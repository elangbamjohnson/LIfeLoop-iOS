//
//  ItemsListViewModelTests.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation
import Testing
@testable import LifeLoop

@MainActor
struct ItemsListViewModelTests {
    @Test("Successful loading preserves the returned item")
    func loadReturnsItems() async {
        let item = makeItem()
        let repository = StubItemRepository(
            result: .success([item])
        )
        let viewModel = ItemsListViewModel(
            repository: repository
        )

        await viewModel.load()

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected loaded state")
            return
        }

        #expect(items.count == 1)
        #expect(items.first?.id == item.id)
        #expect(items.first?.title == item.title)
        #expect(items.first?.status == item.status)
    }

    @Test("An empty response produces the empty state")
    func loadHandlesEmptyResponse() async {
        let repository = StubItemRepository(
            result: .success([])
        )
        let viewModel = ItemsListViewModel(
            repository: repository
        )

        await viewModel.load()

        guard case .empty = viewModel.state else {
            Issue.record("Expected empty state")
            return
        }
    }

    @Test("A repository error produces a readable failure")
    func loadHandlesFailure() async {
        let repository = StubItemRepository(
            result: .failure(StubError.unavailable)
        )
        let viewModel = ItemsListViewModel(
            repository: repository
        )

        await viewModel.load()

        guard case .failed(let message) = viewModel.state else {
            Issue.record("Expected failed state")
            return
        }

        #expect(!message.isEmpty)
    }

    @Test("Retry can recover from an earlier failure")
    func retryRecoversFromFailure() async {
        let repository = StubItemRepository(
            result: .failure(StubError.unavailable)
        )
        let viewModel = ItemsListViewModel(
            repository: repository
        )

        await viewModel.load()

        guard case .failed = viewModel.state else {
            Issue.record("Expected the first load to fail")
            return
        }

        let item = makeItem()
        repository.result = .success([item])

        await viewModel.load()

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected retry to load items")
            return
        }

        #expect(items.count == 1)
        #expect(items.first?.id == item.id)
    }

    @Test("Repository cancellation does not become an error")
    func cancellationReturnsToIdle() async {
        let repository = StubItemRepository(
            result: .failure(CancellationError())
        )
        let viewModel = ItemsListViewModel(
            repository: repository
        )

        await viewModel.load()

        guard case .idle = viewModel.state else {
            Issue.record("Expected idle state after cancellation")
            return
        }
    }

    @Test("Editing a title survives returning to the list")
    func titleEditSurvivesReloadCheck() async {
        let originalItem = makeItem()
        let repository = StubItemRepository(
            result: .success([originalItem])
        )
        let viewModel = ItemsListViewModel(
            repository: repository
        )

        await viewModel.load()

        var updatedItem = originalItem
        updatedItem.title = "Pay electricity bill tomorrow"

        viewModel.updateItem(updatedItem)
        await viewModel.loadIfNeeded()

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected loaded state")
            return
        }

        #expect(items.count == 1)
        #expect(items.first?.title == updatedItem.title)
        #expect(items.first?.id == originalItem.id)
        #expect(items.first?.status == originalItem.status)
    }

    @Test("forceLoad refetches even when already loaded")
    func forceLoadRefetchesEvenWhenLoaded() async {
        let firstItem = makeItem()
        let repository = StubItemRepository(result: .success([firstItem]))
        let viewModel = ItemsListViewModel(repository: repository)

        await viewModel.load()

        guard case .loaded(let firstItems) = viewModel.state else {
            Issue.record("Expected loaded state after first load")
            return
        }
        #expect(firstItems.count == 1)
        #expect(firstItems.first?.id == firstItem.id)

        let secondItem = makeItem()
        repository.result = .success([secondItem])

        await viewModel.forceLoad()

        guard case .loaded(let secondItems) = viewModel.state else {
            Issue.record("Expected loaded state after forceLoad")
            return
        }
        #expect(secondItems.count == 1)
        #expect(secondItems.first?.id == secondItem.id)
    }

    @Test("saveTitle updates item title and revision in state")
    func saveTitleUpdatesItemInState() async throws {
        let item = makeItem()
        let repository = StubItemRepository(result: .success([item]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        let updated = try await viewModel.saveTitle(for: item, newTitle: "Updated title")
        #expect(updated.title == "Updated title")
        #expect(updated.revision == 2)

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(items.first?.title == "Updated title")
        #expect(items.first?.revision == 2)
    }

    @Test("saveTitle rejects item without positive revision")
    func saveTitleRejectsMissingOrInvalidRevision() async throws {
        let itemWithoutRev = makeItem(revision: nil)
        let itemWithZeroRev = makeItem(revision: 0)
        let repository = StubItemRepository(result: .success([itemWithoutRev, itemWithZeroRev]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        await #expect(throws: ItemMutationError.invalidRevision) {
            try await viewModel.saveTitle(for: itemWithoutRev, newTitle: "Updated title")
        }
        await #expect(throws: ItemMutationError.invalidRevision) {
            try await viewModel.saveTitle(for: itemWithZeroRev, newTitle: "Updated title")
        }
    }

    @Test("completeItem moves item to completed status")
    func completeItemUpdatesStatus() async {
        let item = makeItem()
        let repository = StubItemRepository(result: .success([item]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        await viewModel.completeItem(item)

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(items.first?.status == .completed)
    }

    @Test("reopenItem restores active status")
    func reopenItemUpdatesStatus() async {
        var item = makeItem()
        item.status = .completed
        let repository = StubItemRepository(result: .success([item]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        await viewModel.reopenItem(item)

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(items.first?.status == .active)
    }

    @Test("createItem inserts new item at top of loaded list")
    func createItemAddsToLoadedList() async throws {
        let existing = makeItem()
        let repository = StubItemRepository(result: .success([existing]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        let created = try await viewModel.createItem(title: "Brand New Item", itemType: "task")
        #expect(created.title == "Brand New Item")
        #expect(viewModel.items.count == 2)
        #expect(viewModel.items.first?.id == created.id)
    }

    @Test("createItem transitions empty state to loaded with 1 item")
    func createItemTransitionsFromEmptyToLoaded() async throws {
        let repository = StubItemRepository(result: .success([]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()
        #expect(viewModel.items.isEmpty)

        let created = try await viewModel.createItem(title: "First Item", itemType: "task")
        #expect(created.title == "First Item")
        #expect(viewModel.items.count == 1)
        #expect(viewModel.items.first?.title == "First Item")
    }

    @Test("createItem throws on empty title")
    func createItemThrowsOnEmptyTitle() async {
        let repository = StubItemRepository(result: .success([]))
        let viewModel = ItemsListViewModel(repository: repository)

        await #expect(throws: ItemMutationError.emptyTitle) {
            _ = try await viewModel.createItem(title: "   ", itemType: "task")
        }
    }

    @Test("deleteItem removes item after acknowledgement")
    func deleteItemRemovesFromList() async {
        let item = makeItem()
        let repository = StubItemRepository(result: .success([item]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        await viewModel.deleteItem(item)

        guard case .empty = viewModel.state else {
            Issue.record("Expected empty state after deleting the only item")
            return
        }
    }

    @Test("deleteItem preserves items on failure")
    func deleteItemRollbackOnFailure() async {
        let item = makeItem()
        let repository = StubItemRepository(result: .success([item]))
        repository.deleteResult = .failure(StubError.unavailable)
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        await viewModel.deleteItem(item)

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected loaded state after rollback")
            return
        }
        #expect(items.count == 1)
        #expect(items.first?.id == item.id)
        #expect(viewModel.actionError != nil)
    }

    @Test("snoozeItem moves item to snoozed status")
    func snoozeItemUpdatesState() async {
        let item = makeItem()
        let repository = StubItemRepository(result: .success([item]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        await viewModel.snoozeItem(item, days: 3)

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected loaded state")
            return
        }
        #expect(items.first?.status == .snoozed)
    }

    @Test("snoozeItem sets actionError on failure")
    func snoozeItemSetsErrorOnFailure() async {
        let item = makeItem()
        let repository = StubItemRepository(result: .success([item]))
        repository.snoozeResult = .failure(StubError.unavailable)
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        await viewModel.snoozeItem(item, days: 1)

        guard case .loaded(let items) = viewModel.state else {
            Issue.record("Expected loaded state to be preserved on failure")
            return
        }
        #expect(items.first?.status == .active)
        #expect(viewModel.actionError != nil)
    }

    @Test func confirmReviewPromotesPendingItemToActive() async {
        let pending = LifeItem(id: UUID(), title: "Pending Task", status: .pendingReview, revision: 1)
        let repository = StubItemRepository(result: .success([pending]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        await viewModel.confirmReview(pending)

        #expect(viewModel.items.first?.status == .active)
        #expect(viewModel.actionError == nil)
    }

    @Test func confirmReviewRejectsMissingOrInvalidRevision() async {
        let invalidItem = LifeItem(id: UUID(), title: "Pending Task", status: .pendingReview, revision: nil)
        let repository = StubItemRepository(result: .success([invalidItem]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        await viewModel.confirmReview(invalidItem)

        #expect(viewModel.items.first?.status == .pendingReview)
        #expect(viewModel.actionError == ItemMutationError.invalidRevision.errorDescription)
    }

    @Test func confirmReviewPropagatesConflictError() async {
        let pending = LifeItem(id: UUID(), title: "Pending Task", status: .pendingReview, revision: 2)
        let repository = StubItemRepository(result: .success([pending]))
        repository.confirmReviewResult = .failure(ItemMutationError.conflict)
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()

        await viewModel.confirmReview(pending)

        #expect(viewModel.items.first?.status == .pendingReview)
        #expect(viewModel.actionError == ItemMutationError.conflict.errorDescription)
    }

    @Test func captureRefreshFailureKeepsReviewItemsAndRecoveryClearsError() async {
        let pending = LifeItem(id: UUID(), title: "Review this", status: .pendingReview, revision: 1)
        let repository = StubItemRepository(result: .success([pending]))
        let viewModel = ItemsListViewModel(repository: repository)
        await viewModel.load()
        repository.result = .failure(StubError.unavailable)
        await viewModel.refreshAfterCapture()
        #expect(viewModel.items == [pending])
        #expect(viewModel.refreshError != nil)
        repository.result = .success([])
        await viewModel.refreshAfterCapture()
        guard case .empty = viewModel.state else {
            Issue.record("Expected the successful empty response to replace saved items")
            return
        }
        #expect(viewModel.refreshError == nil)
    }

    private func makeItem(revision: Int? = 1) -> LifeItem {
        LifeItem(
            id: UUID(),
            title: "Pay electricity bill",
            status: .active,
            revision: revision
        )
    }
}

@MainActor
private final class StubItemRepository: ItemRepository {
    var result: Result<[LifeItem], Error>
    var updateResult: Result<LifeItem, Error>?
    var completeResult: Result<LifeItem, Error>?
    var reopenResult: Result<LifeItem, Error>?
    var deleteResult: Result<Void, Error>?
    var snoozeResult: Result<LifeItem, Error>?

    init(result: Result<[LifeItem], Error>) {
        self.result = result
    }

    func fetchItems() async throws -> [LifeItem] {
        try result.get()
    }

    func createItem(title: String, itemType: String) async throws -> LifeItem {
        LifeItem(id: UUID(), title: title, status: .active)
    }

    func updateItem(id: UUID, title: String, expectedRevision: Int) async throws -> LifeItem {
        if let updateResult { return try updateResult.get() }
        return LifeItem(id: id, title: title, status: .active, revision: expectedRevision + 1)
    }

    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        if let completeResult { return try completeResult.get() }
        return LifeItem(id: id, title: "Completed", status: .completed, updatedAt: updatedAt)
    }

    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        if let reopenResult { return try reopenResult.get() }
        return LifeItem(id: id, title: "Reopened", status: .active, updatedAt: updatedAt)
    }

    func snoozeItem(id: UUID, snoozeDays: Int) async throws -> LifeItem {
        if let snoozeResult { return try snoozeResult.get() }
        return LifeItem(id: id, title: "Snoozed", status: .snoozed)
    }

    var confirmReviewResult: Result<LifeItem, Error>?
    func confirmReviewItem(id: UUID, expectedRevision: Int?) async throws -> LifeItem {
        if let confirmReviewResult { return try confirmReviewResult.get() }
        return LifeItem(id: id, title: "Confirmed", status: .active, revision: (expectedRevision ?? 1) + 1)
    }


    func deleteItem(id: UUID, updatedAt: String?) async throws {
        if let deleteResult { try deleteResult.get() }
    }
}

private enum StubError: Error {
    case unavailable
}
