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

    @Test func searchMatchesTitleItemTypeAmountAndMetadataValuesWithoutKeyNoise() {
        let bill = LifeItem(
            id: UUID(),
            title: "Monthly Electricity",
            status: .active,
            itemType: "bill",
            metadata: [
                "amount": .number(2840),
                "currency": .string("INR"),
                "location": .string("Bengaluru"),
                "tags": .array([.string("utilities"), .string("home")]),
                "confidenceScore": .number(0.95),
                "isShared": .bool(false)
            ]
        )
        let courier = LifeItem(
            id: UUID(),
            title: "Passport delivery",
            status: .active,
            itemType: "waiting_for",
            metadata: [
                "waitingFor": .string("DHL Express"),
                "nested": .object(["tracking": .string("TRACK-99")])
            ]
        )

        #expect(LifeItem.filter([bill, courier], matching: "  ") .count == 2)
        #expect(LifeItem.filter([bill, courier], matching: "electricity").map(\.id) == [bill.id])
        #expect(LifeItem.filter([bill, courier], matching: "waiting for").map(\.id) == [courier.id])
        #expect(LifeItem.filter([bill, courier], matching: "Bengaluru").map(\.id) == [bill.id])
        #expect(LifeItem.filter([bill, courier], matching: "utilities").map(\.id) == [bill.id])
        #expect(LifeItem.filter([bill, courier], matching: "2,840").map(\.id) == [bill.id])
        #expect(LifeItem.filter([bill, courier], matching: "2840").map(\.id) == [bill.id])
        #expect(LifeItem.filter([bill, courier], matching: "dhl").map(\.id) == [courier.id])
        #expect(LifeItem.filter([bill, courier], matching: "TRACK-99").map(\.id) == [courier.id])

        // Internal keys & booleans must not pollute user search queries
        #expect(LifeItem.filter([bill, courier], matching: "confidenceScore").isEmpty)
        #expect(LifeItem.filter([bill, courier], matching: "false").isEmpty)
    }

    @Test func waitingForSummaryCoversFutureOverduePluralCompletedAndPendingReview() {
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: referenceDate)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: referenceDate)!
        let inThreeDays = calendar.date(byAdding: .day, value: 3, to: referenceDate)!

        let upcoming = LifeItem(
            id: UUID(),
            title: "Passport courier",
            status: .active,
            itemType: "waiting_for",
            dueDate: inThreeDays,
            metadata: ["waitingFor": .string("DHL")]
        )
        let upcomingSummary = upcoming.waitingForStatusSummary(relativeTo: referenceDate, calendar: calendar)
        #expect(upcomingSummary?.isOverdue == false)
        #expect(upcomingSummary?.text == "Expected \(inThreeDays.formatted(.dateTime.month(.abbreviated).day()))")

        let undated = LifeItem(id: UUID(), title: "Contract signature", status: .active, itemType: "waiting_for")
        #expect(undated.waitingForStatusSummary(relativeTo: referenceDate, calendar: calendar) ==
            LifeItem.WaitingForSummary(text: "Expected Soon", isOverdue: false))

        let oneDayOverdue = LifeItem(
            id: UUID(),
            title: "Passport Renewal",
            status: .active,
            itemType: "waiting_for",
            dueDate: oneDayAgo,
            metadata: ["waitingFor": .string("Alice")]
        )
        #expect(oneDayOverdue.waitingForStatusSummary(relativeTo: referenceDate, calendar: calendar) ==
            LifeItem.WaitingForSummary(text: "Alice's passport renewal is overdue by 1 day.", isOverdue: true))

        let threeDaysOverdue = LifeItem(
            id: UUID(),
            title: "Refund Check",
            status: .active,
            itemType: "waiting_for",
            dueDate: threeDaysAgo,
            metadata: ["waitingFor": .string("Bob")]
        )
        #expect(threeDaysOverdue.waitingForStatusSummary(relativeTo: referenceDate, calendar: calendar) ==
            LifeItem.WaitingForSummary(text: "Bob's refund check is overdue by 3 days.", isOverdue: true))

        let received = LifeItem(
            id: UUID(),
            title: "Courier",
            status: .completed,
            itemType: "waiting_for",
            metadata: ["completedAt": .string("2026-11-18T09:00:00Z")]
        )
        let receivedSummary = received.waitingForStatusSummary(relativeTo: referenceDate, calendar: calendar)
        #expect(receivedSummary?.isOverdue == false)
        #expect(receivedSummary?.text.hasPrefix("Received") == true)

        let pendingReview = LifeItem(id: UUID(), title: "Draft wait", status: .pendingReview, itemType: "waiting_for")
        #expect(pendingReview.waitingForStatusSummary(relativeTo: referenceDate, calendar: calendar) == nil)
    }
}
