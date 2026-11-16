import Foundation

@MainActor
protocol ItemRepository {
    func fetchItems() async throws -> [LifeItem]
    func createItem(title: String, itemType: String) async throws -> LifeItem
    func updateItem(id: UUID, title: String, updatedAt: String?) async throws -> LifeItem
    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem
    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem
    func deleteItem(id: UUID, updatedAt: String?) async throws
}
