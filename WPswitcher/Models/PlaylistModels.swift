import Foundation

struct WallpaperDraft: Equatable {
    var url: URL
    var displayName: String
    var bookmarkData: Data?
}

struct PlaylistDraft: Equatable {
    var name: String
    var intervalMinutes: Int
    var wallpapers: [WallpaperDraft]
}

struct WallpaperRecord: Equatable, Identifiable {
    let id: UUID
    let url: URL
    let displayName: String
    let createdAt: Date
    let bookmarkData: Data?
}

struct PlaylistRecord: Equatable, Identifiable {
    let id: UUID
    let name: String
    let intervalMinutes: Int
    let createdAt: Date
    let wallpapers: [WallpaperRecord]
}
