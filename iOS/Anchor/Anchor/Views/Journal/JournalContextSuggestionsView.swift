//
//  JournalContextSuggestionsView.swift
//  Anchor
//
//  Approximates what Apple's own Journal app does with its restricted
//  JournalingSuggestions framework (now also offered at the top of this
//  list, using the Journaling Suggestions entitlement), by talking to
//  EventKit, PhotoKit, and MusicKit directly. Calendar and Photos need only their standard
//  usage-description prompts (already in Info.plist) and work as-is.
//  Music needs one manual step the code alone can't safely do: enabling
//  the "MusicKit" capability in Xcode (Signing & Capabilities → +
//  Capability), since that's a project-signing change, not something to
//  guess at in a hand-edited entitlements file without being able to
//  verify it against a real provisioning profile.
//
//  Nothing here is inserted automatically — every suggestion is tap to
//  add, same as the mascot's journal prompts.
//

import SwiftUI
import EventKit
import Photos
import MusicKit
#if canImport(JournalingSuggestions)
import JournalingSuggestions
#endif

struct JournalContextSuggestionsView: View {
    let day: Date
    let onInsert: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var events: [EKEvent] = []
    @State private var calendarAuthDenied = false

    @State private var photoAssets: [PHAsset] = []
    @State private var photoThumbnails: [UIImage] = []
    @State private var photosAuthDenied = false

    @State private var recentSongs: [(title: String, artist: String)] = []
    @State private var musicAuthDenied = false
    @State private var musicUnavailableMessage: String?

    var body: some View {
        NavigationStack {
            List {
                #if canImport(JournalingSuggestions)
                if #available(iOS 17.2, *) {
                Section("Apple's journaling suggestions") {
                        JournalingSuggestionsPicker {
                            Label("Browse suggestions", systemImage: "sparkles")
                        } onCompletion: { suggestion in
                            await MainActor.run {
                                onInsert("✨ \(suggestion.title)")
                                dismiss()
                            }
                        }
                }
                }
                #endif
                Section("Calendar events that day") {
                    if calendarAuthDenied {
                        Text("Calendar access is off. Enable it in Settings → Anchor.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if events.isEmpty {
                        Text("Nothing found for this day.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(events, id: \.eventIdentifier) { event in
                        Button {
                            onInsert("📅 \(event.title ?? "Event")")
                            dismiss()
                        } label: {
                            Text(event.title ?? "Untitled event")
                        }
                    }
                }

                Section("Photos from that day") {
                    if photosAuthDenied {
                        Text("Photos access is off. Enable it in Settings → Anchor.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if photoAssets.isEmpty {
                        Text("No photos found for this day.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(zip(photoAssets.indices, photoAssets)), id: \.1.localIdentifier) { index, asset in
                                    Button {
                                        insertPhoto(asset)
                                    } label: {
                                        Image(uiImage: photoThumbnails[index])
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 70, height: 70)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                Section {
                    if let musicUnavailableMessage {
                        Text(musicUnavailableMessage).font(.caption).foregroundStyle(.secondary)
                    } else if musicAuthDenied {
                        Text("Music access is off. Enable it in Settings → Anchor.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if recentSongs.isEmpty {
                        Text("Nothing recent found.").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(Array(recentSongs.enumerated()), id: \.offset) { _, song in
                        Button {
                            onInsert("🎵 \(song.title), \(song.artist)")
                            dismiss()
                        } label: {
                            Text("\(song.title), \(song.artist)")
                        }
                    }
                } header: {
                    Text("Recently played")
                } footer: {
                    Text("Needs the MusicKit capability enabled in Xcode (Signing & Capabilities → + Capability → MusicKit) before this can authorize on a real device.")
                }
            }
            .navigationTitle("Journaling Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await loadCalendarEvents()
                await loadPhotos()
                await loadRecentMusic()
            }
        }
    }

    private func loadCalendarEvents() async {
        let store = EKEventStore()
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        guard granted else { calendarAuthDenied = true; return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate)
    }

    private func loadPhotos() async {
        let status = await withCheckedContinuation { (continuation: CheckedContinuation<PHAuthorizationStatus, Never>) in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { continuation.resume(returning: $0) }
        }
        guard status == .authorized || status == .limited else { photosAuthDenied = true; return }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@", start as NSDate, end as NSDate)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let result = PHAsset.fetchAssets(with: .image, options: options)

        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        assets = Array(assets.prefix(12))

        let manager = PHImageManager.default()
        let requestOptions = PHImageRequestOptions()
        // One callback with the final image. .opportunistic calls back twice
        // (a rough image, then the real one), which resumed the continuation twice.
        requestOptions.deliveryMode = .highQualityFormat
        requestOptions.isNetworkAccessAllowed = true

        var thumbnails: [UIImage] = []
        for asset in assets {
            let image = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
                manager.requestImage(
                    for: asset, targetSize: CGSize(width: 140, height: 140),
                    contentMode: .aspectFill, options: requestOptions
                ) { image, info in
                    // Belt and braces: ignore a rough in-between image, so the
                    // continuation is only ever resumed once.
                    if (info?[PHImageResultIsDegradedKey] as? Bool) == true { return }
                    continuation.resume(returning: image)
                }
            }
            if let image { thumbnails.append(image) }
        }
        photoAssets = Array(assets.prefix(thumbnails.count))
        photoThumbnails = thumbnails
    }

    private func insertPhoto(_ asset: PHAsset) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        manager.requestImage(
            for: asset, targetSize: CGSize(width: 1200, height: 1200),
            contentMode: .aspectFit, options: options
        ) { image, _ in
            guard let image, let data = image.jpegData(compressionQuality: 0.85),
                  let filename = JournalAttachmentStore.save(imageData: data) else { return }
            onInsert("![](\(filename))")
            dismiss()
        }
    }

    private func loadRecentMusic() async {
        let status = await MusicAuthorization.request()
        guard status == .authorized else { musicAuthDenied = true; return }
        do {
            var request = MusicRecentlyPlayedRequest<Song>()
            request.limit = 10
            let response = try await request.response()
            recentSongs = response.items.map { ($0.title, $0.artistName) }
        } catch {
            musicUnavailableMessage = "Couldn't load recent music. Check that the MusicKit capability is enabled in Xcode."
        }
    }
}
