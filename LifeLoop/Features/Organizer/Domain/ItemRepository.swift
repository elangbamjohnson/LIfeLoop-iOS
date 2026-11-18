import Foundation

enum ItemMutationError: Error, LocalizedError, Equatable {
    case notAvailable
    case invalidRevision
    case conflict

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "This action is not available."
        case .invalidRevision:
            return "The item revision is invalid. Please refresh and try again."
        case .conflict:
            return "This item has changed on the server. Please refresh before trying again."
        }
    }
}

struct OrganizerCapabilities: Equatable {
    var allowsTitleEditing: Bool
    var allowsItemMutations: Bool

    static let none = OrganizerCapabilities(allowsTitleEditing: false, allowsItemMutations: false)
    static let titleOnly = OrganizerCapabilities(allowsTitleEditing: true, allowsItemMutations: false)
    static let demo = OrganizerCapabilities(allowsTitleEditing: true, allowsItemMutations: true)

    init(allowsTitleEditing: Bool, allowsItemMutations: Bool) {
        self.allowsTitleEditing = allowsTitleEditing
        self.allowsItemMutations = allowsItemMutations
    }

    init(allowsEditing: Bool) {
        self.allowsTitleEditing = allowsEditing
        self.allowsItemMutations = allowsEditing
    }
}

@MainActor
protocol ItemRepository {
    var cacheDate: Date? { get }
    func fetchItems() async throws -> [LifeItem]
    func createItem(title: String, itemType: String) async throws -> LifeItem
    func updateItem(id: UUID, title: String, expectedRevision: Int) async throws -> LifeItem
    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem
    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem
    func deleteItem(id: UUID, updatedAt: String?) async throws
}

extension ItemRepository {
    var cacheDate: Date? { nil }
}
