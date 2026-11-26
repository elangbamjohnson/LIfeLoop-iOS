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
    private(set) var refreshError: String?
    private(set) var mutatingItemIDs: Set<UUID> = []
    var actionError: String?

    private let repository: any ItemRepository
    private var loadGeneration = 0
    private var deletedCaptureIDs: Set<UUID> = []

    init(repository: any ItemRepository) {
        self.repository = repository
    }

    func load(preservingContent: Bool = false) async {
        guard mutatingItemIDs.isEmpty else { return }
        loadGeneration += 1
        let currentGeneration = loadGeneration

        let hasContent: Bool
        switch state {
        case .loaded, .empty: hasContent = true
        default: hasContent = false
        }
        if !preservingContent || !hasContent { state = .loading }
        refreshError = nil

        do {
            let items = try await repository.fetchItems()
            try Task.checkCancellation()

            guard currentGeneration == loadGeneration else {
                return
            }

            let activeItems = filterDeletedCaptureItems(items)
            state = activeItems.isEmpty ? .empty : .loaded(activeItems)
            lastLoadedAt = repository.cacheDate ?? Date()
            showingCache = repository.cacheDate != nil
        } catch {
            guard currentGeneration == loadGeneration else {
                return
            }

            if error is CancellationError || Task.isCancelled {
                if !preservingContent || !hasContent { state = .idle }
                return
            }

            if case APIError.unauthorized = error { requiresSignIn = true }
            let message = "We couldn't load your items. Please try again."
            if preservingContent && hasContent {
                refreshError = message
            } else {
                state = .failed(message)
            }
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

    var items: [LifeItem] {
        if case .loaded(let items) = state { return items }
        return []
    }

    var timelineGrouping: TimelineGrouping {
        TimelineGrouping.group(items: items)
    }

    func toggleComplete(for item: LifeItem) async {
        if item.status == .completed {
            await reopenItem(item)
        } else {
            await completeItem(item)
        }
    }

    func createItem(title: String, itemType: String, dueDate: Date? = nil) async throws -> LifeItem {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ItemMutationError.emptyTitle }
        let created = try await repository.createItem(title: trimmed, itemType: itemType, dueDate: dueDate)
        if case .loaded(var currentItems) = state {
            currentItems.insert(created, at: 0)
            state = .loaded(currentItems)
        } else {
            state = .loaded([created])
        }
        return created
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

    func snoozeItem(_ item: LifeItem, days: Int) async {
        guard case .loaded = state, !mutatingItemIDs.contains(item.id) else { return }
        mutatingItemIDs.insert(item.id)
        defer { mutatingItemIDs.remove(item.id) }
        do {
            let updated = try await repository.snoozeItem(id: item.id, snoozeDays: days)
            updateItem(updated)
        } catch {
            if error is CancellationError { return }
            actionError = (error as? LocalizedError)?.errorDescription ?? "Could not snooze this item. Please try again."
        }
    }

    func confirmReview(_ item: LifeItem) async {
        guard case .loaded = state, !mutatingItemIDs.contains(item.id) else { return }
        guard let revision = item.revision, revision > 0 else {
            actionError = ItemMutationError.invalidRevision.errorDescription
            return
        }
        mutatingItemIDs.insert(item.id)
        defer { mutatingItemIDs.remove(item.id) }
        do {
            let updated = try await repository.confirmReviewItem(id: item.id, expectedRevision: revision)
            updateItem(updated)
        } catch {
            if error is CancellationError { return }
            actionError = (error as? LocalizedError)?.errorDescription ?? "Could not confirm this item. Please try again."
        }
    }


    func refreshAfterCapture() async {
        await load(preservingContent: true)
    }

    func removeItems(forCaptureID captureID: UUID) {
        deletedCaptureIDs.insert(captureID)
        guard case .loaded(let currentItems) = state else { return }
        let remaining = currentItems.filter { $0.captureId != captureID }
        guard remaining.count != currentItems.count else { return }
        state = remaining.isEmpty ? .empty : .loaded(remaining)
    }

    func reset() {
        loadGeneration += 1
        deletedCaptureIDs.removeAll()
        state = .idle
        lastLoadedAt = nil
        showingCache = false
        requiresSignIn = false
        refreshError = nil
        actionError = nil
        mutatingItemIDs = []
    }

    private func filterDeletedCaptureItems(_ items: [LifeItem]) -> [LifeItem] {
        items.filter { item in
            guard let captureId = item.captureId else { return true }
            return !deletedCaptureIDs.contains(captureId)
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
