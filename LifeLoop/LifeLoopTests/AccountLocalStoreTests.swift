import Foundation
import Testing
@testable import LifeLoop

@MainActor
struct AccountLocalStoreTests {
    let server = URL(string: "https://example.com")!

    @Test func accountsAndServersCannotReadEachOthersData() throws {
        let container = try AccountLocalStore.makeContainer(inMemory: true)
        let accountA = UUID(), accountB = UUID()
        let a = AccountLocalStore(container: container, server: server, accountID: accountA)
        let b = AccountLocalStore(container: container, server: server, accountID: accountB)
        let otherServer = AccountLocalStore(container: container, server: URL(string: "https://other.example.com")!, accountID: accountA)
        let item = LifeItem(id: UUID(), title: "Private", status: .unknown("future"), metadata: ["amount": .number(42)])
        try a.saveItems([item])
        try a.saveDraft(ItemDraft(title: "Draft", baseRevision: "original"), itemID: item.id)
        #expect(try b.readItems() == nil)
        #expect(try otherServer.readItems() == nil)
        #expect(try b.draft(itemID: item.id) == nil)
        let reopened = AccountLocalStore(container: container, server: server, accountID: accountA)
        #expect(try reopened.readItems()?.items.first?.metadata == item.metadata)
        #expect(try reopened.draft(itemID: item.id)?.baseRevision == "original")
    }

    @Test func logoutPurgesOnlyItsAccountAndRejectsLateWrites() throws {
        let container = try AccountLocalStore.makeContainer(inMemory: true)
        let id = UUID()
        let a = AccountLocalStore(container: container, server: server, accountID: id)
        let b = AccountLocalStore(container: container, server: server, accountID: UUID())
        let item = LifeItem(id: UUID(), title: "Item", status: .active)
        try a.saveItems([item])
        try a.saveDraft(ItemDraft(title: "Draft", baseRevision: nil), itemID: item.id)
        try b.saveItems([item])
        try a.purgeAndInvalidate()
        #expect(throws: CancellationError.self) { try a.saveItems([item]) }
        let reopened = AccountLocalStore(container: container, server: server, accountID: id)
        #expect(try reopened.readItems() == nil)
        #expect(try reopened.draft(itemID: item.id) == nil)
        #expect(try b.readItems()?.items.count == 1)
    }

    @Test func emptyRefreshReplacesOldItemsAndCancelRemovesDraft() throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true), server: server, accountID: UUID())
        let item = LifeItem(id: UUID(), title: "Old", status: .active)
        try store.saveItems([item])
        try store.saveItems([])
        #expect(try store.readItems()?.items.isEmpty == true)
        try store.saveDraft(ItemDraft(title: "Changed", baseRevision: nil), itemID: item.id)
        try store.removeDraft(itemID: item.id)
        #expect(try store.draft(itemID: item.id) == nil)
    }

    @Test func deleteItemRemovesItemFromSnapshot() throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true), server: server, accountID: UUID())
        let item1 = LifeItem(id: UUID(), title: "Item 1", status: .active)
        let item2 = LifeItem(id: UUID(), title: "Item 2", status: .active)
        try store.saveItems([item1, item2])
        try store.deleteItem(id: item1.id)
        let remaining = try store.readItems()?.items
        #expect(remaining?.count == 1)
        #expect(remaining?.first?.id == item2.id)
    }

    @Test func insertItemAddsItemToSnapshot() throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true), server: server, accountID: UUID())
        let item1 = LifeItem(id: UUID(), title: "Existing", status: .active)
        try store.saveItems([item1])
        let newItem = LifeItem(id: UUID(), title: "Inserted", status: .active)
        try store.insertItem(newItem)
        let items = try store.readItems()?.items
        #expect(items?.count == 2)
        #expect(items?.first?.id == newItem.id)
    }

    @Test func authenticationAndCancellationAreNotOfflineErrors() {
        #expect(!CachedItemRepository.canUseCache(URLError(.cancelled)))
        #expect(!CachedItemRepository.canUseCache(URLError(.serverCertificateUntrusted)))
        #expect(CachedItemRepository.canUseCache(URLError(.notConnectedToInternet)))
    }
}
