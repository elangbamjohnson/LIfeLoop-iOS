//
//  ItemStatus.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

enum ItemStatus: Equatable, Codable {
    case pendingReview
    case active
    case completed
    case snoozed
    case archived
    case unknown(String)
}
