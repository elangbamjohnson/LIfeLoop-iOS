//
//  SampleItems.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation

enum SampleItems {

    static let all: [LifeItem] = [
        LifeItem(
            id: UUID(),
            title: "Pay electricity bill",
            status: .active
        ),
        LifeItem(
            id: UUID(),
            title: "Renew car insurance",
            status: .pendingReview
        ),
        LifeItem(
            id: UUID(),
            title: "Collect documents from the bank",
            status: .completed
        ),
        LifeItem(
            id: UUID(),
            title: "Book a vehicle service",
            status: .snoozed
        ),
        LifeItem(
            id: UUID(),
            title: "Review last year's warranty",
            status: .archived
        ),
        LifeItem(
            id: UUID(),
            title: "Check an imported item",
            status: .unknown("future_status")
        )
    ]
}
