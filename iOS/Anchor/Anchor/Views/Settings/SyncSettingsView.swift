import SwiftUI
import SwiftData

/// Settings, iCloud sync (Patch SY1b, E1). Off until switched on. See `CloudSync` for what it does and does not send.
/// The setting is read when Anchor starts, so every change says to close Anchor and open it again.
struct SyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var keys = DataKeyManager.shared
    @State private var message: String?
    @State private var confirmTurnOn = false
    @State private var confirmTurnOff = false
    @State private var showRestore = false
    @State private var enabled = CloudSync.isOn
    @State private var syncFiles = UserDefaults.standard.bool(forKey: FileSync.enabledKey)

    var body: some View {
        Form {
            Anchor.SettingsSection(title: nil, footer: "Sync uses your own private iCloud storage and only your own devices. Everything that holds your words is locked before it leaves this phone, and the key never goes to iCloud. Nights that Apple Health already holds are not synced.") {
                Text(statusLine)
                    .font(.system(.subheadline, design: .rounded))
                if let message {
                    Text(message)
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            if enabled {
                onSection
            } else {
                offSection
            }

            if enabled {
                filesSection
            }

            Anchor.SettingsSection(
                title: "A second device",
                footer: "Install Anchor on the other device, sign in to the same Apple ID, open this screen there and choose Use this as a second device. Then type your recovery key. The other device must have nothing in Anchor yet."
            ) {
                if keys.status != .ready && !enabled {
                    Button {
                        useAsSecondDevice()
                    } label: {
                        Text("Use this as a second device").font(.system(.subheadline, design: .rounded))
                    }
                    .disabled(DemoMode.isOn)
                }
                if enabled && keys.status == .needsRecovery {
                    Button {
                        showRestore = true
                    } label: {
                        Text("Type my recovery key").font(.system(.subheadline, design: .rounded))
                    }
                }
                if enabled && keys.status == .ready && !LockMyData.isOn {
                    Button {
                        finishSecondDevice()
                    } label: {
                        Text("Finish setting up this device").font(.system(.subheadline, design: .rounded))
                    }
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("iCloud sync")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            enabled = CloudSync.isOn
            syncFiles = UserDefaults.standard.bool(forKey: FileSync.enabledKey)
            keys.refresh()
        }
        .sheet(isPresented: $showRestore) {
            RecoveryKeyEntrySheet(title: "Restore the key", buttonTitle: "Restore") { typed in
                do {
                    try keys.restore(with: typed)
                    message = "The key is back on this device. Choose Finish setting up this device next."
                    return nil
                } catch DataKeyError.notARecoveryKey {
                    return "That is not a whole recovery key. Check it against the one you wrote down."
                } catch DataKeyError.wrongRecoveryKey {
                    return "That recovery key does not open the recovery file from your other device."
                } catch {
                    return "The key could not be restored. Nothing was changed."
                }
            }
        }
        .confirmationDialog("Turn on iCloud sync?", isPresented: $confirmTurnOn, titleVisibility: .visible) {
            Button("Turn on") { turnOn() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(turnOnWarning)
        }
        .confirmationDialog("Turn off iCloud sync?", isPresented: $confirmTurnOff, titleVisibility: .visible) {
            Button("Turn off", role: .destructive) { turnOff() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This device stops syncing the next time Anchor starts. What is already in iCloud stays there, and other devices keep what they have.")
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var offSection: some View {
        let reason = DemoMode.isOn ? "Off while showcase mode is on." : CloudSync.reasonCannotTurnOn()
        Anchor.SettingsSection(title: nil, footer: reason) {
            Button {
                confirmTurnOn = true
            } label: {
                Text("Turn on iCloud sync").font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .disabled(reason != nil)
        }
    }

    @ViewBuilder
    private var filesSection: some View {
        let reason = FileSync.reasonCannotTurnOn()
        Anchor.SettingsSection(
            title: "Voice notes and photos",
            footer: reason ?? "Only files that are already locked are sent, so iCloud holds nothing readable. This uses your own iCloud storage, and it is a switch for each device. A voice note you delete is deleted from iCloud and from your other devices."
        ) {
            Toggle(isOn: $syncFiles) {
                Text("Send voice notes and photos").font(.system(.subheadline, design: .rounded))
            }
            .disabled(reason != nil && !syncFiles)
            .onChange(of: syncFiles) { _, on in
                UserDefaults.standard.set(on, forKey: FileSync.enabledKey)
                if on { FileSync.startIfDue(force: true) }
            }
            if let last = UserDefaults.standard.string(forKey: FileSync.lastKey), syncFiles {
                Text(last)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var onSection: some View {
        Anchor.SettingsSection(
            title: nil,
            footer: "Clear everything (Your data) clears every device while sync is on."
        ) {
            Button(role: .destructive) {
                confirmTurnOff = true
            } label: {
                Text("Turn off iCloud sync").font(.system(.subheadline, design: .rounded))
            }
        }
    }

    // MARK: Words

    private var statusLine: String {
        if !enabled { return "iCloud sync is off. Everything stays on this device." }
        if CloudSync.openedWithSync {
            return "iCloud sync is on."
        }
        if CloudSync.syncFailedToStart {
            return "Sync could not start this time, so Anchor opened your data without it. Nothing was lost or changed. Check that you are signed in to iCloud and have space, then close and open Anchor again."
        }
        if CloudSync.shouldSyncAtLaunch {
            return "Close Anchor from the app switcher and open it again to start syncing."
        }
        switch keys.status {
        case .needsRecovery: return "This is a second device. Type your recovery key to bring the key here."
        case .ready: return "Almost done: finish setting up this device, then close Anchor and open it again."
        default: return "Waiting for the first device. Turn on iCloud sync there, wait a minute and try again."
        }
    }

    private var healthNights: Int {
        ((try? modelContext.fetch(FetchDescriptor<SleepEntry>())) ?? [])
            .filter { $0.sourceRaw == SleepHealthSettings.sourceHealth }.count
    }

    private var turnOnWarning: String {
        var text = "A safety copy is made first, when Anchor next starts. Sync starts then too."
        let nights = healthNights
        if nights > 0 {
            text += " The \(nights) nights Anchor brought in from Apple Health are removed from Anchor now, because Apple Health information is not kept in iCloud. They stay in Health. Anchor stops bringing nights in from Health while sync is on."
        } else {
            text += " Anchor will not bring nights in from Apple Health while sync is on, because Apple Health information is not kept in iCloud."
        }
        return text
    }

    // MARK: Actions

    private func turnOn() {
        _ = SleepHealthReader.shared.removeImported(context: modelContext)
        UserDefaults.standard.set(true, forKey: CloudSync.enabledKey)
        CloudSync.publishForOtherDevices()
        SafetyCopy.request(.make)
        enabled = true
        message = "Close Anchor from the app switcher and open it again. The safety copy is made and sync starts."
    }

    private func turnOff() {
        UserDefaults.standard.set(false, forKey: CloudSync.enabledKey)
        enabled = false
        message = "Close Anchor from the app switcher and open it again to stop syncing."
    }

    private func useAsSecondDevice() {
        UserDefaults.standard.set(true, forKey: CloudSync.enabledKey)
        enabled = true
        if CloudSync.pullRecoveryFile() {
            keys.refresh()
            message = "Found the recovery file from your other device. Type your recovery key next."
        } else {
            message = "Nothing from another device in iCloud yet. On the first device, turn on iCloud sync, wait a minute and come back here."
        }
    }

    private func finishSecondDevice() {
        guard deviceIsEmpty else {
            message = "This device already has its own data in Anchor, which would be mixed into the other device's. Use a device with nothing in Anchor yet."
            return
        }
        if CloudSync.adoptLockedState() {
            message = "Done. Close Anchor from the app switcher and open it again to start syncing."
        } else {
            message = "The key on this device does not match the one from your other device, or that device has not locked its data yet."
        }
    }

    private var deviceIsEmpty: Bool {
        func count<T: PersistentModel>(_ type: T.Type) -> Int { (try? modelContext.fetchCount(FetchDescriptor<T>())) ?? 0 }
        let total = count(JournalEntry.self) + count(CheckIn.self) + count(TaskItem.self) + count(SleepEntry.self)
            + count(TrustedContact.self) + count(RecoveryCounter.self) + count(SafetyPlan.self)
            + count(AppointmentSeries.self) + count(PersonalGoal.self) + count(QuickList.self)
        return total == 0
    }
}
