import CoreData
import Foundation

final class CoreDataPlaylistStore: PlaylistStore {
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    @discardableResult
    func createPlaylist(_ draft: PlaylistDraft) throws -> PlaylistRecord {
        let context = persistence.viewContext
        var producedRecord: PlaylistRecord?
        var recordedError: Error?

        context.performAndWait {
            do {
                let playlist = PlaylistEntity(context: context)
                playlist.id = UUID()
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

    func deletePlaylist(id: UUID) throws {
        let context = persistence.viewContext
        var recordedError: Error?

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
            } catch {
                recordedError = error
            }
        }

        if let recordedError {
            throw recordedError
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
}
