//
//  TimelineGroupingTests.swift
//  LifeLoopTests
//
//  Created by Johnson Elangbam on 18/11/26.
//

import Foundation
import Testing
@testable import LifeLoop

@MainActor
struct TimelineGroupingTests {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private let referenceDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 18
        components.hour = 12
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(from: components)!
    }()

    @Test func sampleItemsGrouping() {
        let grouping = TimelineGrouping.group(items: SampleItems.all, referenceDate: referenceDate, calendar: calendar)
        let priority = PriorityGrouping(from: grouping)
        #expect(priority.needsAttention.contains { $0.id == UUID(uuidString: "00000000-0000-0000-0000-000000000002")! })
    }

    @Test func completedItemsGoToPast() {
        let completed = LifeItem(
            id: UUID(),
            title: "Done task",
            status: .completed,
            revision: 1
        )
        let grouping = TimelineGrouping.group(items: [completed], referenceDate: referenceDate, calendar: calendar)
        #expect(grouping.past.count == 1)
        #expect(grouping.past.first?.id == completed.id)
        #expect(grouping.today.isEmpty)
        #expect(grouping.needsAttention.isEmpty)
    }

    @Test func overdueItemsGoToNeedsAttention() {
        let overdueDate = calendar.date(byAdding: .day, value: -2, to: referenceDate)!
        let overdue = LifeItem(
            id: UUID(),
            title: "Overdue bill",
            status: .active,
            dueDate: overdueDate,
            revision: 1
        )
        let grouping = TimelineGrouping.group(items: [overdue], referenceDate: referenceDate, calendar: calendar)
        #expect(grouping.needsAttention.count == 1)
        #expect(grouping.needsAttention.first?.id == overdue.id)
    }

    @Test func pendingReviewItemsGoToNeedsAttentionAndTimelineBucket() {
        let tomorrowDate = calendar.date(byAdding: .day, value: 1, to: referenceDate)!
        let pending = LifeItem(
            id: UUID(),
            title: "Review insurance",
            status: .pendingReview,
            dueDate: tomorrowDate,
            revision: 1
        )
        let grouping = TimelineGrouping.group(items: [pending], referenceDate: referenceDate, calendar: calendar)
        #expect(grouping.needsAttention.count == 1)
        #expect(grouping.tomorrow.count == 1)
    }

    @Test func todayAndThisWeekBuckets() {
        let laterToday = calendar.date(byAdding: .hour, value: 3, to: referenceDate)!
        let todayItem = LifeItem(
            id: UUID(),
            title: "Due today",
            status: .active,
            dueDate: laterToday,
            revision: 1
        )
        let inThreeDays = calendar.date(byAdding: .day, value: 3, to: referenceDate)!
        let thisWeekItem = LifeItem(
            id: UUID(),
            title: "In 3 days",
            status: .active,
            dueDate: inThreeDays,
            revision: 1
        )
        let grouping = TimelineGrouping.group(items: [todayItem, thisWeekItem], referenceDate: referenceDate, calendar: calendar)
        #expect(grouping.today.count == 1)
        #expect(grouping.today.first?.title == "Due today")
        #expect(grouping.thisWeek.count == 1)
        #expect(grouping.thisWeek.first?.title == "In 3 days")
    }

    @Test func waitingForItemsGoToWaitingFor() {
        let waiting = LifeItem(
            id: UUID(),
            title: "Passport courier",
            status: .active,
            itemType: "waiting_for",
            metadata: ["waitingFor": .string("DHL")],
            revision: 1
        )
        let grouping = TimelineGrouping.group(items: [waiting], referenceDate: referenceDate, calendar: calendar)
        #expect(grouping.waitingFor.count == 1)
        #expect(grouping.waitingFor.first?.id == waiting.id)
    }

    @Test func itemsWithNullOrEmptyWaitingForMetadataAreNotTreatedAsWaitingFor() {
        let overdueDate = calendar.date(byAdding: .day, value: -57, to: referenceDate)!
        let overdueItem = LifeItem(
            id: UUID(),
            title: "Credit card payment",
            status: .active,
            itemType: "bill",
            dueDate: overdueDate,
            metadata: ["waitingFor": .null, "isWaitingFor": .bool(false)],
            revision: 1
        )
        let grouping = TimelineGrouping.group(items: [overdueItem], referenceDate: referenceDate, calendar: calendar)
        #expect(grouping.waitingFor.isEmpty)
        #expect(grouping.needsAttention.count == 1)
        #expect(grouping.needsAttention.first?.id == overdueItem.id)

        let priority = PriorityGrouping(from: grouping)
        #expect(priority.carouselItems.count == 1)
        #expect(priority.carouselItems.first?.id == overdueItem.id)
    }

    @Test func dateParsingHandlesVariedFormats() {
        let formats = [
            "2026-09-21T00:00:00.000Z",
            "2026-09-22T00:00:00Z",
            "2026-09-22",
            "2026-09-22T00:00:00",
            "2026-09-22T05:30:00.000",
            "2026-09-22 00:00:00",
            "2026-09-22T00:00:00.000+05:30",
            "22 Sep 2026"
        ]
        for f in formats {
            #expect(LifeItem.parseDate(f) != nil, "Failed to parse: \(f)")
        }
    }
}
