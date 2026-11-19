//
//  ItemStatus.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation

enum ItemStatus: Equatable {
    case pendingReview
    case active
    case completed
    case snoozed
    case archived
    case unknown(String)
}

extension ItemStatus: Codable {
    private struct DynamicCodingKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        // 1. Try single value container (string representation, e.g. "active", "pending_review", "future_status")
        if let container = try? decoder.singleValueContainer(),
           let raw = try? container.decode(String.self) {
            switch raw {
            case "pendingReview", "pending_review":
                self = .pendingReview
            case "active":
                self = .active
            case "completed":
                self = .completed
            case "snoozed":
                self = .snoozed
            case "archived":
                self = .archived
            default:
                self = .unknown(raw)
            }
            return
        }

        // 2. Try keyed container (legacy Swift enum encoding representation, e.g. {"active": {}}, {"unknown": {"_0": "future"}})
        if let keyed = try? decoder.container(keyedBy: DynamicCodingKey.self),
           let key = keyed.allKeys.first?.stringValue {
            switch key {
            case "pendingReview", "pending_review":
                self = .pendingReview
            case "active":
                self = .active
            case "completed":
                self = .completed
            case "snoozed":
                self = .snoozed
            case "archived":
                self = .archived
            case "unknown":
                if let nested = try? keyed.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: DynamicCodingKey(stringValue: "unknown")!),
                   let valKey = DynamicCodingKey(stringValue: "_0"),
                   let raw = try? nested.decode(String.self, forKey: valKey) {
                    self = .unknown(raw)
                } else if let raw = try? keyed.decode(String.self, forKey: DynamicCodingKey(stringValue: "unknown")!) {
                    self = .unknown(raw)
                } else {
                    self = .unknown("unknown")
                }
            default:
                self = .unknown(key)
            }
            return
        }

        self = .unknown("unknown")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .pendingReview:
            try container.encode("pending_review")
        case .active:
            try container.encode("active")
        case .completed:
            try container.encode("completed")
        case .snoozed:
            try container.encode("snoozed")
        case .archived:
            try container.encode("archived")
        case .unknown(let raw):
            try container.encode(raw)
        }
    }
}
