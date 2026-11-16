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

    private func makeItem() -> LifeItem {
        LifeItem(
            id: UUID(),
            title: "Pay electricity bill",
            status: .active
        )
    }
}

@MainActor
private final class StubItemRepository: ItemRepository {
    var result: Result<[LifeItem], Error>

    init(result: Result<[LifeItem], Error>) {
        self.result = result
    }

    func fetchItems() async throws -> [LifeItem] {
        try result.get()
    }
}

private enum StubError: Error {
    case unavailable
}
