//
//  PriorityCarouselCard.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 18/11/26.
//

import SwiftUI

struct PriorityCarouselCard: View {
    let item: LifeItem
    var referenceDate: Date = Date()
    var fillsAvailableWidth: Bool = false
    var isMutating: Bool = false
    var onComplete: () -> Void
    var onSnooze: () -> Void
    var onEdit: () -> Void
    var onConfirmReview: (() -> Void)? = nil

    private var carouselBadge: (text: String, tint: Color, background: Color) {
        if item.status == .pendingReview {
            return ("NEEDS REVIEW", .orange, Color.orange.opacity(0.12))
        }
        let calendar = Calendar.current
        let ref = referenceDate
        if let target = TimelineGrouping.targetDate(for: item) {
            let startOfRef = calendar.startOfDay(for: ref)
            let startOfTarget = calendar.startOfDay(for: target)
            let days = calendar.dateComponents([.day], from: startOfRef, to: startOfTarget).day ?? 0
            if days < 0 || (days == 0 && target <= ref) {
                return ("OVERDUE", .red, Color.red.opacity(0.12))
            } else if days == 0 {
                return ("TODAY", .orange, Color.orange.opacity(0.12))
            } else {
                return ("UPCOMING", .blue, Color.blue.opacity(0.12))
            }
        }
        return ("UPCOMING", .blue, Color.blue.opacity(0.12))
    }

    private var formattedDate: String? {
        if let target = TimelineGrouping.targetDate(for: item) {
            return target.formatted(.dateTime.month(.abbreviated).day())
        }
        if let display = item.displayDate {
            return display
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header Row: Status Badge & Due Date (Web Parity)
            HStack(spacing: 6) {
                let badge = carouselBadge
                Text(badge.text)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(badge.tint)
                    .background(badge.background, in: Capsule())

                Spacer()

                if let dateStr = formattedDate {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(dateStr)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }

                if isMutating {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            // Title (2 Lines Clamped)
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 4)

            // Bottom Action Bar: Done (+1d, Edit)
            HStack(spacing: 12) {
                if item.status == .pendingReview, let onConfirmReview {
                    Button(action: onConfirmReview) {
                        HStack(spacing: 3) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10))
                            Text("Confirm")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Confirm AI review for \(item.title)")
                } else {
                    Button(action: onComplete) {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                            Text("Done")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mark done \(item.title)")
                }

                Button(action: onSnooze) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("+1d")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Snooze one day \(item.title)")

                Spacer()

                Button(action: onEdit) {
                    Text("Edit")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(item.title)")
            }
            .padding(.top, 8)
            .overlay(alignment: .top) {
                Divider()
            }
        }
        .padding(12)
        .frame(maxWidth: fillsAvailableWidth ? .infinity : 270, minHeight: 135, alignment: .topLeading)
        .frame(width: fillsAvailableWidth ? nil : 270, height: fillsAvailableWidth ? nil : 135)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }
}
