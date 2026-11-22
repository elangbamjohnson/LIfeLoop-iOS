//
//  ItemDetailView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

struct ItemDetailView: View {
    let item: LifeItem
    var capabilities: OrganizerCapabilities = .demo
    let onEdit: () -> Void
    var onSnooze: ((Int) -> Void)? = nil

    var allowsEditing: Bool {
        get { capabilities.allowsTitleEditing }
        set { capabilities = OrganizerCapabilities(allowsEditing: newValue) }
    }

    var body: some View {
        Form {
            // Section 1: Item header with title and type badge
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .accessibilityIdentifier("itemDetail")
                    HStack {
                        Label(itemTypeDisplay, systemImage: itemTypeIcon)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        statusBadge
                    }
                    if item.status == .snoozed {
                        if let snoozedUntil = item.snoozedUntil {
                            Label("Snoozed until \(snoozedUntil)", systemImage: "clock.arrow.circlepath")
                                .font(.footnote)
                                .foregroundStyle(.purple)
                        } else {
                            Label("Snoozed", systemImage: "clock.arrow.circlepath")
                                .font(.footnote)
                                .foregroundStyle(.purple)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // Section 2: Due date (only if set)
            if let dueDate = item.dueDate {
                Section("Due") {
                    Label(formattedDate(dueDate), systemImage: "calendar")
                        .foregroundStyle(isOverdue ? .red : .primary)
                }
            }

            // Section 3: Metadata (known fields + unknown disclosure)
            if !item.metadata.isEmpty {
                metadataSection
            }
        }
        .navigationTitle("Item details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if capabilities.allowsItemMutations, let onSnooze {
                    Menu {
                        Button("Tomorrow (+1 Day)") { onSnooze(1) }
                        Button("+3 Days") { onSnooze(3) }
                        Button("Next Week (+7 Days)") { onSnooze(7) }
                    } label: {
                        Label("Snooze", systemImage: "clock.arrow.circlepath")
                    }
                    .accessibilityIdentifier("snoozeItem")
                }
                if capabilities.allowsTitleEditing {
                    Button("Edit", action: onEdit)
                        .accessibilityIdentifier("editItem")
                }
            }
        }
    }

    private var itemTypeDisplay: String {
        switch item.itemType {
        case "task": return "Task"
        case "reminder": return "Reminder"
        case "note": return "Note"
        case "event": return "Event"
        case "waiting_for": return "Waiting For"
        default: return item.itemType.capitalized
        }
    }

    private var itemTypeIcon: String {
        switch item.itemType {
        case "task": return "checkmark.circle"
        case "reminder": return "bell"
        case "note": return "note.text"
        case "event": return "calendar"
        case "waiting_for": return "clock.arrow.circlepath"
        default: return "square.grid.2x2"
        }
    }

    private var statusBadge: some View {
        let (label, color) = statusInfo
        return Text(label)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var statusInfo: (String, Color) {
        switch item.status {
        case .pendingReview: return ("Needs Review", .orange)
        case .active: return ("Active", .blue)
        case .completed: return ("Completed", .green)
        case .snoozed: return ("Snoozed", .purple)
        case .archived: return ("Archived", .gray)
        case .unknown(let v): return (v.capitalized, .gray)
        }
    }

    private var isOverdue: Bool {
        guard let dueDate = item.dueDate else { return false }
        return dueDate < Date() && item.status != .completed && item.status != .archived
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let hasTime = item.metadata["hasExplicitTime"] == .bool(true)
        formatter.dateStyle = .long
        formatter.timeStyle = hasTime ? .short : .none
        return formatter.string(from: date)
    }

    @ViewBuilder
    private var metadataSection: some View {
        // Show known meaningful metadata fields
        let knownKeys = ["amount", "currency", "url", "phone", "address", "notes"]
        let knownEntries = item.metadata.filter { knownKeys.contains($0.key) }
        let unknownEntries = item.metadata.filter { !knownKeys.contains($0.key) }

        if !knownEntries.isEmpty {
            Section("Details") {
                ForEach(knownEntries.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    LabeledContent(key.capitalized, value: metadataValueDisplay(value))
                }
            }
        }

        if !unknownEntries.isEmpty {
            Section {
                Label("Additional information is available on the web.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metadataValueDisplay(_ value: JSONValue) -> String {
        switch value {
        case .string(let s): return s
        case .number(let n): return n.description
        case .bool(let b): return b ? "Yes" : "No"
        case .null: return "—"
        case .object, .array: return "See web app"
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(item: SampleItems.all[0], onEdit: {})
    }
}
