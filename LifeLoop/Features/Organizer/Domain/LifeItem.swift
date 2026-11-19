//
//  LifeItem.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation

struct LifeItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var status: ItemStatus
    var itemType: String = "task"
    var dueDate: Date?
    var metadata: [String: JSONValue] = [:]
    var updatedAt: String?
    var revision: Int?
    var snoozedUntil: String?
    var createdAt: String?
}

extension LifeItem {
    static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = isoFormatter.date(from: trimmed) { return d }
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let d = isoFormatter.date(from: trimmed) { return d }

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current

        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd",
            "dd MMM yyyy",
            "MM/dd/yyyy"
        ]
        for format in formats {
            df.dateFormat = format
            if let d = df.date(from: trimmed) { return d }
        }

        return nil
    }

    var displayDate: String? {
        if let createdAt, let date = Self.parseDate(createdAt) {
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
        if let target = TimelineGrouping.targetDate(for: self) {
            return target.formatted(.dateTime.day().month(.abbreviated))
        }
        if let updatedAt, let date = Self.parseDate(updatedAt) {
            return date.formatted(.dateTime.day().month(.abbreviated))
        }
        return nil
    }

    var confidencePercentage: Int? {
        if case .number(let decimal) = metadata["confidenceScore"] {
            let num = NSDecimalNumber(decimal: decimal).doubleValue
            let score = num <= 1.0 ? num * 100.0 : num
            return Int(score.rounded())
        }
        return nil
    }

    var waitingForPerson: String? {
        if case .string(let person) = metadata["waitingFor"], !person.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return person.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if case .string(let person) = metadata["person"], !person.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return person.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if case .string(let person) = metadata["waitingOn"], !person.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return person.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    var descriptionText: String? {
        if case .string(let text) = metadata["description"], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if case .string(let text) = metadata["notes"], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if case .string(let text) = metadata["rawPayload"], !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    var amountFormatted: String? {
        let amountVal: Double?
        if case .number(let decimal) = metadata["amount"] {
            amountVal = NSDecimalNumber(decimal: decimal).doubleValue
        } else if case .string(let str) = metadata["amount"], let num = Double(str) {
            amountVal = num
        } else {
            amountVal = nil
        }
        guard let amountVal else { return nil }

        let currency: String
        if case .string(let cur) = metadata["currency"] {
            currency = cur.uppercased()
        } else {
            currency = "INR"
        }
        let symbol: String
        switch currency {
        case "USD": symbol = "$"
        case "EUR": symbol = "€"
        case "GBP": symbol = "£"
        default: symbol = "₹"
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let formattedNum = formatter.string(from: NSNumber(value: amountVal)) ?? "\(amountVal)"
        return "\(symbol)\(formattedNum)"
    }

    var policyNumber: String? {
        for key in ["policyNumber", "policy_number", "policyNo"] {
            if case .string(let val) = metadata[key], !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return val.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    var vin: String? {
        for key in ["vin", "vinNumber"] {
            if case .string(let val) = metadata[key], !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return val.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    var location: String? {
        if case .string(let val) = metadata["location"], !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return val.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    var tags: [String] {
        if case .array(let arr) = metadata["tags"] {
            let strings = arr.compactMap { (val: JSONValue) -> String? in
                if case .string(let str) = val {
                    let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
                    return trimmed.isEmpty ? nil : trimmed
                }
                return nil
            }
            if !strings.isEmpty { return strings }
        }
        if case .string(let str) = metadata["tags"] {
            let parts = str.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            }.filter { !$0.isEmpty }
            if !parts.isEmpty { return parts }
        }
        return [itemType.replacingOccurrences(of: "_", with: " ")]
    }

    var isFamilyShared: Bool {
        for key in ["familyShared", "sharedWithFamily", "isShared"] {
            if case .bool(let b) = metadata[key], b { return true }
            if case .string(let s) = metadata[key], s.lowercased() == "true" { return true }
        }
        return false
    }

    var fileUrl: String? {
        if case .string(let url) = metadata["fileUrl"], !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    var formattedDeadline: String? {
        dueDate?.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var formattedSnoozedUntil: String? {
        guard let snoozedUntil else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: snoozedUntil) {
            return date.formatted(.dateTime.month(.abbreviated).day().year())
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: snoozedUntil) {
            return date.formatted(.dateTime.month(.abbreviated).day().year())
        }
        return snoozedUntil
    }

    var isOverdue: Bool {
        guard status != .pendingReview, let target = TimelineGrouping.targetDate(for: self) else {
            return false
        }
        let calendar = Calendar.current
        let ref = Date()
        let startOfRef = calendar.startOfDay(for: ref)
        let startOfTarget = calendar.startOfDay(for: target)
        let days = calendar.dateComponents([.day], from: startOfRef, to: startOfTarget).day ?? 0
        return days < 0 || (days == 0 && target <= ref)
    }

    var hasStructuredFields: Bool {
        amountFormatted != nil || dueDate != nil || policyNumber != nil || vin != nil || location != nil || snoozedUntil != nil
    }
}
