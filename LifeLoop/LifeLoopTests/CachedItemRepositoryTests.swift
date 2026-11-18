import Foundation
import SwiftData
import Testing
@testable import LifeLoop

@MainActor
struct CachedItemRepositoryTests {
    @Test func offlineFallbackIsLabelledButUnauthorizedDoesNotUseCache() async throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true),
                                      server: URL(string: "https://example.com")!, accountID: UUID())
        let remote = CacheTestRemote()
        let repository = CachedItemRepository(remote: remote, store: store)
        let fresh = try await repository.fetchItems()
        #expect(repository.cacheDate == nil)
        remote.failure = URLError(.notConnectedToInternet)
        let offline = try await repository.fetchItems()
        #expect(offline.first?.id == fresh.first?.id)
        #expect(repository.cacheDate != nil)
        remote.failure = APIError.unauthorized
        await #expect(throws: APIError.self) { try await repository.fetchItems() }
        #expect(repository.cacheDate == nil)
    }

    @Test func diskStoreReopensWithDraftAndSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("cache.store")
        let accountID = UUID(), itemID = UUID()
        let server = URL(string: "https://example.com")!
        func openStore() throws -> AccountLocalStore {
            let container = try ModelContainer(for: LocalRecord.self, configurations:
                ModelConfiguration("Test", url: url, cloudKitDatabase: .none))
            return AccountLocalStore(container: container, server: server, accountID: accountID)
        }
        do {
            let first = try openStore()
            try first.saveItems([LifeItem(id: itemID, title: "Original", status: .active)])
            try first.saveDraft(ItemDraft(title: "Unsaved", baseRevision: "revision-1"), itemID: itemID)
        }
        let second = try openStore()
        #expect(try second.readItems()?.items.first?.title == "Original")
        #expect(try second.draft(itemID: itemID)?.title == "Unsaved")
        #expect(try second.draft(itemID: itemID)?.baseRevision == "revision-1")
    }

    @Test func updateItemReconcilesCacheAfterRemoteSuccess() async throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true),
                                      server: URL(string: "https://example.com")!, accountID: UUID())
        let remote = CacheTestRemote()
        let repository = CachedItemRepository(remote: remote, store: store)

        let initialItems = try await repository.fetchItems()
        let itemID = initialItems[0].id
        #expect(initialItems[0].title == "Personal item")

        remote.updatedItem = LifeItem(id: itemID, title: "Updated in Cloud", status: .active, revision: 2)
        let updated = try await repository.updateItem(id: itemID, title: "Updated in Cloud", expectedRevision: 1)
        #expect(updated.title == "Updated in Cloud")
        #expect(updated.revision == 2)

        let cached = try store.readItems()
        #expect(cached?.items.first?.title == "Updated in Cloud")
        #expect(cached?.items.first?.revision == 2)

        remote.failure = URLError(.notConnectedToInternet)
        let offlineItems = try await repository.fetchItems()
        #expect(offlineItems.first?.title == "Updated in Cloud")
        #expect(offlineItems.first?.revision == 2)
        #expect(repository.cacheDate != nil)
    }

    @Test func updateItemPropagatesCacheWriteFailure() async throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true),
                                      server: URL(string: "https://example.com")!, accountID: UUID())
        let remote = CacheTestRemote()
        let repository = CachedItemRepository(remote: remote, store: store)

        let initialItems = try await repository.fetchItems()
        let itemID = initialItems[0].id

        try store.purgeAndInvalidate()

        remote.updatedItem = LifeItem(id: itemID, title: "Updated", status: .active, revision: 2)
        await #expect(throws: CancellationError.self) {
            try await repository.updateItem(id: itemID, title: "Updated", expectedRevision: 1)
        }
    }
}

@MainActor
private final class CacheTestRemote: ItemRepository {
    var failure: Error?
    var updatedItem: LifeItem?
    let item = LifeItem(id: UUID(), title: "Personal item", status: .active, revision: 1)
    func fetchItems() async throws -> [LifeItem] {
        if let failure { throw failure }
        return [item]
    }
    func createItem(title: String, itemType: String) async throws -> LifeItem { throw APIError.forbidden }
    func updateItem(id: UUID, title: String, expectedRevision: Int) async throws -> LifeItem {
        if let failure { throw failure }
        if let updatedItem { return updatedItem }
        return LifeItem(id: id, title: title, status: .active, revision: expectedRevision + 1)
    }
    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem { throw APIError.forbidden }
    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem { throw APIError.forbidden }
    func deleteItem(id: UUID, updatedAt: String?) async throws { throw APIError.forbidden }
}
