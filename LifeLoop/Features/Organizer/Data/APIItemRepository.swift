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
        throw ItemMutationError.notAvailable
    }
    func updateItem(id: UUID, title: String, expectedRevision: Int) async throws -> LifeItem {
        guard expectedRevision > 0 else {
            throw ItemMutationError.invalidRevision
        }
        let payload = UpdateItemTitleRequest(title: title, expectedRevision: expectedRevision)
        let body = try JSONEncoder().encode(payload)
        let data: Data
        do {
            let (responseData, _) = try await client.request(
                "api/v1/items/\(id.uuidString.lowercased())",
                method: "PATCH",
                body: body,
                authenticated: true
            )
            data = responseData
        } catch APIError.conflict {
            throw ItemMutationError.conflict
        }
        let response: ItemResponse
        do {
            response = try JSONDecoder().decode(ItemResponse.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
        let canonicalItem: LifeItem
        do {
            canonicalItem = try response.item.domainValue()
        } catch {
            throw APIError.invalidResponse
        }
        guard canonicalItem.id == id,
              let canonicalRevision = canonicalItem.revision,
              canonicalRevision > expectedRevision else {
            throw APIError.invalidResponse
        }
        return canonicalItem
    }
    func completeItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        throw ItemMutationError.notAvailable
    }
    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        throw ItemMutationError.notAvailable
    }
    func deleteItem(id: UUID, updatedAt: String?) async throws {
        throw ItemMutationError.notAvailable
    }
    typealias MutationError = ItemMutationError

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
    let revision: Int?

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
            dueDate: date, metadata: metadata ?? [:], updatedAt: updatedAt,
            revision: revision
        )
    }
}
