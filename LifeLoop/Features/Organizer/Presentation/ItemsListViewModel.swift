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
    private(set) var lastLoadedAt: Date?
    private(set) var showingCache = false
    private(set) var requiresSignIn = false
    private(set) var mutatingItemIDs: Set<UUID> = []
    var actionError: String?

    private let repository: any ItemRepository
    private var loadGeneration = 0

    init(repository: any ItemRepository) {
        self.repository = repository
    }

    func load() async {
        guard mutatingItemIDs.isEmpty else { return }
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
            lastLoadedAt = repository.cacheDate ?? Date()
            showingCache = repository.cacheDate != nil
        } catch {
            guard currentGeneration == loadGeneration else {
                return
            }

            if error is CancellationError || Task.isCancelled {
                state = .idle
                return
            }

            if case APIError.unauthorized = error { requiresSignIn = true }
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

    func saveTitle(for item: LifeItem, newTitle: String) async throws -> LifeItem {
        guard case .loaded = state, !mutatingItemIDs.contains(item.id) else { throw ItemMutationError.conflict }
        guard let revision = item.revision, revision > 0 else {
            throw ItemMutationError.invalidRevision
        }
        mutatingItemIDs.insert(item.id)
        defer { mutatingItemIDs.remove(item.id) }

        let updated = try await repository.updateItem(id: item.id, title: newTitle, expectedRevision: revision)
        updateItem(updated)
        return updated
    }

    func completeItem(_ item: LifeItem) async {
        guard case .loaded = state, !mutatingItemIDs.contains(item.id) else { return }
        mutatingItemIDs.insert(item.id)
        defer { mutatingItemIDs.remove(item.id) }

        do {
            let updated = try await repository.completeItem(id: item.id, updatedAt: item.updatedAt)
            updateItem(updated)
        } catch {
            if error is CancellationError { return }
            actionError = (error as? APIError)?.errorDescription ?? "Could not complete this item. Please try again."
        }
    }

    func reopenItem(_ item: LifeItem) async {
        guard case .loaded = state, !mutatingItemIDs.contains(item.id) else { return }
        mutatingItemIDs.insert(item.id)
        defer { mutatingItemIDs.remove(item.id) }

        do {
            let updated = try await repository.reopenItem(id: item.id, updatedAt: item.updatedAt)
            updateItem(updated)
        } catch {
            if error is CancellationError { return }
            actionError = (error as? APIError)?.errorDescription ?? "Could not reopen this item. Please try again."
        }
    }

    func deleteItem(_ item: LifeItem) async {
        guard case .loaded = state, !mutatingItemIDs.contains(item.id) else { return }
        mutatingItemIDs.insert(item.id)
        defer { mutatingItemIDs.remove(item.id) }
        do {
            try await repository.deleteItem(id: item.id, updatedAt: item.updatedAt)
            if case .loaded(let items) = state {
                let remaining = items.filter { $0.id != item.id }
                state = remaining.isEmpty ? .empty : .loaded(remaining)
            }
        } catch {
            if error is CancellationError { return }
            actionError = (error as? APIError)?.errorDescription ?? "Could not delete this item. Please try again."
        }
    }

    func forceLoad() async {
        await load()
    }

    var isStale: Bool {
        guard let lastLoadedAt else { return true }
        return Date().timeIntervalSince(lastLoadedAt) > 5 * 60
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
