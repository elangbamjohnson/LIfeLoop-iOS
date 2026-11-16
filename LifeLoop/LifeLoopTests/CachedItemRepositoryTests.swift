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
}

@MainActor
private final class CacheTestRemote: ItemRepository {
    var failure: Error?
    let item = LifeItem(id: UUID(), title: "Personal item", status: .active)
    func fetchItems() async throws -> [LifeItem] {
        if let failure { throw failure }
        return [item]
    }
    func createItem(title: String, itemType: String) async throws -> LifeItem { throw APIError.forbidden }
    func updateItem(id: UUID, title: String, updatedAt: String?) async throws -> LifeItem { throw APIError.forbidden }
    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem { throw APIError.forbidden }
    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem { throw APIError.forbidden }
    func deleteItem(id: UUID, updatedAt: String?) async throws { throw APIError.forbidden }
}
