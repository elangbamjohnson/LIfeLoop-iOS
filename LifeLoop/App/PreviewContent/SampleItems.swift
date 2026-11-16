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
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            title: "Pay electricity bill",
            status: .active
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Renew car insurance",
            status: .pendingReview
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            title: "Collect documents from the bank",
            status: .completed
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            title: "Book a vehicle service",
            status: .snoozed
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            title: "Review last year's warranty",
            status: .archived
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            title: "Check an imported item",
            status: .unknown("future_status")
        )
    ]
}
