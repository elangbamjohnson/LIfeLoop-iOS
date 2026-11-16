//
//  LifeItem.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation

struct LifeItem: Identifiable {
    let id: UUID
    var title: String
    var status: ItemStatus
    var itemType: String = "task"
    var dueDate: Date?
    var metadata: [String: JSONValue] = [:]
    var updatedAt: String?
}
