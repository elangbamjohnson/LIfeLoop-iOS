import Foundation

enum ItemMutationError: Error, LocalizedError, Equatable {
    case notAvailable
    case invalidRevision
    case conflict
    case emptyTitle

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "This action is not available."
        case .invalidRevision:
            return "The item revision is invalid. Please refresh and try again."
        case .conflict:
            return "This item has changed on the server. Please refresh before trying again."
        case .emptyTitle:
            return "A title is required to create an item."
        }
    }
}

struct OrganizerCapabilities: Equatable {
    var allowsTitleEditing: Bool
    var allowsItemMutations: Bool
    var allowsItemCreation: Bool
    var isDemo: Bool

    static let none = OrganizerCapabilities(allowsTitleEditing: false, allowsItemMutations: false, allowsItemCreation: false, isDemo: false)
    static let titleOnly = OrganizerCapabilities(allowsTitleEditing: true, allowsItemMutations: false, allowsItemCreation: false, isDemo: false)
    static let connected = OrganizerCapabilities(allowsTitleEditing: true, allowsItemMutations: true, allowsItemCreation: true, isDemo: false)
    static let demo = OrganizerCapabilities(allowsTitleEditing: true, allowsItemMutations: true, allowsItemCreation: true, isDemo: true)

    init(allowsTitleEditing: Bool, allowsItemMutations: Bool, allowsItemCreation: Bool = true, isDemo: Bool = false) {
        self.allowsTitleEditing = allowsTitleEditing
        self.allowsItemMutations = allowsItemMutations
        self.allowsItemCreation = allowsItemCreation
        self.isDemo = isDemo
    }

    init(allowsEditing: Bool, allowsItemCreation: Bool? = nil, isDemo: Bool = false) {
        self.allowsTitleEditing = allowsEditing
        self.allowsItemMutations = allowsEditing
        self.allowsItemCreation = allowsItemCreation ?? allowsEditing
        self.isDemo = isDemo
    }
}

@MainActor
protocol ItemRepository {
    var cacheDate: Date? { get }
    func fetchItems() async throws -> [LifeItem]
    func createItem(title: String, itemType: String) async throws -> LifeItem
    func createItem(title: String, itemType: String, dueDate: Date?) async throws -> LifeItem
    func updateItem(id: UUID, title: String, expectedRevision: Int) async throws -> LifeItem
    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem
    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem
    func snoozeItem(id: UUID, snoozeDays: Int) async throws -> LifeItem
    func deleteItem(id: UUID, updatedAt: String?) async throws
    func confirmReviewItem(id: UUID, expectedRevision: Int?) async throws -> LifeItem
}

extension ItemRepository {
    var cacheDate: Date? { nil }
    func createItem(title: String, itemType: String, dueDate: Date?) async throws -> LifeItem {
        try await createItem(title: title, itemType: itemType)
    }
    func confirmReviewItem(id: UUID, expectedRevision: Int?) async throws -> LifeItem {
        throw ItemMutationError.notAvailable
    }
}
