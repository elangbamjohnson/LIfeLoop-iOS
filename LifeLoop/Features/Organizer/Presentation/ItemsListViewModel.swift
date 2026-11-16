//
//  ItemsListViewModel.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ItemsListViewModel {
    enum State {
        case idle
        case loading
        case loaded([LifeItem])
        case empty
        case failed(String)
    }

    private(set) var state: State = .idle

    private let repository: any ItemRepository
    private var loadGeneration = 0

    init(repository: any ItemRepository) {
        self.repository = repository
    }

    func load() async {
        loadGeneration += 1
        let currentGeneration = loadGeneration

        state = .loading

        do {
            let items = try await repository.fetchItems()
            try Task.checkCancellation()

            guard currentGeneration == loadGeneration else {
                return
            }

            state = items.isEmpty ? .empty : .loaded(items)
        } catch {
            guard currentGeneration == loadGeneration else {
                return
            }

            if error is CancellationError || Task.isCancelled {
                state = .idle
                return
            }

            state = .failed(
                "We couldn't load your items. Please try again."
            )
        }
    }

    func updateItem(_ updatedItem: LifeItem) {
        guard case .loaded(var items) = state else {
            return
        }

        guard let index = items.firstIndex(where: {
            $0.id == updatedItem.id
        }) else {
            return
        }

        items[index] = updatedItem
        state = .loaded(items)
    }

    func loadIfNeeded() async {
        switch state {
        case .loaded, .empty:
            return

        case .idle, .loading, .failed:
            await load()
        }
    }
}
