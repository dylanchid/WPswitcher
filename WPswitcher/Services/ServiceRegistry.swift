import Combine
import Foundation

final class SchedulerViewState: ObservableObject {
    @Published private(set) var isRunning: Bool
    @Published private(set) var activePlaylistID: UUID?
    @Published private(set) var lastRotatedPlaylistID: UUID?
    @Published private(set) var rotationEventCount: Int = 0

    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(
        schedulerCoordinator: SchedulerCoordinator,
        notificationCenter: NotificationCenter = .default
    ) {
        self.notificationCenter = notificationCenter
        self.isRunning = schedulerCoordinator.isRunning
        self.activePlaylistID = schedulerCoordinator.activePlaylistID
        observeNotifications()
    }

    deinit {
        observers.forEach(notificationCenter.removeObserver)
    }

    func refresh(from schedulerCoordinator: SchedulerCoordinator) {
        isRunning = schedulerCoordinator.isRunning
        activePlaylistID = schedulerCoordinator.activePlaylistID
    }

    private func observeNotifications() {
        observers.append(
            notificationCenter.addObserver(
                forName: .schedulerCoordinatorStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else { return }
                if let isRunning = notification.userInfo?[SchedulerNotificationKey.isRunning] as? Bool {
                    self.isRunning = isRunning
                }
                self.activePlaylistID = notification.userInfo?[SchedulerNotificationKey.activePlaylistID] as? UUID
            }
        )

        observers.append(
            notificationCenter.addObserver(
                forName: .schedulerCoordinatorDidRotateWallpaper,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else { return }
                self.lastRotatedPlaylistID = notification.userInfo?[SchedulerNotificationKey.playlistID] as? UUID
                self.rotationEventCount += 1
            }
        )
    }
}

final class ServiceRegistry: ObservableObject {
    let persistence: PersistenceController
    let wallpaperService: WallpaperService
    let playlistStore: PlaylistStore
    let schedulerCoordinator: SchedulerCoordinator
    let appearanceObserver: AppearanceObserver
    let errorManager: ErrorManager
    let schedulerState: SchedulerViewState

    init(
        persistence: PersistenceController = .shared,
        wallpaperService: WallpaperService? = nil,
        playlistStore: PlaylistStore? = nil,
        schedulerCoordinator: SchedulerCoordinator? = nil,
        appearanceObserver: AppearanceObserver = SystemAppearanceObserver(),
        errorManager: ErrorManager = ErrorManager(),
        notificationCenter: NotificationCenter = .default
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
                wallpaperService: resolvedWallpaperService,
                notificationCenter: notificationCenter
            )
        }
        self.appearanceObserver = appearanceObserver
        self.schedulerState = SchedulerViewState(
            schedulerCoordinator: self.schedulerCoordinator,
            notificationCenter: notificationCenter
        )
    }
}

extension ServiceRegistry {
    static let preview: ServiceRegistry = {
        ServiceRegistry(persistence: .preview, errorManager: ErrorManager())
    }()
}
