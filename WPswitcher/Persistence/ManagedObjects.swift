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
    @NSManaged var playbackModeRaw: String
    @NSManaged var multiDisplayPolicyRaw: String
    @NSManaged var items: NSOrderedSet?
    @NSManaged var displayAssignments: NSOrderedSet?
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
    @NSManaged var lightPlaylistItems: NSSet?
    @NSManaged var darkPlaylistItems: NSSet?
    @NSManaged var lightDisplayAssignments: NSSet?
    @NSManaged var darkDisplayAssignments: NSSet?
}

@objc(PlaylistItemEntity)
final class PlaylistItemEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PlaylistItemEntity> {
        let request = NSFetchRequest<PlaylistItemEntity>(entityName: "PlaylistItemEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        return request
    }

    @NSManaged var id: UUID
    @NSManaged var order: Int32
    @NSManaged var playlist: PlaylistEntity
    @NSManaged var lightWallpaper: WallpaperEntity?
    @NSManaged var darkWallpaper: WallpaperEntity?
}

@objc(DisplayAssignmentEntity)
final class DisplayAssignmentEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<DisplayAssignmentEntity> {
        let request = NSFetchRequest<DisplayAssignmentEntity>(entityName: "DisplayAssignmentEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "order", ascending: true)]
        return request
    }

    @NSManaged var displayID: String
    @NSManaged var id: UUID
    @NSManaged var order: Int32
    @NSManaged var playlist: PlaylistEntity
    @NSManaged var lightWallpaper: WallpaperEntity?
    @NSManaged var darkWallpaper: WallpaperEntity?
}

extension PlaylistEntity {
    var playbackMode: PlaylistPlaybackMode {
        get { PlaylistPlaybackMode(rawValue: playbackModeRaw) ?? .sequential }
        set { playbackModeRaw = newValue.rawValue }
    }

    var multiDisplayPolicy: MultiDisplayPolicy {
        get { MultiDisplayPolicy(rawValue: multiDisplayPolicyRaw) ?? .mirror }
        set { multiDisplayPolicyRaw = newValue.rawValue }
    }

    var orderedWallpapers: [WallpaperEntity] {
        (wallpapers?.array as? [WallpaperEntity]) ?? []
    }

    var orderedItems: [PlaylistItemEntity] {
        guard let storedItems = items?.array as? [PlaylistItemEntity], !storedItems.isEmpty else {
            return []
        }
        return storedItems.sorted { $0.order < $1.order }
    }

    var orderedDisplayAssignments: [DisplayAssignmentEntity] {
        guard let storedAssignments = displayAssignments?.array as? [DisplayAssignmentEntity], !storedAssignments.isEmpty else {
            return []
        }
        return storedAssignments.sorted { $0.order < $1.order }
    }

    func applyDraft(_ draft: PlaylistDraft, createdAt defaultCreatedAt: Date = Date(), in context: NSManagedObjectContext) {
        name = draft.name
        intervalMinutes = Int32(draft.intervalMinutes)
        playbackMode = draft.playbackMode
        multiDisplayPolicy = draft.multiDisplayPolicy
        if managedObjectContext?.insertedObjects.contains(self) == true || creationDateNeedsSeed {
            createdAt = defaultCreatedAt
        }

        let wallpaperLookup = fetchWallpapers(for: draft, in: context)

        let existingItems = Dictionary(uniqueKeysWithValues: orderedItems.map { ($0.id, $0) })
        let desiredEntries = draft.entries.sorted { $0.order < $1.order }

        var resolvedItems: [PlaylistItemEntity] = []
        var seenItemIds: Set<UUID> = []

        for entry in desiredEntries {
            let item = existingItems[entry.id] ?? PlaylistItemEntity(context: context)
            item.id = entry.id
            item.playlist = self
            item.lightWallpaper = entry.lightWallpaperId.flatMap { wallpaperLookup[$0] }
            item.darkWallpaper = entry.darkWallpaperId.flatMap { wallpaperLookup[$0] }
            resolvedItems.append(item)
            seenItemIds.insert(entry.id)
        }

        for (itemId, item) in existingItems where !seenItemIds.contains(itemId) {
            context.delete(item)
        }

        if !resolvedItems.isEmpty {
            for (index, item) in resolvedItems.enumerated() {
                item.order = Int32(index)
            }
            items = NSOrderedSet(array: resolvedItems)
        } else {
            items = nil
        }

        let existingAssignments = Dictionary(uniqueKeysWithValues: orderedDisplayAssignments.map { ($0.id, $0) })
        let desiredAssignments = draft.displayAssignments.sorted { $0.order < $1.order }
        var resolvedAssignments: [DisplayAssignmentEntity] = []
        var seenAssignmentIds: Set<UUID> = []

        for assignment in desiredAssignments {
            let entity = existingAssignments[assignment.id] ?? DisplayAssignmentEntity(context: context)
            entity.id = assignment.id
            entity.displayID = assignment.displayID
            entity.order = Int32(assignment.order)
            entity.playlist = self
            entity.lightWallpaper = assignment.lightWallpaperId.flatMap { wallpaperLookup[$0] }
            entity.darkWallpaper = assignment.darkWallpaperId.flatMap { wallpaperLookup[$0] }
            resolvedAssignments.append(entity)
            seenAssignmentIds.insert(entity.id)
        }

        for (assignmentId, assignment) in existingAssignments where !seenAssignmentIds.contains(assignmentId) {
            context.delete(assignment)
        }

        if !resolvedAssignments.isEmpty {
            for (index, assignment) in resolvedAssignments.enumerated() {
                assignment.order = Int32(index)
            }
            displayAssignments = NSOrderedSet(array: resolvedAssignments)
        } else {
            displayAssignments = nil
        }
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
            playbackMode: playbackMode,
            multiDisplayPolicy: multiDisplayPolicy,
            entries: makeEntryRecords(),
            displayAssignments: orderedDisplayAssignments.map { $0.toRecord() }
        )
    }

    private func fetchWallpapers(for draft: PlaylistDraft, in context: NSManagedObjectContext) -> [UUID: WallpaperEntity] {
        var identifiers: Set<UUID> = []
        draft.entries.forEach { entry in
            if let lightId = entry.lightWallpaperId {
                identifiers.insert(lightId)
            }
            if let darkId = entry.darkWallpaperId {
                identifiers.insert(darkId)
            }
        }
        draft.displayAssignments.forEach { assignment in
            if let lightId = assignment.lightWallpaperId {
                identifiers.insert(lightId)
            }
            if let darkId = assignment.darkWallpaperId {
                identifiers.insert(darkId)
            }
        }

        guard !identifiers.isEmpty else { return [:] }

        let request = WallpaperEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", identifiers as NSSet)

        do {
            let results = try context.fetch(request)
            return Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
        } catch {
            return [:]
        }
    }

    private func makeEntryRecords() -> [PlaylistEntryRecord] {
        let resolvedItems = orderedItems

        if resolvedItems.isEmpty, !orderedWallpapers.isEmpty {
            return orderedWallpapers.enumerated().map { index, wallpaper in
                let entryId = wallpaper.id
                return PlaylistEntryRecord(
                    id: entryId,
                    order: index,
                    lightWallpaper: wallpaper.toRecord(),
                    darkWallpaper: nil
                )
            }
        }

        return resolvedItems.map { $0.toRecord() }
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

extension PlaylistItemEntity {
    func toRecord() -> PlaylistEntryRecord {
        PlaylistEntryRecord(
            id: id,
            order: Int(order),
            lightWallpaper: lightWallpaper?.toRecord(),
            darkWallpaper: darkWallpaper?.toRecord()
        )
    }
}

extension DisplayAssignmentEntity {
    func toRecord() -> DisplayAssignmentRecord {
        DisplayAssignmentRecord(
            id: id,
            displayID: displayID,
            order: Int(order),
            lightWallpaper: lightWallpaper?.toRecord(),
            darkWallpaper: darkWallpaper?.toRecord()
        )
    }
}
