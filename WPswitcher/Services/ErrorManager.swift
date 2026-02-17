import Foundation
import os.log

enum AppError: LocalizedError {
    case wallpaperImportFailed(String)
    case wallpaperApplicationFailed(String)
    case playlistOperationFailed(String)
    case fileAccessDenied(String)
    case invalidImageData(String)
    case coreDataError(String)
    case unknownError(String)

    static var maxWallpaperFileSize: Int64 = 100 * 1024 * 1024 // 100MB default

    var errorDescription: String? {
        switch self {
        case .wallpaperImportFailed(let filename):
            return "Failed to import wallpaper '\(filename)': The file may be corrupted or in an unsupported format."
        case .wallpaperApplicationFailed(let reason):
            return "Could not apply wallpaper: \(reason)"
        case .playlistOperationFailed(let operation):
            return "Playlist operation failed: \(operation)"
        case .fileAccessDenied(let path):
            return "File access denied: \(path). Please check file permissions."
        case .invalidImageData(let filename):
            return "Invalid image data in '\(filename)': The file may be corrupted."
        case .coreDataError(let details):
            return "Database error: \(details)"
        case .unknownError(let message):
            return "An unexpected error occurred: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .wallpaperImportFailed:
            return "Try selecting a different image file or check if the file is accessible."
        case .wallpaperApplicationFailed:
            return "Try selecting a different wallpaper or check system permissions."
        case .playlistOperationFailed:
            return "Try the operation again or restart the application."
        case .fileAccessDenied:
            return "Grant file access permissions in System Preferences > Security & Privacy."
        case .invalidImageData:
            return "Try opening the file in an image editor to verify it's not corrupted."
        case .coreDataError:
            return "Try restarting the application. If the problem persists, contact support."
        case .unknownError:
            return "Try restarting the application. If the problem continues, please report this issue."
        }
    }
}

final class ErrorManager: ObservableObject, @unchecked Sendable {
    @Published var currentError: AppError?
    @Published var showError = false
    @Published var errorQueue: [AppError] = []
    
    private let logger = Logger(subsystem: "com.example.WPswitcher", category: "ErrorManager")
    private let autoDismissInterval: TimeInterval
    private var errorTimer: Timer?

    init(autoDismissInterval: TimeInterval = 5.0) {
        self.autoDismissInterval = autoDismissInterval
    }

    @MainActor
    func handle(_ error: Error, context: String = "") {
        let appError = mapToAppError(error)

        logger.error("Error in \(context, privacy: .public): \(appError.localizedDescription, privacy: .public)")

        if errorQueue.isEmpty {
            currentError = appError
            showError = true
        }

        errorQueue.append(appError)
        scheduleAutoDismiss()
    }

    @MainActor
    func dismissCurrentError() {
        guard !errorQueue.isEmpty else { return }
        
        errorQueue.removeFirst()
        
        if let nextError = errorQueue.first {
            currentError = nextError
            scheduleAutoDismiss()
        } else {
            currentError = nil
            showError = false
            errorTimer?.invalidate()
            errorTimer = nil
        }
    }

    @MainActor
    func clearAll() {
        currentError = nil
        showError = false
        errorQueue.removeAll()
        errorTimer?.invalidate()
        errorTimer = nil
    }

    @MainActor
    private func scheduleAutoDismiss() {
        errorTimer?.invalidate()
        errorTimer = Timer.scheduledTimer(withTimeInterval: autoDismissInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.dismissCurrentError()
            }
        }
    }

    private func mapToAppError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }
        
        if let nsError = error as NSError? {
            switch nsError.domain {
            case NSCocoaErrorDomain:
                switch nsError.code {
                case NSFileReadNoPermissionError, NSFileWriteNoPermissionError:
                    return .fileAccessDenied(nsError.localizedDescription)
                case NSFileReadCorruptFileError:
                    return .invalidImageData(nsError.localizedDescription)
                default:
                    break
                }
            default:
                break
            }
        }
        
        return .unknownError(error.localizedDescription)
    }
}
