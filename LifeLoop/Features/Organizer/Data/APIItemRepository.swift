import Foundation

final class APIItemRepository: ItemRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func fetchItems() async throws -> [LifeItem] {
        let (data, _) = try await client.request("api/v1/items")
        return try JSONDecoder().decode(ItemListResponse.self, from: data)
            .items.map { try $0.domainValue() }
    }

    // Do not send mutations until the server enforces revision preconditions.
    func createItem(title: String, itemType: String) async throws -> LifeItem {
        throw MutationError.notAvailable
    }
    func updateItem(id: UUID, title: String, updatedAt: String?) async throws -> LifeItem {
        throw MutationError.notAvailable
    }
    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        throw MutationError.notAvailable
    }
    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        throw MutationError.notAvailable
    }
    func deleteItem(id: UUID, updatedAt: String?) async throws {
        throw MutationError.notAvailable
    }
    enum MutationError: Error { case notAvailable }

}

struct ItemListResponse: Decodable {
    let items: [ItemDTO]
}

struct ItemResponse: Decodable {
    let item: ItemDTO
}

struct ItemDTO: Decodable {
    let id: UUID
    let title: String
    let status: String
    let itemType: String
    let dueDate: String?
    let metadata: [String: JSONValue]?
    let updatedAt: String?

    func domainValue() throws -> LifeItem {
        let mappedStatus: ItemStatus
        switch status {
        case "pending_review": mappedStatus = .pendingReview
        case "active": mappedStatus = .active
        case "completed": mappedStatus = .completed
        case "snoozed": mappedStatus = .snoozed
        case "archived": mappedStatus = .archived
        default: mappedStatus = .unknown(status)
        }
        var date: Date?
        if let dueDate {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = formatter.date(from: dueDate)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: dueDate)
            }
            guard date != nil else { throw APIError.invalidResponse }
        }
        return LifeItem(
            id: id, title: title, status: mappedStatus, itemType: itemType,
            dueDate: date, metadata: metadata ?? [:], updatedAt: updatedAt
        )
    }
}
