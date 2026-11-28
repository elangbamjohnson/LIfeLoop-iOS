//
//  APIItemRepository.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 16/11/26.
//

import Foundation

final class APIItemRepository: ItemRepository {
    private let client: APIClient
    init(client: APIClient) { self.client = client }

    func fetchItems() async throws -> [LifeItem] {
        let (data, _) = try await client.request("api/v1/items")
        return try JSONDecoder().decode(ItemListResponse.self, from: data)
            .items.map { try $0.domainValue() }
    }

    func createItem(title: String, itemType: String) async throws -> LifeItem {
        try await createItem(title: title, itemType: itemType, dueDate: nil)
    }

    func createItem(title: String, itemType: String, dueDate: Date? = nil) async throws -> LifeItem {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ItemMutationError.emptyTitle
        }
        var dueDateString: String? = nil
        if let dueDate {
            dueDateString = ISO8601DateFormatter().string(from: dueDate)
        }
        let payload = CreateItemRequest(title: trimmed, itemType: itemType, dueDate: dueDateString)
        let body = try JSONEncoder().encode(payload)
        let (responseData, _) = try await client.request(
            "api/v1/items",
            method: "POST",
            body: body,
            authenticated: true
        )
        let response: ItemResponse
        do {
            response = try JSONDecoder().decode(ItemResponse.self, from: responseData)
        } catch {
            throw APIError.invalidResponse
        }
        return try response.item.domainValue()
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
        let payload = CompleteItemRequest(completed: true)
        let body = try JSONEncoder().encode(payload)
        let (responseData, _) = try await client.request(
            "api/v1/items/\(id.uuidString.lowercased())/complete",
            method: "POST", body: body, authenticated: true
        )
        let response = try JSONDecoder().decode(ItemResponse.self, from: responseData)
        return try response.item.domainValue()
    }
    func reopenItem(id: UUID, updatedAt: String?) async throws -> LifeItem {
        let payload = CompleteItemRequest(completed: false)
        let body = try JSONEncoder().encode(payload)
        let (responseData, _) = try await client.request(
            "api/v1/items/\(id.uuidString.lowercased())/complete",
            method: "POST", body: body, authenticated: true
        )
        let response = try JSONDecoder().decode(ItemResponse.self, from: responseData)
        return try response.item.domainValue()
    }
    func snoozeItem(id: UUID, snoozeDays: Int) async throws -> LifeItem {
        let payload = SnoozeItemRequest(snoozeDays: snoozeDays)
        let body = try JSONEncoder().encode(payload)
        let (responseData, _) = try await client.request(
            "api/v1/items/\(id.uuidString.lowercased())/snooze",
            method: "POST", body: body, authenticated: true
        )
        let response = try JSONDecoder().decode(ItemResponse.self, from: responseData)
        return try response.item.domainValue()
    }
    func deleteItem(id: UUID, updatedAt: String?) async throws {
        // DELETE returns 200 {success:true}, not 204 empty
        _ = try await client.request(
            "api/v1/items/\(id.uuidString.lowercased())",
            method: "DELETE", body: nil, authenticated: true
        )
    }
    func confirmReviewItem(id: UUID, expectedRevision: Int?) async throws -> LifeItem {
        guard let expectedRevision, expectedRevision > 0 else {
            throw ItemMutationError.invalidRevision
        }
        let payload = ConfirmReviewRequest(expectedRevision: expectedRevision)
        let body = try JSONEncoder().encode(payload)
        let responseData: Data
        do {
            let (data, _) = try await client.request(
                "api/v1/items/\(id.uuidString.lowercased())",
                method: "PATCH", body: body, authenticated: true
            )
            responseData = data
        } catch APIError.conflict {
            throw ItemMutationError.conflict
        }
        let response: ItemResponse
        do {
            response = try JSONDecoder().decode(ItemResponse.self, from: responseData)
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
    let snoozedUntil: String?
    let createdAt: String?
    let captureId: UUID?

    func domainValue() throws -> LifeItem {
        let mappedStatus: ItemStatus
        switch status.lowercased() {
        case "pending_review", "pendingreview": mappedStatus = .pendingReview
        case "active": mappedStatus = .active
        case "completed": mappedStatus = .completed
        case "snoozed": mappedStatus = .snoozed
        case "archived": mappedStatus = .archived
        default: mappedStatus = .unknown(status)
        }
        var date: Date?
        if let dueDate {
            date = LifeItem.parseDate(dueDate)
        }
        if date == nil, let meta = metadata {
            if case .string(let raw) = meta["dueDate"] {
                date = LifeItem.parseDate(raw)
            } else if case .string(let raw) = meta["expiryDate"] {
                date = LifeItem.parseDate(raw)
            }
        }
        return LifeItem(
            id: id, title: title, status: mappedStatus, itemType: itemType,
            dueDate: date, metadata: metadata ?? [:], updatedAt: updatedAt,
            revision: revision, snoozedUntil: snoozedUntil, createdAt: createdAt,
            captureId: captureId
        )
    }
}
