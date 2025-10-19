import AppKit
import Foundation
import os.log

struct ScopedWallpaperURL {
    let url: URL
    let stopAccessing: () -> Void
}

enum WallpaperResolution {
    case available(ScopedWallpaperURL)
    case missing
}

protocol WallpaperService {
    func advanceToNextWallpaper()
    @discardableResult func apply(entry: PlaylistEntryRecord, from playlist: PlaylistRecord) -> Bool
    func toggleRotation()
    func fetchLibrary() throws -> [WallpaperRecord]
    @discardableResult func importWallpapers(from urls: [URL]) throws -> [WallpaperRecord]
    func deleteWallpaper(id: UUID) throws
    func resolveAccess(for wallpaper: WallpaperRecord) -> WallpaperResolution
}

protocol PlaylistStore {
    @discardableResult func createPlaylist(_ draft: PlaylistDraft) throws -> PlaylistRecord
    func fetchPlaylists() throws -> [PlaylistRecord]
    func fetchPlaylist(id: UUID) throws -> PlaylistRecord?
    @discardableResult func updatePlaylist(_ draft: PlaylistDraft) throws -> PlaylistRecord
    func deletePlaylist(id: UUID) throws
    @discardableResult func upsertWallpaper(_ draft: WallpaperDraft) throws -> WallpaperRecord
}

protocol SchedulerCoordinator {
    var isRunning: Bool { get }
    func start()
    func pause()
    func toggleRotation()
}

protocol AppearanceObserver {
    func startObserving()
    func stopObserving()
}

enum PlaylistStoreError: Error {
    case playlistNotFound
    case invalidDraft
}

final class DefaultWallpaperService: WallpaperService {
    func advanceToNextWallpaper() {
        os_log("Advance to next wallpaper (stub)")
    }

    @discardableResult
    func apply(entry: PlaylistEntryRecord, from playlist: PlaylistRecord) -> Bool {
        os_log(
            "Apply playlist entry (stub) %{public}@ from playlist %{public}@",
            entry.id.uuidString,
            playlist.name
        )
        return false
    }

    func toggleRotation() {
        os_log("Toggle wallpaper rotation (stub)")
    }

    func fetchLibrary() throws -> [WallpaperRecord] {
        os_log("Fetch wallpaper library (stub)")
        return []
    }

    func importWallpapers(from urls: [URL]) throws -> [WallpaperRecord] {
        os_log("Import wallpapers (stub) %{public}@", urls.description)
        return []
    }

    func deleteWallpaper(id: UUID) throws {
        os_log("Delete wallpaper (stub) %{public}@", id.uuidString)
    }

    func resolveAccess(for wallpaper: WallpaperRecord) -> WallpaperResolution {
        os_log("Resolve access for wallpaper (stub) %{public}@", wallpaper.id.uuidString)
        return .missing
    }
}

final class DefaultSchedulerCoordinator: SchedulerCoordinator {
    private enum ScheduleUpdateCause: String {
        case start
        case wake
        case manualRefresh
    }

    private enum RotationTrigger: String {
        case timer
        case wakeCatchUp
        case manual
    }

    private let playlistStore: PlaylistStore
    private let wallpaperService: WallpaperService
    private let workspace: NSWorkspace
    private let workspaceNotificationCenter: NotificationCenter
    private let playlistNotificationCenter: NotificationCenter
    private let dateProvider: () -> Date
    private let logger = Logger(subsystem: "com.example.WPswitcher", category: "Scheduler")

    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()
    private let stateQueue = DispatchQueue(label: "com.example.WPswitcher.scheduler.state", qos: .utility)

    private var schedules: [UUID: PlaylistSchedule] = [:]
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var playlistObserver: NSObjectProtocol?
    private var running = false

    private let minimumInterval: TimeInterval = 5 // seconds

    init(
        playlistStore: PlaylistStore,
        wallpaperService: WallpaperService,
        workspace: NSWorkspace = .shared,
        workspaceNotificationCenter: NotificationCenter? = nil,
        playlistNotificationCenter: NotificationCenter = .default,
        dateProvider: @escaping () -> Date = Date.init,
        queue: DispatchQueue? = nil
    ) {
        self.playlistStore = playlistStore
        self.wallpaperService = wallpaperService
        self.workspace = workspace
        self.workspaceNotificationCenter = workspaceNotificationCenter ?? workspace.notificationCenter
        self.playlistNotificationCenter = playlistNotificationCenter
        self.dateProvider = dateProvider
        self.queue = queue ?? DispatchQueue(label: "com.example.WPswitcher.scheduler", qos: .utility)
        self.queue.setSpecific(key: queueKey, value: ())
    }

    var isRunning: Bool {
        stateQueue.sync { running }
    }

    func start() {
        queue.async {
            guard !self.isRunning else {
                self.logger.debug("Scheduler start requested but already running")
                return
            }
            self.logger.log("Starting scheduler")
            self.setRunning(true)
            self.subscribeToWorkspaceNotifications()
            self.subscribeToPlaylistNotifications()
            self.rebuildSchedules(reason: .start)
        }
    }

    func pause() {
        queue.async {
            guard self.isRunning else {
                self.logger.debug("Scheduler pause requested but already stopped")
                return
            }
            self.logger.log("Pausing scheduler")
            self.setRunning(false)
            self.cancelAllTimers(clearRemaining: true)
            self.unsubscribeFromWorkspaceNotifications()
            self.unsubscribeFromPlaylistNotifications()
        }
    }

    func toggleRotation() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    deinit {
        withQueue {
            cancelAllTimers(clearRemaining: true)
            unsubscribeFromWorkspaceNotifications()
            unsubscribeFromPlaylistNotifications()
        }
    }

    // MARK: - Private helpers

    private func setRunning(_ newValue: Bool) {
        stateQueue.sync { running = newValue }
    }

    private func isPlaylistPlayable(_ playlist: PlaylistRecord) -> Bool {
        playlist.entries.contains { $0.lightWallpaper != nil || $0.darkWallpaper != nil }
    }

    private func rebuildSchedules(reason: ScheduleUpdateCause) {
        guard isRunning else { return }

        do {
            let playlists = try playlistStore.fetchPlaylists()
            let playable = playlists.filter(isPlaylistPlayable)
            logger.log("Rebuilding schedules for \(playable.count, privacy: .public) playlists (reason: \(reason.rawValue, privacy: .public))")

            let incomingIds = Set(playable.map(\.id))
            let existingIds = Set(schedules.keys)
            let removed = existingIds.subtracting(incomingIds)

            for identifier in removed {
                if let schedule = schedules.removeValue(forKey: identifier) {
                    schedule.cancelTimer()
                    logger.log("Removed schedule for playlist \(schedule.record.name, privacy: .public)")
                }
            }

            for record in playable {
                let schedule = schedules[record.id] ?? PlaylistSchedule(record: record)
                schedule.update(with: record)
                schedules[record.id] = schedule
                rescheduleTimer(for: schedule, reason: reason)
            }
        } catch {
            logger.error("Failed to rebuild schedules: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func rescheduleTimer(for schedule: PlaylistSchedule, reason: ScheduleUpdateCause) {
        schedule.cancelTimer()

        guard isRunning else { return }
        guard schedule.hasPlayableEntries else {
            logger.warning("Playlist \(schedule.record.name, privacy: .public) has no usable entries; skipping timer setup")
            return
        }

        let interval = schedule.intervalSeconds(minimum: minimumInterval)
        let remaining = schedule.consumeRemainingInterval()
        let initialDelay: TimeInterval

        if let remaining {
            if remaining <= 0 {
                logger.log("Running immediate catch-up rotation for playlist \(schedule.record.name, privacy: .public)")
                performRotation(for: schedule, trigger: .wakeCatchUp)
                initialDelay = interval
            } else {
                initialDelay = remaining
            }
        } else {
            initialDelay = interval
        }

        schedule.prepareRandomCursorIfNeeded()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + max(initialDelay, 0.001), repeating: interval)
        let playlistID = schedule.id
        timer.setEventHandler { [weak self] in
            self?.handleTimerFired(for: playlistID)
        }

        let nextFireDate = dateProvider().addingTimeInterval(max(initialDelay, 0.001))
        schedule.assign(timer: timer, nextFireDate: nextFireDate)
        timer.resume()

        logger.log(
            "Scheduled playlist \(schedule.record.name, privacy: .public) with interval \(interval, privacy: .public)s (delay \(initialDelay, privacy: .public)s, reason \(reason.rawValue, privacy: .public))"
        )
    }

    private func handleTimerFired(for playlistID: UUID) {
        guard isRunning else { return }
        guard let schedule = schedules[playlistID] else { return }

        let interval = schedule.intervalSeconds(minimum: minimumInterval)
        schedule.updateNextFireDate(dateProvider().addingTimeInterval(interval))
        performRotation(for: schedule, trigger: .timer)
    }

    private func performRotation(for schedule: PlaylistSchedule, trigger: RotationTrigger) {
        guard isRunning else { return }
        guard let entry = schedule.nextEntry() else {
            logger.warning("No playable entry available for playlist \(schedule.record.name, privacy: .public); trigger \(trigger.rawValue, privacy: .public)")
            return
        }

        let preview = selectWallpaper(for: entry)
        let applied = wallpaperService.apply(entry: entry, from: schedule.record)

        if applied {
            if let wallpaper = preview {
                logger.log(
                    "Rotated playlist \(schedule.record.name, privacy: .public) to wallpaper \(wallpaper.displayName, privacy: .public) (trigger \(trigger.rawValue, privacy: .public))"
                )
            } else {
                logger.log(
                    "Rotated playlist \(schedule.record.name, privacy: .public) using multi-display assignments (trigger \(trigger.rawValue, privacy: .public))"
                )
            }
        } else {
            logger.error(
                "Failed to rotate playlist \(schedule.record.name, privacy: .public) for entry \(entry.id.uuidString, privacy: .public) (trigger \(trigger.rawValue, privacy: .public))"
            )
        }
    }

    private func selectWallpaper(for entry: PlaylistEntryRecord) -> WallpaperRecord? {
        if isDarkModeEnabled() {
            return entry.darkWallpaper ?? entry.lightWallpaper
        } else {
            return entry.lightWallpaper ?? entry.darkWallpaper
        }
    }

    private func isDarkModeEnabled() -> Bool {
        guard #available(macOS 10.14, *) else { return false }
        let evaluate: () -> Bool = {
            guard let application = NSApp else { return false }
            let match = application.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua
        }
        if Thread.isMainThread {
            return evaluate()
        } else {
            return DispatchQueue.main.sync(execute: evaluate)
        }
    }

    private func cancelAllTimers(clearRemaining: Bool) {
        for schedule in schedules.values {
            if clearRemaining {
                schedule.clearRemainingInterval()
            }
            schedule.cancelTimer()
        }
    }

    private func subscribeToWorkspaceNotifications() {
        guard sleepObserver == nil, wakeObserver == nil else { return }

        sleepObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleWorkspaceWillSleep()
        }

        wakeObserver = workspaceNotificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.handleWorkspaceDidWake()
        }

        logger.log("Registered workspace sleep/wake observers")
    }

    private func unsubscribeFromWorkspaceNotifications() {
        if let sleepObserver {
            workspaceNotificationCenter.removeObserver(sleepObserver)
            self.sleepObserver = nil
        }
        if let wakeObserver {
            workspaceNotificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
    }

    private func handleWorkspaceWillSleep() {
        queue.async {
            guard self.isRunning else { return }
            let now = self.dateProvider()
            for schedule in self.schedules.values {
                schedule.captureRemainingInterval(referenceDate: now)
                schedule.cancelTimer()
            }
            self.logger.log("Workspace entering sleep; captured \(self.schedules.count, privacy: .public) schedules")
        }
    }

    private func handleWorkspaceDidWake() {
        queue.async {
            guard self.isRunning else { return }
            self.logger.log("Workspace woke from sleep; rebuilding schedules")
            self.rebuildSchedules(reason: .wake)
        }
    }

    private func subscribeToPlaylistNotifications() {
        guard playlistObserver == nil else { return }
        playlistObserver = playlistNotificationCenter.addObserver(
            forName: .playlistStoreDidChange,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handlePlaylistStoreDidChange(notification)
        }
        logger.log("Registered playlist store observer")
    }

    private func unsubscribeFromPlaylistNotifications() {
        if let playlistObserver {
            playlistNotificationCenter.removeObserver(playlistObserver)
            self.playlistObserver = nil
        }
    }

    private func handlePlaylistStoreDidChange(_ notification: Notification) {
        queue.async {
            guard self.isRunning else { return }
            if let playlistID = notification.userInfo?["playlistID"] as? UUID,
               let schedule = self.schedules[playlistID] {
                self.logger.log("Playlist \(schedule.record.name, privacy: .public) changed; refreshing schedule")
            } else {
                self.logger.log("Received playlist change notification; refreshing schedules")
            }
            self.rebuildSchedules(reason: .manualRefresh)
        }
    }

    private func withQueue(_ perform: () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            perform()
        } else {
            queue.sync(execute: perform)
        }
    }
}

private final class PlaylistSchedule {
    let id: UUID
    private(set) var record: PlaylistRecord
    private var timer: DispatchSourceTimer?
    private var nextFireDate: Date
    private var remainingInterval: TimeInterval?

    private var validEntries: [PlaylistEntryRecord]
    private var sequentialIndex: Int = 0
    private var randomBag: [Int] = []
    private var lastPlayedEntryID: UUID?

    init(record: PlaylistRecord) {
        self.id = record.id
        self.record = record
        self.validEntries = PlaylistSchedule.filterEntries(in: record)
        self.nextFireDate = Date()
        if record.playbackMode == .random && !validEntries.isEmpty {
            randomBag = Array(validEntries.indices).shuffled()
        }
    }

    var hasPlayableEntries: Bool {
        !validEntries.isEmpty
    }

    func update(with record: PlaylistRecord) {
        self.record = record
        let newEntries = PlaylistSchedule.filterEntries(in: record)
        validEntries = newEntries

        guard !newEntries.isEmpty else {
            sequentialIndex = 0
            randomBag = []
            lastPlayedEntryID = nil
            return
        }

        if let lastPlayedEntryID,
           let lastIndex = newEntries.firstIndex(where: { $0.id == lastPlayedEntryID }) {
            sequentialIndex = (lastIndex + 1) % newEntries.count
        } else if sequentialIndex >= newEntries.count {
            sequentialIndex = sequentialIndex % newEntries.count
        }

        if !newEntries.contains(where: { $0.id == lastPlayedEntryID }) {
            lastPlayedEntryID = nil
        }

        switch record.playbackMode {
        case .sequential:
            randomBag = []
        case .random:
            randomBag = randomBag.filter { $0 < newEntries.count }
            if randomBag.isEmpty {
                randomBag = Array(newEntries.indices).shuffled()
            }
        }
    }

    func assign(timer: DispatchSourceTimer, nextFireDate: Date) {
        self.timer = timer
        self.nextFireDate = nextFireDate
    }

    func cancelTimer() {
        timer?.cancel()
        timer = nil
    }

    func updateNextFireDate(_ date: Date) {
        nextFireDate = date
    }

    func captureRemainingInterval(referenceDate: Date) {
        remainingInterval = max(0, nextFireDate.timeIntervalSince(referenceDate))
    }

    func consumeRemainingInterval() -> TimeInterval? {
        defer { remainingInterval = nil }
        return remainingInterval
    }

    func clearRemainingInterval() {
        remainingInterval = nil
    }

    func prepareRandomCursorIfNeeded() {
        guard record.playbackMode == .random else { return }
        if randomBag.isEmpty {
            randomBag = Array(validEntries.indices).shuffled()
        }
    }

    func nextEntry() -> PlaylistEntryRecord? {
        guard !validEntries.isEmpty else { return nil }

        switch record.playbackMode {
        case .sequential:
            if sequentialIndex >= validEntries.count {
                sequentialIndex = 0
            }
            let index = sequentialIndex
            sequentialIndex = (index + 1) % validEntries.count
            let entry = validEntries[index]
            lastPlayedEntryID = entry.id
            return entry
        case .random:
            if randomBag.isEmpty {
                randomBag = Array(validEntries.indices).shuffled()
            }
            guard !randomBag.isEmpty else { return nil }
            let index = randomBag.removeFirst()
            let entry = validEntries[index]
            lastPlayedEntryID = entry.id
            return entry
        }
    }

    func intervalSeconds(minimum: TimeInterval) -> TimeInterval {
        let computed = TimeInterval(record.intervalMinutes) * 60.0
        return max(computed, minimum)
    }

    private static func filterEntries(in record: PlaylistRecord) -> [PlaylistEntryRecord] {
        record.entries.filter { $0.lightWallpaper != nil || $0.darkWallpaper != nil }
    }
}

final class DefaultAppearanceObserver: AppearanceObserver {
    func startObserving() {
        os_log("Start appearance observer (stub)")
    }

    func stopObserving() {
        os_log("Stop appearance observer (stub)")
    }
}
