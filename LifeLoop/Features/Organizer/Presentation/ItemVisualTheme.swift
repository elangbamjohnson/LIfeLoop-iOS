//
//  ItemVisualTheme.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 18/11/26.
//

import SwiftUI

struct ItemCategoryTheme {
    let label: String
    let iconName: String
    let tint: Color

    static func theme(for itemType: String) -> ItemCategoryTheme {
        switch itemType.lowercased() {
        case "payment", "bill", "financial", "purchase":
            return ItemCategoryTheme(label: "Financial", iconName: "creditcard", tint: .green)
        case "document":
            return ItemCategoryTheme(label: "Document", iconName: "doc.text", tint: .green)
        case "vehicle", "car":
            return ItemCategoryTheme(label: "Vehicle", iconName: "car", tint: .orange)
        case "warranty":
            return ItemCategoryTheme(label: "Warranty", iconName: "shield.checkerboard", tint: .orange)
        case "renewal":
            return ItemCategoryTheme(label: "Renewal", iconName: "arrow.clockwise", tint: .blue)
        case "subscription":
            return ItemCategoryTheme(label: "Subscription", iconName: "repeat", tint: .blue)
        case "appointment":
            return ItemCategoryTheme(label: "Appointment", iconName: "calendar", tint: .blue)
        case "reminder":
            return ItemCategoryTheme(label: "Reminder", iconName: "bell", tint: .blue)
        case "deadline":
            return ItemCategoryTheme(label: "Deadline", iconName: "flag", tint: .red)
        case "waiting_for":
            return ItemCategoryTheme(label: "Waiting For", iconName: "hourglass", tint: .purple)
        case "person", "personal", "memory":
            return ItemCategoryTheme(label: "Personal", iconName: "person.fill", tint: .purple)
        default:
            let formatted = itemType.replacingOccurrences(of: "_", with: " ").capitalized
            return ItemCategoryTheme(
                label: formatted.isEmpty ? "Task" : formatted,
                iconName: "tag",
                tint: .secondary
            )
        }
    }
}

struct ItemBadgeInfo {
    let text: String
    let iconName: String?
    let tint: Color
    let background: Color

    static func badge(for item: LifeItem, referenceDate: Date = Date(), calendar: Calendar = .current) -> ItemBadgeInfo? {
        if item.status == .completed {
            return ItemBadgeInfo(
                text: "Completed",
                iconName: nil,
                tint: .green,
                background: Color.green.opacity(0.12)
            )
        }

        if item.status == .pendingReview {
            return ItemBadgeInfo(
                text: "Needs Review",
                iconName: "sparkles",
                tint: .orange,
                background: Color.orange.opacity(0.12)
            )
        }

        if item.status == .snoozed {
            var label = "Snoozed"
            if let until = item.snoozedUntil {
                if let date = LifeItem.parseDate(until) {
                    label = "Snoozed to \(date.formatted(.dateTime.month(.abbreviated).day()))"
                }
            }
            return ItemBadgeInfo(
                text: label,
                iconName: "clock.arrow.circlepath",
                tint: .purple,
                background: Color.purple.opacity(0.12)
            )
        }

        guard let target = TimelineGrouping.targetDate(for: item) else {
            return nil
        }

        let startOfRef = calendar.startOfDay(for: referenceDate)
        let startOfTarget = calendar.startOfDay(for: target)
        let days = calendar.dateComponents([.day], from: startOfRef, to: startOfTarget).day ?? 0

        if days < 0 || (days == 0 && target <= referenceDate) {
            let label = days < 0 ? "Overdue by \(abs(days))d" : "Overdue"
            return ItemBadgeInfo(
                text: label,
                iconName: "calendar",
                tint: .red,
                background: Color.red.opacity(0.12)
            )
        } else if days == 0 {
            return ItemBadgeInfo(
                text: "Due today",
                iconName: "calendar",
                tint: .orange,
                background: Color.orange.opacity(0.12)
            )
        } else if days == 1 {
            return ItemBadgeInfo(
                text: "Tomorrow",
                iconName: "calendar",
                tint: .blue,
                background: Color.blue.opacity(0.12)
            )
        } else if days <= 7 {
            return ItemBadgeInfo(
                text: "In \(days) days",
                iconName: "calendar",
                tint: .blue,
                background: Color.blue.opacity(0.12)
            )
        } else {
            return ItemBadgeInfo(
                text: target.formatted(.dateTime.month(.abbreviated).day()),
                iconName: "calendar",
                tint: .secondary,
                background: Color.secondary.opacity(0.10)
            )
        }
    }
}
