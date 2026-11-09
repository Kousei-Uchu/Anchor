import SwiftUI

/// The safety copy screen (Patch 35b1). It only asks for a job; the job runs the next time Anchor
/// starts, before the database is opened. See `SafetyCopy` and docs/DECISIONS_EXPLAINED.md (D15).
struct SafetyCopyView: View {
    @State private var status = SafetyCopy.status()
    @State private var confirmGoBack = false
    @State private var confirmUndo = false
    @State private var confirmDelete = false

    var body: some View {
        Form {
            if let pending = status.pending {
                Anchor.SettingsSection(title: "Waiting", footer: "Close Anchor from the app switcher and open it again. The copy is made when it starts.") {
                    Text(waitingText(pending))
                        .font(.system(.subheadline, design: .rounded))
                    Button {
                        SafetyCopy.cancelRequest()
                        refresh()
                    } label: {
                        Text("Cancel")
                            .font(.system(.subheadline, design: .rounded))
                    }
                }
            }

            if let result = status.lastResult {
                Anchor.SettingsSection(title: "Last time") {
                    Text(result)
                        .font(.system(.subheadline, design: .rounded))
                    Button {
                        SafetyCopy.clearLastResult()
                        refresh()
                    } label: {
                        Text("Dismiss")
                            .font(.system(.subheadline, design: .rounded))
                    }
                }
            }

            Anchor.SettingsSection(
                title: "Safety copy",
                footer: "An exact copy of your database, voice notes and Journal photos, kept on this phone and out of phone backups. If the phone is lost or wiped, the copy goes with it."
            ) {
                if status.exists, let made = status.createdAt {
                    Text("Made \(made.formatted(date: .abbreviated, time: .shortened)), \(status.files) files, \(sizeText(status.bytes)).")
                        .font(.system(.subheadline, design: .rounded))
                } else {
                    Text("No copy yet.")
                        .font(.system(.subheadline, design: .rounded))
                }
                Button {
                    SafetyCopy.request(.make)
                    refresh()
                } label: {
                    Text(status.exists ? "Make a new safety copy" : "Make a safety copy")
                        .font(.system(.subheadline, design: .rounded))
                }
                .disabled(DemoMode.isOn)
            }

            if status.exists {
                Anchor.SettingsSection(
                    title: "Go back",
                    footer: "Puts the copy in place. What is there now is set aside, not deleted, and Undo go back brings it back. Anything you wrote after the copy was made is in the set-aside part."
                ) {
                    Button {
                        confirmGoBack = true
                    } label: {
                        Text("Go back to the safety copy")
                            .font(.system(.subheadline, design: .rounded))
                    }
                    .disabled(DemoMode.isOn)
                }
            }

            if status.hasSetAside {
                Anchor.SettingsSection(
                    title: "Undo go back",
                    footer: "Swaps what is on the phone with what was set aside. Doing it again goes back again. Going back a second time replaces the older set-aside part."
                ) {
                    Button {
                        confirmUndo = true
                    } label: {
                        Text("Undo go back")
                            .font(.system(.subheadline, design: .rounded))
                    }
                    .disabled(DemoMode.isOn)
                }
            }

            if status.exists {
                Anchor.SettingsSection(title: nil) {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Text("Delete the safety copy")
                            .font(.system(.subheadline, design: .rounded))
                    }
                }
            }
        }
        .anchorSettingsStyle()
        .navigationTitle("Safety copy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HelpNoteToolbarButton(icon: "arrow.uturn.backward.circle", title: "About the safety copy", paragraphs: SafetyCopyHelp.paragraphs)
            }
        }
        .onAppear { refresh() }
        .confirmationDialog("Go back to the safety copy?", isPresented: $confirmGoBack, titleVisibility: .visible) {
            Button("Go back on the next start", role: .destructive) {
                SafetyCopy.request(.goBack)
                refresh()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Nothing is deleted. What is there now is set aside first.")
        }
        .confirmationDialog("Undo go back?", isPresented: $confirmUndo, titleVisibility: .visible) {
            Button("Undo on the next start", role: .destructive) {
                SafetyCopy.request(.undo)
                refresh()
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete the safety copy?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete the copy", role: .destructive) {
                SafetyCopy.deleteCopy()
                refresh()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your own data is not touched. Anything set aside is kept.")
        }
    }

    private func refresh() {
        status = SafetyCopy.status()
    }

    private func waitingText(_ job: SafetyCopy.Request) -> String {
        switch job {
        case .make: return "A safety copy will be made."
        case .goBack: return "Anchor will go back to the safety copy."
        case .undo: return "Anchor will undo going back."
        }
    }

    private func sizeText(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
