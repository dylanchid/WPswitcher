import CoreData
import os.log

final class PersistenceController {
    static let shared = PersistenceController()
    private static let logger = Logger(subsystem: "com.example.WPswitcher", category: "Persistence")

    let container: NSPersistentContainer
    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = Self.makeContainer(inMemory: inMemory)
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    private static func makeContainer(inMemory: Bool) -> NSPersistentContainer {
        let primary = NSPersistentContainer(name: "DataModel")
        configurePersistentStore(primary, inMemory: inMemory)
        do {
            try loadPersistentStores(primary)
            return primary
        } catch {
            logger.error("Failed to load persistent store: \(error.localizedDescription, privacy: .public). Falling back to in-memory store.")
            let fallback = NSPersistentContainer(name: "DataModel")
            configurePersistentStore(fallback, inMemory: true)
            do {
                try loadPersistentStores(fallback)
                return fallback
            } catch {
                fatalError("Unresolved error loading fallback persistent store: \(error)")
            }
        }
    }

    private static func configurePersistentStore(_ container: NSPersistentContainer, inMemory: Bool) {
        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
    }

    private static func loadPersistentStores(_ container: NSPersistentContainer) throws {
        let semaphore = DispatchSemaphore(value: 0)
        let expectedCallbacks = max(container.persistentStoreDescriptions.count, 1)
        var callbacksRemaining = expectedCallbacks
        var firstError: Error?

        container.loadPersistentStores { _, error in
            if firstError == nil, let error {
                firstError = error
            }
            callbacksRemaining -= 1
            if callbacksRemaining == 0 {
                semaphore.signal()
            }
        }

        semaphore.wait()
        if let firstError {
            throw firstError
        }
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
}

extension PersistenceController {
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        return controller
    }()
}
