import CoreData

@objc(PlaylistEntity)
final class PlaylistEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PlaylistEntity> {
        let request = NSFetchRequest<PlaylistEntity>(entityName: "PlaylistEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return request
    }

    @NSManaged var createdAt: Date
    @NSManaged var id: UUID
    @NSManaged var intervalMinutes: Int32
    @NSManaged var name: String
    @NSManaged var wallpapers: NSOrderedSet?
}

@objc(WallpaperEntity)
final class WallpaperEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<WallpaperEntity> {
        NSFetchRequest<WallpaperEntity>(entityName: "WallpaperEntity")
    }

    @NSManaged var createdAt: Date
    @NSManaged var displayName: String
    @NSManaged var id: UUID
    @NSManaged var url: URL
    @NSManaged var bookmarkData: Data?
    @NSManaged var playlists: NSSet?
}

extension PlaylistEntity {
    var orderedWallpapers: [WallpaperEntity] {
        (wallpapers?.array as? [WallpaperEntity]) ?? []
    }

    func applyDraft(_ draft: PlaylistDraft, createdAt defaultCreatedAt: Date = Date(), in context: NSManagedObjectContext) {
        name = draft.name
        intervalMinutes = Int32(draft.intervalMinutes)
        if managedObjectContext?.insertedObjects.contains(self) == true || creationDateNeedsSeed {
            createdAt = defaultCreatedAt
        }

        if let existing = wallpapers {
            existing.forEach { element in
                if let wallpaper = element as? WallpaperEntity {
                    context.delete(wallpaper)
                }
            }
        }

        let wallpaperEntities: [WallpaperEntity] = draft.wallpapers.map { draft in
            let entity = WallpaperEntity(context: context)
            entity.id = UUID()
            entity.url = draft.url
            entity.displayName = draft.displayName
            entity.createdAt = defaultCreatedAt
            entity.bookmarkData = draft.bookmarkData
            entity.playlists = NSSet(object: self)
            return entity
        }

        wallpapers = NSOrderedSet(array: wallpaperEntities)
    }

    private var creationDateNeedsSeed: Bool {
        willAccessValue(forKey: "createdAt")
        defer { didAccessValue(forKey: "createdAt") }
        return primitiveValue(forKey: "createdAt") == nil
    }

    func toRecord() -> PlaylistRecord {
        PlaylistRecord(
            id: id,
            name: name,
            intervalMinutes: Int(intervalMinutes),
            createdAt: createdAt,
            wallpapers: orderedWallpapers.map { $0.toRecord() }
        )
    }
}

extension WallpaperEntity {
    func toRecord() -> WallpaperRecord {
        WallpaperRecord(
            id: id,
            url: url,
            displayName: displayName,
            createdAt: createdAt,
            bookmarkData: bookmarkData
        )
    }
}
