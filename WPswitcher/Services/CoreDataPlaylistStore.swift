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
    func createPlaylist(_ draft: PlaylistDraft) throws -> PlaylistRecord {
        let context = persistence.viewContext
        var producedRecord: PlaylistRecord?
        var recordedError: Error?

        context.performAndWait {
            do {
                let playlist = PlaylistEntity(context: context)
                playlist.id = draft.id ?? UUID()
                playlist.applyDraft(draft, in: context)
                try context.save()
                producedRecord = playlist.toRecord()
            } catch {
                recordedError = error
            }
        }

        if let recordedError {
            throw recordedError
        }

        guard let producedRecord else {
            fatalError("Failed to create playlist record")
        }
        notifyPlaylistChanged(playlistID: producedRecord.id)
        return producedRecord
    }

    func fetchPlaylists() throws -> [PlaylistRecord] {
        let context = persistence.viewContext
        var playlists: [PlaylistRecord] = []
        var recordedError: Error?

        context.performAndWait {
            do {
                let request = PlaylistEntity.fetchRequest()
                let results = try context.fetch(request)
                playlists = results.map { $0.toRecord() }
            } catch {
                recordedError = error
            }
        }

        if let recordedError {
            throw recordedError
        }

        return playlists
    }

    func fetchPlaylist(id: UUID) throws -> PlaylistRecord? {
        let context = persistence.viewContext
        var record: PlaylistRecord?
        var recordedError: Error?

        context.performAndWait {
            do {
                let request = PlaylistEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1
                if let result = try context.fetch(request).first {
                    record = result.toRecord()
                }
            } catch {
                recordedError = error
            }
        }

        if let recordedError {
            throw recordedError
        }

        return record
    }

    @discardableResult
    func updatePlaylist(_ draft: PlaylistDraft) throws -> PlaylistRecord {
        guard let identifier = draft.id else {
            throw PlaylistStoreError.invalidDraft
        }

        let context = persistence.viewContext
        var producedRecord: PlaylistRecord?
        var recordedError: Error?

        context.performAndWait {
            do {
                let request = PlaylistEntity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", identifier as CVarArg)
                request.fetchLimit = 1
                guard let playlist = try context.fetch(request).first else {
                    recordedError = PlaylistStoreError.playlistNotFound
                    return
                }

                playlist.applyDraft(draft, in: context)
                try context.save()
                producedRecord = playlist.toRecord()
            } catch {
                recordedError = error
            }
        }

        if let recordedError {
            throw recordedError
        }

        guard let producedRecord else {
            fatalError("Failed to update playlist record")
        }
        notifyPlaylistChanged(playlistID: producedRecord.id)
        return producedRecord
    }

    func deletePlaylist(id: UUID) throws {
        let context = persistence.viewContext
        var recordedError: Error?
        var deleted = false

        context.performAndWait {
            let request = PlaylistEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            do {
                let results = try context.fetch(request)
                guard let playlist = results.first else {
                    recordedError = PlaylistStoreError.playlistNotFound
                    return
                }

                context.delete(playlist)
                try context.save()
                deleted = true
            } catch {
                recordedError = error
            }
        }

        if let recordedError {
            throw recordedError
        }

        if deleted {
            notifyPlaylistChanged(playlistID: id)
        }
    }

    @discardableResult
    func upsertWallpaper(_ draft: WallpaperDraft) throws -> WallpaperRecord {
        let context = persistence.viewContext
        var record: WallpaperRecord?
        var recordedError: Error?

        context.performAndWait {
            do {
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
                record = entity.toRecord()
            } catch {
                recordedError = error
            }
        }

        if let recordedError {
            throw recordedError
        }

        guard let record else {
            fatalError("Failed to upsert wallpaper record")
        }
        return record
    }

    private func notifyPlaylistChanged(playlistID: UUID) {
        notificationCenter.post(
            name: .playlistStoreDidChange,
            object: self,
            userInfo: ["playlistID": playlistID]
        )
    }
}
