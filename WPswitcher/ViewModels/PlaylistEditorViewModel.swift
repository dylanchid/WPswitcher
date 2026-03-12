import Combine
import Foundation

@MainActor
final class PlaylistEditorViewModel: ObservableObject {
    struct Entry: Identifiable, Equatable {
        var id: UUID
        var lightWallpaperId: UUID?
        var darkWallpaperId: UUID?
    }

    struct DisplayAssignment: Identifiable, Equatable {
        var id: UUID
        var displayID: String
        var lightWallpaperId: UUID?
        var darkWallpaperId: UUID?
    }

    @Published var name: String {
        didSet { markDirtyIfNeeded() }
    }

    @Published var intervalMinutes: Int {
        didSet { markDirtyIfNeeded() }
    }

    @Published var playbackMode: PlaylistPlaybackMode {
        didSet { markDirtyIfNeeded() }
    }

    @Published var multiDisplayPolicy: MultiDisplayPolicy {
        didSet { markDirtyIfNeeded() }
    }

    @Published var entries: [Entry] {
        didSet { guard !isInitializing else { return }; markDirtyIfNeeded() }
    }

    @Published var displayAssignments: [DisplayAssignment] {
        didSet { guard !isInitializing else { return }; markDirtyIfNeeded() }
    }

    @Published private(set) var wallpapers: [WallpaperRecord] = []
    @Published private(set) var availableDisplays: [DisplayDescriptor] = []
    @Published var errorMessage: String?
    @Published private(set) var isSaving = false
    @Published private(set) var hasUnsavedChanges = false

    private let playlistStore: PlaylistStore
    private let wallpaperService: WallpaperService
    private let onSave: (PlaylistRecord) -> Void

    private var playlistId: UUID?
    private var lastKnownRecord: PlaylistRecord?
    private var originalSnapshot: Snapshot
    private var isInitializing = true

    private struct Snapshot: Equatable {
        var name: String
        var intervalMinutes: Int
        var playbackMode: PlaylistPlaybackMode
        var multiDisplayPolicy: MultiDisplayPolicy
        var entries: [Entry]
        var displayAssignments: [DisplayAssignment]
    }

    init(
        playlist: PlaylistRecord?,
        playlistStore: PlaylistStore,
        wallpaperService: WallpaperService,
        onSave: @escaping (PlaylistRecord) -> Void
    ) {
        self.playlistStore = playlistStore
        self.wallpaperService = wallpaperService
        self.onSave = onSave

        let seedName = playlist?.name ?? "Untitled Playlist"
        let seedInterval = playlist?.intervalMinutes ?? 15
        let seedPlayback = playlist?.playbackMode ?? .sequential
        let seedPolicy = playlist?.multiDisplayPolicy ?? .mirror
        let seedEntries = playlist?.entries.map {
            Entry(
                id: $0.id,
                lightWallpaperId: $0.lightWallpaper?.id,
                darkWallpaperId: $0.darkWallpaper?.id
            )
        } ?? []
        let seedAssignments = playlist?.displayAssignments.map {
            DisplayAssignment(
                id: $0.id,
                displayID: $0.displayID,
                lightWallpaperId: $0.lightWallpaper?.id,
                darkWallpaperId: $0.darkWallpaper?.id
            )
        } ?? []

        name = seedName
        intervalMinutes = seedInterval
        playbackMode = seedPlayback
        multiDisplayPolicy = seedPolicy
        entries = seedEntries
        displayAssignments = seedAssignments
        playlistId = playlist?.id
        lastKnownRecord = playlist

        originalSnapshot = Snapshot(
            name: seedName,
            intervalMinutes: seedInterval,
            playbackMode: seedPlayback,
            multiDisplayPolicy: seedPolicy,
            entries: seedEntries,
            displayAssignments: seedAssignments
        )

        seedWallpapers(from: playlist)

        isInitializing = false
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    func refreshLibrary() {
        Task {
            do {
                let libraryRecords = try await wallpaperService.fetchLibrary()
                let displays = wallpaperService.availableDisplays()
                errorMessage = nil
                refreshWallpapersCache(using: lastKnownRecord, library: libraryRecords)
                availableDisplays = displays
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addEntry() {
        entries.append(Entry(id: UUID(), lightWallpaperId: nil, darkWallpaperId: nil))
    }

    func removeEntry(at index: Int) {
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
    }

    func moveEntryUp(at index: Int) {
        guard entries.indices.contains(index), index > 0 else { return }
        entries.swapAt(index, index - 1)
    }

    func moveEntryDown(at index: Int) {
        guard entries.indices.contains(index), index < entries.count - 1 else { return }
        entries.swapAt(index, index + 1)
    }

    func addDisplayAssignment() {
        let identifier = nextAvailableDisplayID()
        displayAssignments.append(
            DisplayAssignment(id: UUID(), displayID: identifier, lightWallpaperId: nil, darkWallpaperId: nil)
        )
    }

    func removeDisplayAssignment(at index: Int) {
        guard displayAssignments.indices.contains(index) else { return }
        displayAssignments.remove(at: index)
    }

    func moveDisplayAssignmentUp(at index: Int) {
        guard displayAssignments.indices.contains(index), index > 0 else { return }
        displayAssignments.swapAt(index, index - 1)
    }

    func moveDisplayAssignmentDown(at index: Int) {
        guard displayAssignments.indices.contains(index), index < displayAssignments.count - 1 else { return }
        displayAssignments.swapAt(index, index + 1)
    }

    func nameForWallpaper(id: UUID?) -> String {
        guard let id, let record = wallpaperLookup[id] else { return "None" }
        return record.displayName
    }

    func wallpaper(for id: UUID?) -> WallpaperRecord? {
        guard let id else { return nil }
        return wallpaperLookup[id]
    }

    func saveChanges() {
        guard canSave else { return }

        isSaving = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryDrafts = entries.enumerated().map { index, entry in
            PlaylistEntryDraft(
                id: entry.id,
                order: index,
                lightWallpaperId: entry.lightWallpaperId,
                darkWallpaperId: entry.darkWallpaperId
            )
        }

        let normalizedAssignments = displayAssignments.enumerated().map { index, assignment in
            (
                index,
                assignment.id,
                assignment.displayID.trimmingCharacters(in: .whitespacesAndNewlines),
                assignment.lightWallpaperId,
                assignment.darkWallpaperId
            )
        }

        if multiDisplayPolicy == .perDisplay {
            if normalizedAssignments.contains(where: { $0.2.isEmpty }) {
                errorMessage = "Each display assignment must include a display identifier."
                isSaving = false
                return
            }

            let knownDisplayIDs = Set(availableDisplays.map(\.id))
            if !knownDisplayIDs.isEmpty,
               let staleAssignment = normalizedAssignments.first(where: { !knownDisplayIDs.contains($0.2) }) {
                errorMessage = "Display assignment '\(staleAssignment.2)' no longer matches a connected display."
                isSaving = false
                return
            }

            var seenIdentifiers: Set<String> = []
            for assignment in normalizedAssignments {
                let canonical = assignment.2.lowercased()
                if !seenIdentifiers.insert(canonical).inserted {
                    errorMessage = "Display identifiers must be unique."
                    isSaving = false
                    return
                }
            }
        }

        let assignmentDrafts = normalizedAssignments.map { normalized in
            DisplayAssignmentDraft(
                id: normalized.1,
                displayID: normalized.2,
                order: normalized.0,
                lightWallpaperId: normalized.3,
                darkWallpaperId: normalized.4
            )
        }

        let draft = PlaylistDraft(
            id: playlistId,
            name: trimmedName,
            intervalMinutes: intervalMinutes,
            playbackMode: playbackMode,
            multiDisplayPolicy: multiDisplayPolicy,
            entries: entryDrafts,
            displayAssignments: assignmentDrafts
        )

        Task {
            do {
                let record: PlaylistRecord
                if playlistId == nil {
                    record = try await playlistStore.createPlaylist(draft)
                    playlistId = record.id
                } else {
                    record = try await playlistStore.updatePlaylist(draft)
                }

                lastKnownRecord = record
                onSave(record)
                collapseIntoSnapshot(record: record)
                seedWallpapers(from: record)
                refreshLibrary()
                hasUnsavedChanges = false
            } catch {
                errorMessage = error.localizedDescription
            }

            isSaving = false
        }
    }

    func labelForDisplay(id: String) -> String {
        availableDisplays.first(where: { $0.id == id })?.name ?? id
    }

    func applyUpdatedRecord(_ record: PlaylistRecord) {
        guard record.id == playlistId else { return }
        lastKnownRecord = record
        isInitializing = true
        name = record.name
        intervalMinutes = record.intervalMinutes
        playbackMode = record.playbackMode
        multiDisplayPolicy = record.multiDisplayPolicy
        entries = record.entries.map { entry in
            Entry(
                id: entry.id,
                lightWallpaperId: entry.lightWallpaper?.id,
                darkWallpaperId: entry.darkWallpaper?.id
            )
        }
        displayAssignments = record.displayAssignments.map { assignment in
            DisplayAssignment(
                id: assignment.id,
                displayID: assignment.displayID,
                lightWallpaperId: assignment.lightWallpaper?.id,
                darkWallpaperId: assignment.darkWallpaper?.id
            )
        }
        collapseIntoSnapshot(record: record)
        seedWallpapers(from: record)
        refreshLibrary()
        hasUnsavedChanges = false
        isInitializing = false
    }

    private func refreshWallpapersCache(using record: PlaylistRecord?, library: [WallpaperRecord]? = nil) {
        var lookup: [UUID: WallpaperRecord] = [:]

        if let library {
            lookup.merge(library.mapKeyedById()) { lhs, _ in lhs }
        }

        if let record {
            record.entries.forEach { entry in
                if let light = entry.lightWallpaper {
                    lookup[light.id] = light
                }
                if let dark = entry.darkWallpaper {
                    lookup[dark.id] = dark
                }
            }
            record.displayAssignments.forEach { assignment in
                if let light = assignment.lightWallpaper {
                    lookup[light.id] = light
                }
                if let dark = assignment.darkWallpaper {
                    lookup[dark.id] = dark
                }
            }
        }

        if let existing = library, lookup.isEmpty {
            lookup = existing.mapKeyedById()
        }

        wallpapers = lookup.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func collapseIntoSnapshot(record: PlaylistRecord) {
        originalSnapshot = Snapshot(
            name: record.name,
            intervalMinutes: record.intervalMinutes,
            playbackMode: record.playbackMode,
            multiDisplayPolicy: record.multiDisplayPolicy,
            entries: record.entries.map {
                Entry(
                    id: $0.id,
                    lightWallpaperId: $0.lightWallpaper?.id,
                    darkWallpaperId: $0.darkWallpaper?.id
                )
            },
            displayAssignments: record.displayAssignments.map {
                DisplayAssignment(
                    id: $0.id,
                    displayID: $0.displayID,
                    lightWallpaperId: $0.lightWallpaper?.id,
                    darkWallpaperId: $0.darkWallpaper?.id
                )
            }
        )
    }

    private func markDirtyIfNeeded() {
        guard !isInitializing else { return }
        hasUnsavedChanges = currentSnapshot != originalSnapshot
    }

    private var currentSnapshot: Snapshot {
        Snapshot(
            name: name,
            intervalMinutes: intervalMinutes,
            playbackMode: playbackMode,
            multiDisplayPolicy: multiDisplayPolicy,
            entries: entries,
            displayAssignments: displayAssignments
        )
    }

    private var wallpaperLookup: [UUID: WallpaperRecord] {
        wallpapers.mapKeyedById()
    }

    private func seedWallpapers(from record: PlaylistRecord?) {
        var lookup: [UUID: WallpaperRecord] = [:]
        record?.entries.forEach { entry in
            if let light = entry.lightWallpaper {
                lookup[light.id] = light
            }
            if let dark = entry.darkWallpaper {
                lookup[dark.id] = dark
            }
        }
        record?.displayAssignments.forEach { assignment in
            if let light = assignment.lightWallpaper {
                lookup[light.id] = light
            }
            if let dark = assignment.darkWallpaper {
                lookup[dark.id] = dark
            }
        }
        wallpapers = lookup.values.sorted { lhs, rhs in
            lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private func nextDisplayIdentifier() -> String {
        ""
    }

    private func nextAvailableDisplayID() -> String {
        let used = Set(displayAssignments.map(\.displayID))
        if let next = availableDisplays.first(where: { !used.contains($0.id) }) {
            return next.id
        }
        return availableDisplays.first?.id ?? nextDisplayIdentifier()
    }
}

private extension Array where Element == WallpaperRecord {
    func mapKeyedById() -> [UUID: WallpaperRecord] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0) })
    }
}
