//
//  CachedItemRepositoryTests.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 17/11/26.
//

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

    @Test func deleteItemRemovesFromLocalStoreAfterRemoteSuccess() async throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true),
                                      server: URL(string: "https://example.com")!, accountID: UUID())
        let remote = CacheTestRemote()
        let repository = CachedItemRepository(remote: remote, store: store)

        let initialItems = try await repository.fetchItems()
        let itemID = initialItems[0].id

        try await repository.deleteItem(id: itemID, updatedAt: nil)
        #expect(remote.deletedID == itemID)

        let cached = try store.readItems()
        #expect(cached?.items.isEmpty == true)
    }

    @Test func snoozeItemReconcilesCacheAfterRemoteSuccess() async throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true),
                                      server: URL(string: "https://example.com")!, accountID: UUID())
        let remote = CacheTestRemote()
        let repository = CachedItemRepository(remote: remote, store: store)

        let initialItems = try await repository.fetchItems()
        let itemID = initialItems[0].id

        let snoozed = try await repository.snoozeItem(id: itemID, snoozeDays: 1)
        #expect(snoozed.status == .snoozed)

        let cached = try store.readItems()
        #expect(cached?.items.first?.status == .snoozed)
    }

    @Test func createItemReconcilesCacheAfterRemoteSuccess() async throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true),
                                      server: URL(string: "https://example.com")!, accountID: UUID())
        let remote = CacheTestRemote()
        let repository = CachedItemRepository(remote: remote, store: store)

        let createdItem = LifeItem(id: UUID(), title: "Cached Created Item", status: .active, itemType: "task", revision: 1)
        remote.createdItem = createdItem

        let result = try await repository.createItem(title: "Cached Created Item", itemType: "task")
        #expect(result.id == createdItem.id)

        let snapshot = try store.readItems()
        #expect(snapshot?.items.first?.id == createdItem.id)
        #expect(snapshot?.items.first?.title == "Cached Created Item")
    }

    @Test func deletedCaptureItemsAreNotRestoredToViewModelOrDiskCacheByStaleFetch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("cache.store")
        let server = URL(string: "https://example.com")!
        let accountID = UUID()

        func openStore() throws -> AccountLocalStore {
            let container = try ModelContainer(for: LocalRecord.self, configurations:
                ModelConfiguration("RaceB", url: url, cloudKitDatabase: .none))
            return AccountLocalStore(container: container, server: server, accountID: accountID)
        }

        let captureA = UUID()
        let itemA = LifeItem(id: UUID(), title: "Extracted from A", status: .pendingReview, revision: 1, captureId: captureA)
        let itemB = LifeItem(id: UUID(), title: "Unrelated item", status: .active, revision: 1)

        let store = try openStore()
        let remote = CacheTestRemote()
        remote.itemsToReturn = [itemA, itemB]
        let repository = CachedItemRepository(remote: remote, store: store)
        let viewModel = ItemsListViewModel(repository: repository)

        await viewModel.load()
        #expect(viewModel.items.map(\.id) == [itemA.id, itemB.id])
        #expect(try store.readItems()?.items.map(\.id) == [itemA.id, itemB.id])

        let staleFetch = CacheRequestGate<[LifeItem]>()
        remote.fetchRequests = [staleFetch]
        let refreshTask = Task { await viewModel.refreshAfterCapture() }
        await staleFetch.waitUntilStarted()

        // Complete capture A's deletion and local cleanup while the item fetch is still in flight.
        viewModel.removeItems(forCaptureID: captureA)
        try store.deleteItems(forCaptureID: captureA)
        #expect(viewModel.items.map(\.id) == [itemB.id])
        #expect(try store.readItems()?.items.map(\.id) == [itemB.id])

        // Underlying transport ignores cancellation and delivers the stale pre-delete snapshot.
        staleFetch.resolve(.success([itemA, itemB]))
        await refreshTask.value

        #expect(viewModel.items.map(\.id) == [itemB.id])
        #expect(try store.readItems()?.items.map(\.id) == [itemB.id])

        // Reopen a fresh store consumer & perform an offline fetch to prove disk cache stays clean.
        let freshStore = try openStore()
        #expect(try freshStore.readItems()?.items.map(\.id) == [itemB.id])
        let offlineRemote = CacheTestRemote()
        offlineRemote.failure = URLError(.notConnectedToInternet)
        let offlineRepo = CachedItemRepository(remote: offlineRemote, store: freshStore)
        let offlineItems = try await offlineRepo.fetchItems()
        #expect(offlineItems.map(\.id) == [itemB.id])
        #expect(offlineRepo.cacheDate != nil)
    }

    @Test func captureDeletionWhileItemsViewModelIsLoadingExcludesDeletedItemsAndEndsLoading() async throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true),
                                      server: URL(string: "https://example.com")!, accountID: UUID())
        let remote = CacheTestRemote()
        let repository = CachedItemRepository(remote: remote, store: store)
        let viewModel = ItemsListViewModel(repository: repository)

        let captureA = UUID()
        let itemA = LifeItem(id: UUID(), title: "Extracted from A", status: .pendingReview, revision: 1, captureId: captureA)
        let itemB = LifeItem(id: UUID(), title: "Unrelated item", status: .active, revision: 1)

        let loadingGate = CacheRequestGate<[LifeItem]>()
        remote.fetchRequests = [loadingGate]

        let loadTask = Task { await viewModel.forceLoad() }
        await loadingGate.waitUntilStarted()
        guard case .loading = viewModel.state else {
            Issue.record("Expected ItemsListViewModel to be in .loading state")
            return
        }

        // Deletion completes while ItemsListViewModel is still loading.
        viewModel.removeItems(forCaptureID: captureA)
        try store.deleteItems(forCaptureID: captureA)

        loadingGate.resolve(.success([itemA, itemB]))
        await loadTask.value

        #expect(viewModel.items.map(\.id) == [itemB.id])
        #expect(try store.readItems()?.items.map(\.id) == [itemB.id])

        // Subsequent legitimate refresh works normally.
        let itemC = LifeItem(id: UUID(), title: "Fresh item", status: .active, revision: 1)
        remote.itemsToReturn = [itemC, itemB]
        await viewModel.refreshAfterCapture()
        #expect(viewModel.items.map(\.id) == [itemC.id, itemB.id])
        #expect(try store.readItems()?.items.map(\.id) == [itemC.id, itemB.id])
    }

    @Test func failedCaptureDeletePreservesRowItemsAndOfflineCache() async throws {
        let store = AccountLocalStore(container: try AccountLocalStore.makeContainer(inMemory: true),
                                      server: URL(string: "https://example.com")!, accountID: UUID())
        let remote = CacheTestRemote()
        let captureA = Capture(id: UUID(), rawPayload: "Capture A", processingStatus: .completed, createdAt: Date())
        let itemA = LifeItem(id: UUID(), title: "Extracted A", status: .pendingReview, revision: 1, captureId: captureA.id)
        let itemB = LifeItem(id: UUID(), title: "Unrelated B", status: .active, revision: 1)
        remote.itemsToReturn = [itemA, itemB]

        let itemRepo = CachedItemRepository(remote: remote, store: store)
        let itemsVM = ItemsListViewModel(repository: itemRepo)
        let captureRepo = CacheTestCaptureRepository(captures: [captureA], deleteFailure: APIError.server(500))
        let captureVM = CaptureViewModel(repository: captureRepo)
        captureVM.setForegroundActive(true)
        captureVM.onCaptureDeleted = { id in
            itemsVM.removeItems(forCaptureID: id)
            try? store.deleteItems(forCaptureID: id)
        }

        await captureVM.loadCaptures()
        await itemsVM.load()
        #expect(captureVM.captures.map(\.id) == [captureA.id])
        #expect(itemsVM.items.map(\.id) == [itemA.id, itemB.id])

        let deleted = await captureVM.deleteCapture(captureA)
        #expect(deleted == false)
        #expect(captureVM.actionError != nil)
        #expect(captureVM.captures.map(\.id) == [captureA.id])
        #expect(itemsVM.items.map(\.id) == [itemA.id, itemB.id])
        #expect(try store.readItems()?.items.map(\.id) == [itemA.id, itemB.id])
    }

    @Test func staleItemResponseAfterResetAndPurgeCannotRestorePreviousAccountCache() async throws {
        let container = try AccountLocalStore.makeContainer(inMemory: true)
        let server = URL(string: "https://example.com")!
        let accountA = UUID()
        let oldStore = AccountLocalStore(container: container, server: server, accountID: accountA)
        let remote = CacheTestRemote()
        let oldRepo = CachedItemRepository(remote: remote, store: oldStore)
        let viewModel = ItemsListViewModel(repository: oldRepo)

        let staleItem = LifeItem(id: UUID(), title: "Account A Item", status: .active, revision: 1, captureId: UUID())
        let gate = CacheRequestGate<[LifeItem]>()
        remote.fetchRequests = [gate]

        let oldLoad = Task { await viewModel.load() }
        await gate.waitUntilStarted()

        // Simulate logout / reset while the old transport fetch is still in flight.
        try oldStore.purgeAndInvalidate()
        viewModel.reset()
        guard case .idle = viewModel.state else {
            Issue.record("Expected viewModel to reset to .idle")
            return
        }

        gate.resolve(.success([staleItem]))
        await oldLoad.value

        guard case .idle = viewModel.state else {
            Issue.record("Stale pre-reset response must not overwrite reset state")
            return
        }
        #expect(viewModel.items.isEmpty)

        let reopenedStore = AccountLocalStore(container: container, server: server, accountID: accountA)
        #expect(try reopenedStore.readItems() == nil)
    }
}

@MainActor
private final class CacheTestCaptureRepository: CaptureRepository {
    var captures: [Capture]
    var deleteFailure: Error?

    init(captures: [Capture], deleteFailure: Error? = nil) {
        self.captures = captures
        self.deleteFailure = deleteFailure
    }

    func fetchCaptures() async throws -> [Capture] { captures }
    func createCapture(text: String, source: String) async throws -> Capture {
        Capture(id: UUID(), source: source, rawPayload: text)
    }
    func retryCapture(id: UUID) async throws {}
    func deleteCapture(id: UUID) async throws {
        if let deleteFailure { throw deleteFailure }
        captures.removeAll { $0.id == id }
    }
}

/// Deliberately ignores task cancellation so tests can deliver stale in-flight responses.
@MainActor
private final class CacheRequestGate<Value: Sendable> {
    private var result: Result<Value, Error>?
    private var continuation: CheckedContinuation<Value, Error>?
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []

    func value() async throws -> Value {
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll()
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }

    func resolve(_ result: Result<Value, Error>) {
        self.result = result
        continuation?.resume(with: result)
        continuation = nil
    }
}

@MainActor
private final class CacheTestRemote: ItemRepository {
    var failure: Error?
    var updatedItem: LifeItem?
    var createdItem: LifeItem?
    var deletedID: UUID?
    var itemsToReturn: [LifeItem]?
    var fetchRequests: [CacheRequestGate<[LifeItem]>] = []
    let item = LifeItem(id: UUID(), title: "Personal item", status: .active, revision: 1)
    func fetchItems() async throws -> [LifeItem] {
        if !fetchRequests.isEmpty { return try await fetchRequests.removeFirst().value() }
        if let failure { throw failure }
        return itemsToReturn ?? [item]
    }
    func createItem(title: String, itemType: String) async throws -> LifeItem {
        if let failure { throw failure }
        if let createdItem { return createdItem }
        return LifeItem(id: UUID(), title: title, status: .active, itemType: itemType, revision: 1)
    }
    func updateItem(id: UUID, title: String, expectedRevision: Int) async throws -> LifeItem {
        if let failure { throw failure }
        if let updatedItem { return updatedItem }
        return LifeItem(id: id, title: title, status: .active, revision: expectedRevision + 1)
    }
    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem { throw APIError.forbidden }
    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem { throw APIError.forbidden }
    func snoozeItem(id: UUID, snoozeDays: Int) async throws -> LifeItem {
        if let failure { throw failure }
        return LifeItem(id: id, title: "Personal item", status: .snoozed, revision: 2)
    }
    func deleteItem(id: UUID, updatedAt: String?) async throws {
        if let failure { throw failure }
        deletedID = id
    }
}
