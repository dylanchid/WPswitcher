import Foundation

final class ServiceRegistry: ObservableObject {
    let persistence: PersistenceController
    let wallpaperService: WallpaperService
    let playlistStore: PlaylistStore
    let schedulerCoordinator: SchedulerCoordinator
    let appearanceObserver: AppearanceObserver
    let errorManager: ErrorManager

    init(
        persistence: PersistenceController = .shared,
        wallpaperService: WallpaperService? = nil,
        playlistStore: PlaylistStore? = nil,
        schedulerCoordinator: SchedulerCoordinator? = nil,
        appearanceObserver: AppearanceObserver = SystemAppearanceObserver(),
        errorManager: ErrorManager = ErrorManager()
    ) {
        self.persistence = persistence
        self.errorManager = errorManager
        let resolvedPlaylistStore = playlistStore ?? CoreDataPlaylistStore(persistence: persistence)
        let resolvedWallpaperService = wallpaperService ?? CoreDataWallpaperService(
            persistence: persistence,
            playlistStore: resolvedPlaylistStore
        )

        self.playlistStore = resolvedPlaylistStore
        self.wallpaperService = resolvedWallpaperService

        if let schedulerCoordinator {
            self.schedulerCoordinator = schedulerCoordinator
        } else {
            self.schedulerCoordinator = DefaultSchedulerCoordinator(
                playlistStore: resolvedPlaylistStore,
                wallpaperService: resolvedWallpaperService
            )
        }
        self.appearanceObserver = appearanceObserver
    }
}

extension ServiceRegistry {
    static let preview: ServiceRegistry = {
        ServiceRegistry(persistence: .preview, errorManager: ErrorManager())
    }()
}
