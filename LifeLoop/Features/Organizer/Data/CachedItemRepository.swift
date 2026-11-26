import Foundation

@MainActor
final class CachedItemRepository: ItemRepository {
    let remote: any ItemRepository
    let store: AccountLocalStore
    private(set) var cacheDate: Date?

    init(remote: any ItemRepository, store: AccountLocalStore) {
        self.remote = remote
        self.store = store
    }

    func fetchItems() async throws -> [LifeItem] {
        cacheDate = nil
        do {
            let items = try await remote.fetchItems()
            try Task.checkCancellation()
            try store.saveItems(items)
            return items
        } catch let error as URLError where Self.canUseCache(error) {
            try Task.checkCancellation()
            guard let snapshot = try store.readItems() else { throw error }
            cacheDate = snapshot.date
            return snapshot.items
        }
    }

    static func canUseCache(_ error: URLError) -> Bool {
        [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost,
         .cannotFindHost, .dnsLookupFailed].contains(error.code)
    }

    func createItem(title: String, itemType: String) async throws -> LifeItem {
        try await createItem(title: title, itemType: itemType, dueDate: nil)
    }

    func createItem(title: String, itemType: String, dueDate: Date?) async throws -> LifeItem {
        let created = try await remote.createItem(title: title, itemType: itemType, dueDate: dueDate)
        try? store.insertItem(created)
        return created
    }
    func updateItem(id: UUID, title: String, expectedRevision: Int) async throws -> LifeItem {
        let updated = try await remote.updateItem(id: id, title: title, expectedRevision: expectedRevision)
        try store.updateItem(updated)
        return updated
    }
    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        let updated = try await remote.completeItem(id: id, updatedAt: updatedAt)
        try? store.updateItem(updated)
        return updated
    }
    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        let updated = try await remote.reopenItem(id: id, updatedAt: updatedAt)
        try? store.updateItem(updated)
        return updated
    }
    func snoozeItem(id: UUID, snoozeDays: Int) async throws -> LifeItem {
        let updated = try await remote.snoozeItem(id: id, snoozeDays: snoozeDays)
        try? store.updateItem(updated)
        return updated
    }
    func deleteItem(id: UUID, updatedAt: String?) async throws {
        try await remote.deleteItem(id: id, updatedAt: updatedAt)
        try? store.deleteItem(id: id)
    }
    func confirmReviewItem(id: UUID, expectedRevision: Int?) async throws -> LifeItem {
        let updated = try await remote.confirmReviewItem(id: id, expectedRevision: expectedRevision)
        try? store.updateItem(updated)
        return updated
    }
}
