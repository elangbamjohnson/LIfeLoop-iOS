import Foundation

struct CreateItemRequest: Encodable {
    let title: String
    let itemType: String
}

struct UpdateItemRequest: Encodable {
    let title: String
    let updatedAt: String?
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
