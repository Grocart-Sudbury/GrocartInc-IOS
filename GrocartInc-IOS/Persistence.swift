//
//  Persistence.swift
//  GrocartInc-IOS
//
//  Created by Athul Babu on 2026-02-03.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        for _ in 0..<10 {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
        }
        do {
            try viewContext.save()
        } catch {
            // Preview data only — log and continue instead of crashing.
            NSLog("[Persistence] Preview save failed: \(error)")
        }
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "GrocartInc_IOS")
        if inMemory {
            if let description = container.persistentStoreDescriptions.first {
                description.url = URL(fileURLWithPath: "/dev/null")
            }
        }
        loadPersistentStore()
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    /// Loads the on-disk store. If it fails (disk full, failed migration,
    /// data protection while the device is locked), the corrupt store
    /// files are deleted and loading is retried once; if that still
    /// fails, the app falls back to an in-memory store so it still
    /// launches and shows its UI instead of terminating.
    private func loadPersistentStore() {
        container.loadPersistentStores { [weak container] storeDescription, error in
            guard let container = container else { return }
            if let error = error as NSError? {
                NSLog("[Persistence] Failed to load store: \(error), \(error.userInfo)")
                Self.recover(container: container, failedStoreURL: storeDescription.url)
            }
        }
    }

    private static func recover(container: NSPersistentContainer, failedStoreURL: URL?) {
        // Try once to rebuild: delete the corrupt store files and reload.
        if let storeURL = failedStoreURL {
            let fileManager = FileManager.default
            for suffix in ["", "-wal", "-shm"] {
                let fileURL = suffix.isEmpty
                    ? storeURL
                    : URL(fileURLWithPath: storeURL.path + suffix)
                try? fileManager.removeItem(at: fileURL)
            }
            container.loadPersistentStores { _, retryError in
                if let retryError = retryError {
                    NSLog("[Persistence] Store rebuild failed: \(retryError), falling back to an in-memory store")
                    addInMemoryStore(to: container)
                }
            }
            return
        }
        addInMemoryStore(to: container)
    }

    private static func addInMemoryStore(to container: NSPersistentContainer) {
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error = error {
                // Last resort: log and continue with no store. The app
                // can still show its UI; Core Data reads just come back
                // empty instead of crashing the launch.
                NSLog("[Persistence] In-memory fallback failed: \(error)")
            }
        }
    }
}
