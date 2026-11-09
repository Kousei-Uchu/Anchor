import SwiftUI

/// The Lock my data screen (Patch 35b3, D15). It only asks for a job; the job runs on the next start, after the
/// safety copy has been made. See `LockMyData` and docs/DECISIONS_EXPLAINED.md.
struct LockMyDataView: View {
    @StateObject private var keys = DataKeyManager.shared
    @State private var status = LockMyData.status()
    @State private var recoveryChecked = false
    @State private var backupKept = false
    @State private var showCheck = false
    @State private var confirmLock = false

    private var keyReady: Bool { keys.status == .ready && keys.hasRecoveryFile }
    private var canLock: Bool {
        keyReady && recoveryChecked && backupKept && !DemoMode.isOn && AnchorSchema.openedPersistentStore
    }

    var body: some View {
        Form {
            if status.waiting {
                Anchor.SettingsSection(
                    title: "Waiting",
                    footer: "Close Anchor from the app switcher and open it again. The safety copy is made first, then your text is locked, before any screen opens."
                ) {
                    Text("Your text will be locked on the next start.")
                        .font(.system(.subheadline, design: .rounded))
                    Button {
                        LockMyData.cancelRequest()
                        refresh()
                    } label: {
                        Text("Cancel").font(.system(.subheadline, design: .rounded))
                    }
                }
            }

            if let result = status.lastResult {
                Anchor.SettingsSection(title: "Last time") {
                    Text(result).font(.system(.subheadline, design: .rounded))
                    Button {
                        LockMyData.clearLastResult()
                        refresh()
                    } label: {
                        Text("Dismiss").font(.system(.subheadline, design: .rounded))
                    }
                }
            }

            if status.isOn {
                lockedSection
            } else if !status.waiting {
                beforeSection
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("Lock my data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HelpNoteToolbarButton(icon: "lock.doc", title: "About Lock my data", paragraphs: LockMyDataHelp.paragraphs)
            }
        }
        .onAppear {
            keys.refresh()
            refresh()
        }
        .sheet(isPresented: $showCheck) {
            RecoveryKeyEntrySheet(title: "Check recovery key", buttonTitle: "Check") { typed in
                do {
                    try keys.checkRecoveryKey(typed)
                    recoveryChecked = true
                    return nil
                } catch {
                    return keyMessage(for: error)
                }
            }
        }
        .confirmationDialog("Lock your text on the next start?", isPresented: $confirmLock, titleVisibility: .visible) {
            Button("Lock on the next start") {
                LockMyData.request()
                refresh()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("A safety copy is made first. If anything does not check out afterwards, Anchor goes back to it.")
        }
    }

    // MARK: Not locked yet

    @ViewBuilder
    private var beforeSection: some View {
        Anchor.SettingsSection(
            title: "Before you lock",
            footer: "Locking writes your text in a code only the key on this phone can open. If that key is ever lost, your recovery key and an encrypted backup are the way back."
        ) {
            row("Data key", keys.status == .ready ? "On this device" : "Not ready")
            row("Recovery file", keys.hasRecoveryFile ? "Kept with your data" : "Missing")
            if !keyReady {
                NavigationLink {
                    EncryptionSettingsView()
                } label: {
                    Text("Set up the key in Encryption").font(.system(.subheadline, design: .rounded))
                }
            }
            row("Recovery key", recoveryChecked ? "Checked just now" : "Not checked")
            Button {
                showCheck = true
            } label: {
                Text("Check my recovery key").font(.system(.subheadline, design: .rounded))
            }
            .disabled(!keys.hasRecoveryFile)
            Toggle(isOn: $backupKept) {
                Text("I have kept an encrypted backup somewhere other than this phone")
                    .font(.system(.subheadline, design: .rounded))
            }
            Text("Make one in Your data, Make an encrypted backup, and save it to Files, iCloud Drive or a computer.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.secondary)
        }

        Anchor.SettingsSection(
            title: nil,
            footer: DemoMode.isOn ? "Off while showcase mode is on." : "A safety copy is made first. Voice notes and Journal photos are not locked yet."
        ) {
            Button {
                confirmLock = true
            } label: {
                Text("Lock my data").font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .disabled(!canLock)
        }
    }

    // MARK: Locked

    @ViewBuilder
    private var lockedSection: some View {
        Anchor.SettingsSection(
            title: "Locked",
            footer: status.scrubWaiting
                ? "Close Anchor from the app switcher and open it again to finish: the old plain copies are cleared out of the database file on that start."
                : "Everything you write from now on is locked as it is saved."
        ) {
            if let when = status.lockedAt {
                row("Locked", when.formatted(date: .abbreviated, time: .shortened))
            }
            row("Items checked", "\(status.items)")
            row("Voice notes and photos", "Not locked yet")
        }

        Anchor.SettingsSection(
            title: "The safety copy",
            footer: "The safety copy was made before locking, so it still holds your text unlocked. Delete it when you are happy."
        ) {
            NavigationLink {
                SafetyCopyView()
            } label: {
                Text("Safety copy").font(.system(.subheadline, design: .rounded))
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(.subheadline, design: .rounded))
            Spacer(minLength: 12)
            Text(value)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func refresh() {
        status = LockMyData.status()
    }
}

/// Stands between the app lock and the app while the text is locked but the key is not on this phone, such as on a
/// phone restored from a backup. Without it every screen would show locked text as empty, and saving one of them
/// would write the empty text over the locked text. Shows the app as usual when the key is here, when nothing is
/// locked, and in showcase mode (Patch 35b3).
struct KeyGateView<Content: View>: View {
    @ObservedObject private var keys = DataKeyManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var restoring = false
    @State private var confirmOpenAnyway = false
    @State private var openAnyway = false
    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var blocked: Bool {
        LockMyData.isOn && !DemoMode.isOn && !openAnyway && keys.status != .ready
    }

    var body: some View {
        Group {
            if blocked {
                gate
            } else {
                content()
            }
        }
        .onAppear { keys.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { keys.refresh() }
        }
    }

    private var gate: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.system(.title2, design: .rounded).weight(.semibold))
                Text(message)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(.secondary)
                if keys.status == .needsRecovery {
                    Button {
                        restoring = true
                    } label: {
                        Text("Restore with your recovery key")
                            .font(.system(.body, design: .rounded).weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button {
                    keys.refresh()
                } label: {
                    Text("Try again")
                        .font(.system(.body, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button(role: .destructive) {
                    confirmOpenAnyway = true
                } label: {
                    Text("Open Anchor without it")
                        .font(.system(.subheadline, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $restoring) {
            RecoveryKeyEntrySheet(title: "Restore the key", buttonTitle: "Restore") { typed in
                do {
                    try keys.restore(with: typed)
                    return nil
                } catch {
                    return keyMessage(for: error)
                }
            }
        }
        .confirmationDialog("Open Anchor without the key?", isPresented: $confirmOpenAnyway, titleVisibility: .visible) {
            Button("Open without it", role: .destructive) { openAnyway = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Locked text will look empty, and saving over it would replace it. Look, but do not edit or save anything locked.")
        }
    }

    private var title: String {
        switch keys.status {
        case .needsRecovery: return "Your key is not on this phone"
        case .unavailable: return "Your key cannot be read right now"
        default: return "Your key is missing"
        }
    }

    private var message: String {
        switch keys.status {
        case .needsRecovery:
            return "Your text is locked, and the key that opens it is not on this phone. This happens on a phone restored from a backup. Your recovery key brings it back."
        case .unavailable:
            return "Your text is locked, and Anchor cannot reach the key just now. This usually passes. Try again in a moment."
        default:
            return "Your text is locked, and neither the key nor the recovery file is on this phone. An encrypted backup or the safety copy can bring your text back."
        }
    }
}
