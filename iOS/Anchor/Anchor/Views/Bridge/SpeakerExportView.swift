//
//  SpeakerExportView.swift
//  Anchor
//
//  Who is speaking, on an export (Patch VN5, docs/OPTIONAL_FEATURES.md, E2, D43, D79). For each Journal entry that
//  has people in it, and each person in it, the person picks Show name, Hide name or Leave out. The choice is for
//  this export only: it lives in the state of the screen that opened this one and is gone when that is closed.
//  Used by Export for someone and by the CSV and PDF export in Your data.
//

import SwiftUI

struct SpeakerExportView: View {
    let rows: [SpeakerExportRow]
    @Binding var choices: SpeakerExportChoices

    var body: some View {
        List {
            Section {
                Menu {
                    ForEach(SpeakerExportMode.allCases) { mode in
                        Button(mode.title) { choices.setAll(mode, in: rows) }
                    }
                } label: {
                    Text("Set everyone to")
                }
            } footer: {
                Text("Nothing here is kept once this export is closed. Only a name at the start of a line is changed, so look at the preview before you send it.")
            }

            ForEach(rows) { row in
                Section(row.date.formatted(date: .abbreviated, time: .shortened)) {
                    ForEach(row.people, id: \.self) { person in
                        Picker(person, selection: binding(entry: row.id, person: person)) {
                            ForEach(SpeakerExportMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Who is speaking")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { choices.keepOnly(rows) }
    }

    private func binding(entry: UUID, person: String) -> Binding<SpeakerExportMode> {
        Binding(
            get: { choices.mode(entry: entry, person: person) },
            set: { choices.set($0, entry: entry, person: person) }
        )
    }
}
