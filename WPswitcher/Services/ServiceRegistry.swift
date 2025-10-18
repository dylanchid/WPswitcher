import Combine

final class ServiceRegistry: ObservableObject {
    let persistence: PersistenceController
    let wallpaperService: WallpaperService
    let playlistStore: PlaylistStore
    let schedulerCoordinator: SchedulerCoordinator
    let appearanceObserver: AppearanceObserver

    init(
        persistence: PersistenceController = .shared,
        wallpaperService: WallpaperService? = nil,
        playlistStore: PlaylistStore? = nil,
        schedulerCoordinator: SchedulerCoordinator = DefaultSchedulerCoordinator(),
        appearanceObserver: AppearanceObserver = DefaultAppearanceObserver()
    ) {
        self.persistence = persistence
        let resolvedPlaylistStore = playlistStore ?? CoreDataPlaylistStore(persistence: persistence)
        self.playlistStore = resolvedPlaylistStore
        self.wallpaperService = wallpaperService ?? CoreDataWallpaperService(persistence: persistence, playlistStore: resolvedPlaylistStore)
        self.schedulerCoordinator = schedulerCoordinator
        self.appearanceObserver = appearanceObserver
    }
}

extension ServiceRegistry {
    static let preview: ServiceRegistry = {
        ServiceRegistry(persistence: .preview)
    }()
}
