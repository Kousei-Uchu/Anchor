//
//  ThreadView.swift
//  Anchor
//

import SwiftUI

struct ThreadView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                // Matches the tile-row dashboard used on Plan and Bridge,
                // rather than a stock settings-style List — Thread's
                // destinations (message log, support calendar, notes to
                // yourself) are places to reach, not configuration to dig
                // through.
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Anchor.TileRow(title: "With someone") {
                            NavigationLink { ThreadMessagesView() } label: {
                                Anchor.TileButtonLabel(icon: "bubble.left.and.bubble.right.fill", title: "Message log", tint: Anchor.Theme.accent)
                            }
                            NavigationLink { SupportCalendarView() } label: {
                                Anchor.TileButtonLabel(icon: "calendar.badge.clock", title: "Support calendar", tint: Anchor.Theme.accent)
                            }
                        }
                        Text("Message log is tied to a real contact and can actually send.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Anchor.TileRow(title: "Just for you") {
                            NavigationLink { FutureNoteListView() } label: {
                                Anchor.TileButtonLabel(icon: "envelope.open.badge.clock", title: "To future me", tint: Anchor.Theme.sage)
                            }
                            NavigationLink { UnsentDraftsView() } label: {
                                Anchor.TileButtonLabel(icon: "square.and.pencil", title: "Things I haven't said", tint: Anchor.Theme.sage)
                            }
                        }
                        Text("\"Things I haven't said\" is for big things you might never send, to anyone.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
            }
            .anchorBackground()
            .navigationTitle("Thread")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HelpToolbarButton(topic: .thread)
                }
            }
        }
    }
}
