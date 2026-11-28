//
//  ItemMutationDTO.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 16/11/26.
//

import Foundation

struct CreateItemRequest: Encodable {
    let title: String
    let itemType: String
    let dueDate: String?

    init(title: String, itemType: String, dueDate: String? = nil) {
        self.title = title
        self.itemType = itemType
        self.dueDate = dueDate
    }
}

struct CompleteItemRequest: Encodable {
    let completed: Bool
}

struct SnoozeItemRequest: Encodable {
    let snoozeDays: Int
}

struct UpdateItemTitleRequest: Encodable {
    let title: String
    let expectedRevision: Int
}

struct ConfirmReviewRequest: Encodable {
    let status: String = "active"
    let expectedRevision: Int
}


/// Used for complete/reopen/delete endpoints where the only optional field is updatedAt.
struct OptionalUpdatedAtRequest: Encodable {
    let updatedAt: String?

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let updatedAt {
            try container.encode(updatedAt, forKey: .updatedAt)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case updatedAt
    }
}
