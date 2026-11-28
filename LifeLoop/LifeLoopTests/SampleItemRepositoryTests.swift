//
//  SampleItemRepositoryTests.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 16/11/26.
//

import Foundation
import Testing
@testable import LifeLoop

@MainActor
struct SampleItemRepositoryTests {
    @Test func mutationsSurviveRefreshWithoutLosingFields() async throws {
        let original = LifeItem(id: UUID(), title: "Original", status: .active,
                                itemType: "payment", metadata: ["amount": .number(42)], revision: 1)
        let repository = SampleItemRepository(items: [original])
        let updated = try await repository.updateItem(id: original.id, title: "Edited", expectedRevision: 1)
        #expect(updated.title == "Edited")
        #expect(updated.revision == 2)
        let completed = try await repository.completeItem(id: original.id, updatedAt: nil)
        #expect(completed.title == "Edited")
        #expect(completed.metadata == original.metadata)
        let refreshed = try await repository.fetchItems()
        #expect(refreshed.first?.status == .completed)
        #expect(refreshed.first?.revision == 2)
        try await repository.deleteItem(id: original.id, updatedAt: nil)
        let remaining = try await repository.fetchItems()
        #expect(remaining.isEmpty)
    }

    @Test func demoTitleEditingRejectsMismatchedRevision() async throws {
        let original = LifeItem(id: UUID(), title: "Original", status: .active, revision: 3)
        let repository = SampleItemRepository(items: [original])
        await #expect(throws: ItemMutationError.conflict) {
            try await repository.updateItem(id: original.id, title: "Edited", expectedRevision: 2)
        }
    }

    @Test func demoTitleEditingRejectsNonPositiveRevision() async throws {
        let original = LifeItem(id: UUID(), title: "Original", status: .active, revision: 1)
        let repository = SampleItemRepository(items: [original])
        await #expect(throws: ItemMutationError.invalidRevision) {
            try await repository.updateItem(id: original.id, title: "Edited", expectedRevision: 0)
        }
        await #expect(throws: ItemMutationError.invalidRevision) {
            try await repository.updateItem(id: original.id, title: "Edited", expectedRevision: -1)
        }
    }

    @Test func demoTitleEditingRejectsMissingStoredRevision() async throws {
        let original = LifeItem(id: UUID(), title: "Original", status: .active, revision: nil)
        let repository = SampleItemRepository(items: [original])
        await #expect(throws: ItemMutationError.invalidRevision) {
            try await repository.updateItem(id: original.id, title: "Edited", expectedRevision: 1)
        }
    }

    @Test func demoTitleEditingRejectsNonPositiveStoredRevision() async throws {
        let originalWithZero = LifeItem(id: UUID(), title: "Zero", status: .active, revision: 0)
        let repositoryZero = SampleItemRepository(items: [originalWithZero])
        await #expect(throws: ItemMutationError.invalidRevision) {
            try await repositoryZero.updateItem(id: originalWithZero.id, title: "Edited", expectedRevision: 0)
        }

        let originalWithNegative = LifeItem(id: UUID(), title: "Negative", status: .active, revision: -2)
        let repositoryNegative = SampleItemRepository(items: [originalWithNegative])
        await #expect(throws: ItemMutationError.invalidRevision) {
            try await repositoryNegative.updateItem(id: originalWithNegative.id, title: "Edited", expectedRevision: 1)
        }
    }
}
