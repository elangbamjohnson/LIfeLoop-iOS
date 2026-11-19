//
//  SampleItemRepository.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation

@MainActor
final class SampleItemRepository: ItemRepository {
    private var items: [LifeItem]
    let shouldFail: Bool

    init(items: [LifeItem], shouldFail: Bool = false) {
        self.items = items
        self.shouldFail = shouldFail
    }

    func fetchItems() async throws -> [LifeItem] {
        try await Task.sleep(for: .seconds(1))

        if shouldFail {
            throw SampleError.unavailable
        }

        return items
    }

    func createItem(title: String, itemType: String) async throws -> LifeItem {
        if shouldFail { throw SampleError.unavailable }
        let item = LifeItem(id: UUID(), title: title, status: .active, itemType: itemType)
        items.insert(item, at: 0)
        return item
    }

    func updateItem(id: UUID, title: String, expectedRevision: Int) async throws -> LifeItem {
        let index = try index(for: id)
        guard expectedRevision > 0 else {
            throw ItemMutationError.invalidRevision
        }
        guard let storedRevision = items[index].revision, storedRevision > 0 else {
            throw ItemMutationError.invalidRevision
        }
        guard storedRevision == expectedRevision else {
            throw ItemMutationError.conflict
        }
        items[index].title = title
        items[index].revision = storedRevision + 1
        items[index].updatedAt = ISO8601DateFormatter().string(from: Date())
        return items[index]
    }

    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        let index = try index(for: id)
        items[index].status = .completed
        return items[index]
    }

    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        let index = try index(for: id)
        items[index].status = .active
        return items[index]
    }

    func snoozeItem(id: UUID, snoozeDays: Int) async throws -> LifeItem {
        let index = try index(for: id)
        items[index].status = .snoozed
        return items[index]
    }

    func deleteItem(id: UUID, updatedAt: String?) async throws {
        items.remove(at: try index(for: id))
    }

    func confirmReviewItem(id: UUID, expectedRevision: Int?) async throws -> LifeItem {
        let index = try index(for: id)
        items[index].status = .active
        if let rev = items[index].revision {
            items[index].revision = rev + 1
        }
        return items[index]
    }


    private func index(for id: UUID) throws -> Int {
        if shouldFail { throw SampleError.unavailable }
        guard let index = items.firstIndex(where: { $0.id == id }) else {
            throw SampleError.notFound
        }
        return index
    }

    private enum SampleError: Error { case unavailable, notFound }
}
