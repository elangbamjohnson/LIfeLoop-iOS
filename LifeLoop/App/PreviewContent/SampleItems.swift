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
            status: .active,
            itemType: "bill",
            dueDate: Date().addingTimeInterval(-86400 * 57),
            metadata: ["amount": .number(1250), "currency": .string("INR")],
            revision: 1,
            createdAt: "2026-09-21T10:00:00Z"
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            title: "Renew car insurance",
            status: .pendingReview,
            itemType: "renewal",
            revision: 2,
            createdAt: "2026-09-22T10:00:00Z",
            captureId: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            title: "Buy milk",
            status: .active,
            itemType: "task",
            dueDate: Date().addingTimeInterval(-86400 * 57),
            revision: 1,
            createdAt: "2026-09-22T10:00:00Z"
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            title: "Book a vehicle service",
            status: .snoozed,
            itemType: "vehicle",
            revision: 1,
            snoozedUntil: "2026-11-21T10:00:00Z"
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            title: "Review last year's warranty",
            status: .archived,
            itemType: "warranty",
            revision: 1
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            title: "Check an imported item",
            status: .unknown("future_status"),
            itemType: "task",
            revision: 1
        ),
        LifeItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            title: "Waiting for passport courier",
            status: .active,
            itemType: "waiting_for",
            dueDate: Date().addingTimeInterval(86400 * 3),
            metadata: ["waitingFor": .string("DHL Express")],
            revision: 1
        )
    ]
}
