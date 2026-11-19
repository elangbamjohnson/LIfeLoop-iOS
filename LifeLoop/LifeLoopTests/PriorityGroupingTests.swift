//
//  PriorityGroupingTests.swift
//  LifeLoopTests
//
//  Created by Johnson Elangbam on 18/11/26.
//

import Foundation
import Testing
@testable import LifeLoop

@MainActor
struct PriorityGroupingTests {
    private let calendar = Calendar.current
    private let referenceDate = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 10, minute: 0, second: 0))!

    @Test func pendingReviewIsDeduplicatedFromTodayAndUpcoming() {
        let laterToday = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: referenceDate)!

        let todayPending = LifeItem(
            id: UUID(),
            title: "Review Insurance",
            status: .pendingReview,
            itemType: "renewal",
            dueDate: laterToday,
            metadata: ["confidenceScore": .number(0.85)]
        )

        let todayActive = LifeItem(
            id: UUID(),
            title: "Pay Utility Bill",
            status: .active,
            itemType: "payment",
            dueDate: laterToday
        )

        let futurePending = LifeItem(
            id: UUID(),
            title: "Doctor Follow-up",
            status: .pendingReview,
            itemType: "appointment",
            dueDate: calendar.date(byAdding: .day, value: 3, to: referenceDate)
        )

        let timeline = TimelineGrouping.group(
            items: [todayPending, todayActive, futurePending],
            referenceDate: referenceDate,
            calendar: calendar
        )

        let priority = PriorityGrouping(from: timeline)

        // Needs Attention must contain BOTH pending review items
        #expect(priority.needsAttention.contains(where: { $0.id == todayPending.id }))
        #expect(priority.needsAttention.contains(where: { $0.id == futurePending.id }))

        // Today must contain ONLY the active item, NOT the pending item
        #expect(priority.today.contains(where: { $0.id == todayActive.id }))
        #expect(!priority.today.contains(where: { $0.id == todayPending.id }))

        // Upcoming must NOT contain the future pending review item (it's in needsAttention)
        #expect(!priority.upcoming.contains(where: { $0.id == futurePending.id }))

        // Carousel must contain needsAttention + today
        #expect(priority.carouselItems.contains(where: { $0.id == todayPending.id }))
        #expect(priority.carouselItems.contains(where: { $0.id == futurePending.id }))
        #expect(priority.carouselItems.contains(where: { $0.id == todayActive.id }))
    }

    @Test func confidencePercentageCalculatesCorrectly() {
        let item1 = LifeItem(
            id: UUID(),
            title: "Item 1",
            status: .pendingReview,
            metadata: ["confidenceScore": .number(0.92)]
        )
        #expect(item1.confidencePercentage == 92)

        let item2 = LifeItem(
            id: UUID(),
            title: "Item 2",
            status: .pendingReview,
            metadata: ["confidenceScore": .number(87)]
        )
        #expect(item2.confidencePercentage == 87)

        let item3 = LifeItem(
            id: UUID(),
            title: "Item 3",
            status: .active
        )
        #expect(item3.confidencePercentage == nil)
    }

    @Test func waitingForPersonResolvesFromMetadataKeys() {
        let item1 = LifeItem(
            id: UUID(),
            title: "Refund",
            status: .active,
            metadata: ["waitingFor": .string("Alice")]
        )
        #expect(item1.waitingForPerson == "Alice")

        let item2 = LifeItem(
            id: UUID(),
            title: "Contract",
            status: .active,
            metadata: ["person": .string("Bob Smith")]
        )
        #expect(item2.waitingForPerson == "Bob Smith")

        let item3 = LifeItem(
            id: UUID(),
            title: "Clean task",
            status: .active
        )
        #expect(item3.waitingForPerson == nil)
    }

    @Test func priorityGroupingEmptyState() {
        let timeline = TimelineGrouping()
        let priority = PriorityGrouping(from: timeline)
        #expect(priority.isEmpty)
        #expect(priority.carouselItems.isEmpty)
    }
}
