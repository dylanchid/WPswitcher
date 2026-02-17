import CoreData
import Foundation

extension Notification.Name {
    static let playlistStoreDidChange = Notification.Name("com.example.WPswitcher.playlistStoreDidChange")
}

final class CoreDataPlaylistStore: PlaylistStore {
    private let persistence: PersistenceController
    private let notificationCenter: NotificationCenter

    init(
        persistence: PersistenceController = .shared,
        notificationCenter: NotificationCenter = .default
    ) {
        self.persistence = persistence
        self.notificationCenter = notificationCenter
    }

    @discardableResult
    func createPlaylist(_ draft: PlaylistDraft) async throws -> PlaylistRecord {
        let context = persistence.newBackgroundContext()
        
        let objectID = try await context.perform {
            let playlist = PlaylistEntity(context: context)
            playlist.id = draft.id ?? UUID()
            try playlist.applyDraft(draft, in: context)
            try context.save()
            return playlist.objectID
        }

        let producedRecord = try await materializePlaylistRecord(objectID: objectID)
        notifyPlaylistChanged(playlistID: producedRecord.id)
        return producedRecord
    }

    func fetchPlaylists() async throws -> [PlaylistRecord] {
        let context = persistence.newBackgroundContext()
        
        return try await context.perform {
            let request = PlaylistEntity.fetchRequest()
            request.relationshipKeyPathsForPrefetching = ["items", "displayAssignments", "items.lightWallpaper", "items.darkWallpaper", "displayAssignments.lightWallpaper", "displayAssignments.darkWallpaper"]
            let results = try context.fetch(request)
            return results.map { $0.toRecord() }
        }
    }

    func fetchPlaylist(id: UUID) async throws -> PlaylistRecord? {
        let context = persistence.newBackgroundContext()
        
        return try await context.perform {
            let request = PlaylistEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            request.relationshipKeyPathsForPrefetching = ["items", "displayAssignments", "items.lightWallpaper", "items.darkWallpaper", "displayAssignments.lightWallpaper", "displayAssignments.darkWallpaper"]
            return try context.fetch(request).first?.toRecord()
        }
    }

    @discardableResult
    func updatePlaylist(_ draft: PlaylistDraft) async throws -> PlaylistRecord {
        guard let identifier = draft.id else {
            throw PlaylistStoreError.invalidDraft
        }

        let context = persistence.newBackgroundContext()
        
        let objectID = try await context.perform {
            let request = PlaylistEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", identifier as CVarArg)
            request.fetchLimit = 1
            request.relationshipKeyPathsForPrefetching = ["items", "displayAssignments"]

            guard let playlist = try context.fetch(request).first else {
                throw PlaylistStoreError.playlistNotFound
            }

            try playlist.applyDraft(draft, in: context)
            try context.save()
            return playlist.objectID
        }

        let producedRecord = try await materializePlaylistRecord(objectID: objectID)
        notifyPlaylistChanged(playlistID: producedRecord.id)
        return producedRecord
    }

    func deletePlaylist(id: UUID) async throws {
        let context = persistence.newBackgroundContext()
        
        let deleted = try await context.perform {
            let request = PlaylistEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            let results = try context.fetch(request)
            guard let playlist = results.first else {
                throw PlaylistStoreError.playlistNotFound
            }

            context.delete(playlist)
            try context.save()
            return true
        }

        if deleted {
            notifyPlaylistChanged(playlistID: id)
        }
    }

    @discardableResult
    func upsertWallpaper(_ draft: WallpaperDraft) async throws -> WallpaperRecord {
        let context = persistence.newBackgroundContext()
        
        return try await context.perform {
            let request = WallpaperEntity.fetchRequest()
            request.predicate = NSPredicate(format: "url == %@", draft.url as NSURL)
            request.fetchLimit = 1
            let existing = try context.fetch(request).first
            let entity = existing ?? WallpaperEntity(context: context)
            if existing == nil {
                entity.id = UUID()
                entity.createdAt = Date()
            }
            entity.url = draft.url
            entity.displayName = draft.displayName
            if let bookmark = draft.bookmarkData {
                entity.bookmarkData = bookmark
            }
            try context.save()
            return entity.toRecord()
        }
    }

    /// Builds a PlaylistRecord on the view context (main thread) to avoid priority inversion:
    /// a user-initiated caller would otherwise wait on background context's utility-QoS work in toRecord().
    private func materializePlaylistRecord(objectID: NSManagedObjectID) async throws -> PlaylistRecord {
        try await MainActor.run {
            let viewContext = persistence.viewContext
            viewContext.processPendingChanges()
            guard let entity = try? viewContext.existingObject(with: objectID) as? PlaylistEntity else {
                throw PlaylistStoreError.playlistNotFound
            }
            return entity.toRecord()
        }
    }

    private func notifyPlaylistChanged(playlistID: UUID) {
        notificationCenter.post(
            name: .playlistStoreDidChange,
            object: self,
            userInfo: ["playlistID": playlistID]
        )
    }
}
