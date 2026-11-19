//
//  TimelineGrouping.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 18/11/26.
//

import Foundation

struct TimelineGrouping: Equatable {
    var needsAttention: [LifeItem] = []
    var today: [LifeItem] = []
    var tomorrow: [LifeItem] = []
    var thisWeek: [LifeItem] = []
    var upcoming: [LifeItem] = []
    var waitingFor: [LifeItem] = []
    var past: [LifeItem] = []

    static func targetDate(for item: LifeItem) -> Date? {
        if let snoozedUntil = item.snoozedUntil {
            if let date = LifeItem.parseDate(snoozedUntil) { return date }
        }
        if let dueDate = item.dueDate {
            return dueDate
        }
        if case .string(let raw) = item.metadata["dueDate"], let date = LifeItem.parseDate(raw) {
            return date
        }
        if case .string(let raw) = item.metadata["expiryDate"], let date = LifeItem.parseDate(raw) {
            return date
        }
        return nil
    }

    static func group(
        items: [LifeItem],
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TimelineGrouping {
        var result = TimelineGrouping()

        let startOfRef = calendar.startOfDay(for: referenceDate)

        for item in items {
            // 1. Completed items belong in past / history
            if item.status == .completed {
                result.past.push(item)
                continue
            }

            // 2. Waiting-For items
            let isWaitingFor = item.itemType.lowercased() == "waiting_for"
                || item.itemType.lowercased() == "waitingfor"
                || item.waitingForPerson != nil
                || item.metadata["isWaitingFor"] == .bool(true)
            if isWaitingFor && item.status != .pendingReview {
                result.waitingFor.push(item)
                continue
            }

            guard let target = targetDate(for: item) else {
                if item.status == .pendingReview {
                    result.needsAttention.push(item)
                }
                result.upcoming.push(item)
                continue
            }

            let startOfTarget = calendar.startOfDay(for: target)
            let days = calendar.dateComponents([.day], from: startOfRef, to: startOfTarget).day ?? 0

            let isOverdue = days < 0 || (days == 0 && target <= referenceDate)

            if isOverdue {
                result.needsAttention.push(item)
            } else if days == 0 {
                result.today.push(item)
            } else if days == 1 {
                result.tomorrow.push(item)
            } else if days <= 7 {
                result.thisWeek.push(item)
            } else {
                result.upcoming.push(item)
            }

            // Pending review items also appear in needsAttention for Priority view
            if item.status == .pendingReview && !isOverdue {
                result.needsAttention.push(item)
            }
        }

        // Sort items chronologically within buckets
        let sortByDate: (LifeItem, LifeItem) -> Bool = { a, b in
            let dateA = targetDate(for: a) ?? .distantFuture
            let dateB = targetDate(for: b) ?? .distantFuture
            if dateA != dateB { return dateA < dateB }
            return a.title < b.title
        }

        result.needsAttention.sort(by: sortByDate)
        result.today.sort(by: sortByDate)
        result.tomorrow.sort(by: sortByDate)
        result.thisWeek.sort(by: sortByDate)
        result.upcoming.sort(by: sortByDate)
        result.waitingFor.sort(by: sortByDate)
        result.past.sort(by: sortByDate)

        return result
    }
}

private extension Array {
    mutating func push(_ element: Element) {
        append(element)
    }
}
