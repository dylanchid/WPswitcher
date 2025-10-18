import Foundation

struct WallpaperDraft: Equatable {
    var url: URL
    var displayName: String
    var bookmarkData: Data?
}

struct WallpaperRecord: Equatable, Identifiable {
    let id: UUID
    let url: URL
    let displayName: String
    let createdAt: Date
    let bookmarkData: Data?
}

enum PlaylistPlaybackMode: String, CaseIterable, Equatable {
    case sequential
    case random
}

enum MultiDisplayPolicy: String, CaseIterable, Equatable {
    case mirror
    case perDisplay
}

struct PlaylistEntryDraft: Identifiable, Equatable {
    var id: UUID
    var order: Int
    var lightWallpaperId: UUID?
    var darkWallpaperId: UUID?
}

struct PlaylistEntryRecord: Identifiable, Equatable {
    let id: UUID
    let order: Int
    let lightWallpaper: WallpaperRecord?
    let darkWallpaper: WallpaperRecord?
}

struct DisplayAssignmentDraft: Identifiable, Equatable {
    var id: UUID
    var displayID: String
    var order: Int
    var lightWallpaperId: UUID?
    var darkWallpaperId: UUID?
}

struct DisplayAssignmentRecord: Identifiable, Equatable {
    let id: UUID
    let displayID: String
    let order: Int
    let lightWallpaper: WallpaperRecord?
    let darkWallpaper: WallpaperRecord?
}

struct PlaylistDraft: Equatable {
    var id: UUID?
    var name: String
    var intervalMinutes: Int
    var playbackMode: PlaylistPlaybackMode
    var multiDisplayPolicy: MultiDisplayPolicy
    var entries: [PlaylistEntryDraft]
    var displayAssignments: [DisplayAssignmentDraft]
}

struct PlaylistRecord: Equatable, Identifiable {
    let id: UUID
    let name: String
    let intervalMinutes: Int
    let createdAt: Date
    let playbackMode: PlaylistPlaybackMode
    let multiDisplayPolicy: MultiDisplayPolicy
    let entries: [PlaylistEntryRecord]
    let displayAssignments: [DisplayAssignmentRecord]

    var hasPerDisplayAssignments: Bool {
        multiDisplayPolicy == .perDisplay && !displayAssignments.isEmpty
    }
}
