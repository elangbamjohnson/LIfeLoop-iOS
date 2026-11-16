import Foundation
import Testing
@testable import LifeLoop

@MainActor
struct SampleItemRepositoryTests {
    @Test func mutationsSurviveRefreshWithoutLosingFields() async throws {
        let original = LifeItem(id: UUID(), title: "Original", status: .active,
                                itemType: "payment", metadata: ["amount": .number(42)])
        let repository = SampleItemRepository(items: [original])
        _ = try await repository.updateItem(id: original.id, title: "Edited", updatedAt: nil)
        let completed = try await repository.completeItem(id: original.id, updatedAt: nil)
        #expect(completed.title == "Edited")
        #expect(completed.metadata == original.metadata)
        let refreshed = try await repository.fetchItems()
        #expect(refreshed.first?.status == .completed)
        try await repository.deleteItem(id: original.id, updatedAt: nil)
        let remaining = try await repository.fetchItems()
        #expect(remaining.isEmpty)
    }
}
