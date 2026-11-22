//
//  ItemRowView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

struct ItemRowView: View {
    let item: LifeItem
    var expanded: Bool? = nil
    var onToggleExpand: (() -> Void)? = nil
    var isMutating: Bool = false
    var onToggleComplete: (() -> Void)? = nil
    var onConfirmReview: (() -> Void)? = nil
    var onSnooze: ((Int) -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @State private var localIsExpanded = false

    private var isExpanded: Bool { expanded ?? localIsExpanded }

    private var categoryTheme: ItemCategoryTheme {
        ItemCategoryTheme.theme(for: item.itemType)
    }

    private var badgeInfo: ItemBadgeInfo? {
        ItemBadgeInfo.badge(for: item)
    }

    private var waitingForPerson: String? {
        item.waitingForPerson
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Header Row: Category Pill, Date, and Always-Visible Action Icons
            HStack(alignment: .center, spacing: 6) {
                // Category Pill
                HStack(spacing: 4) {
                    Image(systemName: categoryTheme.iconName)
                        .font(.system(size: 10, weight: .semibold))
                    Text(categoryTheme.label)
                        .font(.system(size: 11, weight: .semibold))
                }
                .fixedSize()
                .padding(.horizontal, 8)
                .padding(.vertical, 3.5)
                .foregroundStyle(categoryTheme.tint)
                .background(categoryTheme.tint.opacity(0.12), in: Capsule())

                // AI Confidence Pill (if pending review)
                if let confidence = item.confidencePercentage, item.status == .pendingReview {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Needs Review (\(confidence)%)")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .fixedSize()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(.orange)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                }

                // Creation / Target Date (e.g. "21 Sep")
                if let dateString = item.displayDate {
                    Text(dateString)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(uiColor: .secondaryLabel))
                        .padding(.leading, 2)
                        .fixedSize()
                }

                Spacer()

                // Action Icons (Confirm, Snooze, Edit, Delete, ChevronDown)
                HStack(spacing: 8) {
                    if item.status == .pendingReview, let onConfirmReview {
                        Button(action: onConfirmReview) {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Confirm")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .fixedSize(horizontal: true, vertical: true)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(Color.orange, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Confirm AI review for \(item.title)")
                        .accessibilityIdentifier("confirmReview-\(item.id.uuidString)")
                    }

                    if isMutating {
                        ProgressView()
                            .controlSize(.mini)
                    }

                    if item.status != .pendingReview && item.itemType != "waiting_for", let onSnooze {
                        Menu {
                            Button("+1 Day (Tomorrow)") { onSnooze(1) }
                            Button("+3 Days") { onSnooze(3) }
                            Button("Next Week (+7d)") { onSnooze(7) }
                        } label: {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Snooze \(item.title)")
                    }

                    if let onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit \(item.title)")
                        .accessibilityIdentifier("editItemQuick-\(item.id.uuidString)")
                    }

                    if let onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete \(item.title)")
                    }

                    // Chevron Expand/Collapse Arrow (omitted for pending review items matching web app)
                    if item.status != .pendingReview {
                        Button {
                            if let onToggleExpand {
                                onToggleExpand()
                            } else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    localIsExpanded.toggle()
                                }
                            }
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color(uiColor: .tertiaryLabel))
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isExpanded ? "Collapse item" : "Expand item")
                        .accessibilityIdentifier("chevronExpand-\(item.id.uuidString)")
                    }
                }
            }

            // 2. Main Title Row: Checkbox, Title, and Due Date Badge
            HStack(alignment: .center, spacing: 10) {
                // Rounded Square Checkbox
                if let onToggleComplete {
                    Button(action: onToggleComplete) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(item.status == .completed ? Color.green : Color(uiColor: .separator), lineWidth: 1.5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(item.status == .completed ? Color.green : Color.clear)
                                )
                                .frame(width: 20, height: 20)

                            if item.status == .completed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.status == .completed ? "Mark incomplete" : "Mark complete")
                    .accessibilityIdentifier("toggleComplete-\(item.id.uuidString)")
                }

                // Title Text
                Text(item.title)
                    .font(.system(size: 15, weight: .semibold))
                    .strikethrough(item.status == .completed, color: .secondary)
                    .foregroundStyle(item.status == .completed ? .secondary : .primary)
                    .lineLimit(isExpanded ? nil : 2)

                // Overdue / Due Date Badge (e.g. Overdue by 57d)
                if let badge = badgeInfo, item.status != .pendingReview, item.status != .completed {
                    HStack(spacing: 3) {
                        Image(systemName: badge.iconName ?? "calendar")
                            .font(.system(size: 10, weight: .semibold))
                        Text(badge.text)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .fixedSize()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(badge.tint)
                    .background(badge.background, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(badge.tint.opacity(0.4), lineWidth: 1)
                    )
                }

                Spacer(minLength: 0)
            }

            // Subtitle if waiting for someone
            if let person = waitingForPerson {
                Text("Waiting for: \(person)")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .padding(.leading, 38)
            }

            // 3. Expandable Complete Information Container (Web Parity)
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .padding(.top, 4)

                    // Description / Notes
                    if let description = item.descriptionText, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                    }

                    // Key-Value Structured Metadata Grid
                    if item.hasStructuredFields {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                            if let amountStr = item.amountFormatted {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("AMOUNT DUE")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text(amountStr)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.green)
                                }
                            }

                            if let deadline = item.formattedDeadline {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DEADLINE")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text(deadline)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(item.isOverdue ? .red : .primary)
                                }
                            }

                            if let policy = item.policyNumber {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("POLICY #")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text(policy)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                }
                            }

                            if let vin = item.vin {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("VIN / ASSET #")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text(vin)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                }
                            }

                            if let loc = item.location {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("LOCATION")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text(loc)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                }
                            }

                            if let snoozed = item.formattedSnoozedUntil {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("SNOOZED UNTIL")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 3) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 10))
                                        Text(snoozed)
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Tags & Badges Footer
                    HStack(spacing: 8) {
                        let tags = item.tags
                        if !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.system(size: 11))
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 6))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                        Spacer()

                        if item.isFamilyShared {
                            Label("Family", systemImage: "person.2.fill")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .foregroundStyle(.orange)
                                .background(Color.orange.opacity(0.12), in: Capsule())
                        }

                        if let urlString = item.fileUrl, let url = URL(string: urlString) {
                            Link(destination: url) {
                                Label("Attachment", systemImage: "paperclip")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.blue)
                            }
                        }
                    }

                    // Waiting For Specialized Action Bar (Web App Parity: Received, Remind me later, Follow up)
                    if item.itemType == "waiting_for" && item.status != .completed {
                        HStack(spacing: 8) {
                            if let onToggleComplete {
                                Button {
                                    onToggleComplete()
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                        Text("Received")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .fixedSize()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(Color.green)
                                    .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Mark as received")
                                .accessibilityIdentifier("receivedItem-\(item.id.uuidString)")
                            }

                            if let onSnooze {
                                Menu {
                                    Button("+1 Day (Tomorrow)") { onSnooze(1) }
                                    Button("+3 Days") { onSnooze(3) }
                                    Button("Next Week (+7d)") { onSnooze(7) }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 11, weight: .medium))
                                        Text("Remind me later")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                    .fixedSize()
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .foregroundStyle(Color.primary)
                                    .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color(uiColor: .separator).opacity(0.2), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remind me later")
                                .accessibilityIdentifier("remindLaterItem-\(item.id.uuidString)")
                            }

                            Spacer(minLength: 4)

                            if let person = waitingForPerson,
                               let mailto = URL(string: "mailto:?subject=Following%20up%20regarding%20\(item.title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&body=Hi%20\(person.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""),%0D%0A%0D%0AJust%20following%20up%20on%20this.") {
                                Link(destination: mailto) {
                                    Text("Follow up")
                                        .font(.system(size: 12, weight: .semibold))
                                        .fixedSize()
                                        .foregroundStyle(Color(uiColor: .systemBackground))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Color(uiColor: .label), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .accessibilityLabel("Follow up with \(person)")
                                .accessibilityIdentifier("followUpItem-\(item.id.uuidString)")
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .transition(expanded != nil ? .opacity : .asymmetric(
                    insertion: .opacity.animation(.easeInOut(duration: 0.2).delay(0.06)),
                    removal: .opacity.animation(.easeInOut(duration: 0.14))
                ))
                .clipped()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }
}

#Preview("All statuses") {
    List(SampleItems.all) { item in
        ItemRowView(item: item)
    }
}

#Preview("Long title and large text") {
    List {
        ItemRowView(item: LifeItem(
            id: SampleItems.all[0].id,
            title: "Collect the documents needed to renew car insurance",
            status: .pendingReview
        ))
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
