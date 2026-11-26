//
//  CaptureHistoryView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 22/11/26.
//

import SwiftUI

struct CaptureHistoryRowView: View {
    let capture: Capture
    var associatedItems: [LifeItem] = []
    var isMutating: Bool = false
    var mutatingItemIDs: Set<UUID> = []
    var allowsMutations: Bool = true
    var onConfirmItem: ((LifeItem) -> Void)? = nil
    var onEditItem: ((LifeItem) -> Void)? = nil
    var onRetry: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    private var statusColor: Color {
        if capture.processingStatus == .completed && capture.aiEnrichmentFailed {
            return .orange
        }
        return capture.processingStatus.tintColor
    }

    private var statusIcon: String {
        if capture.processingStatus == .completed && capture.aiEnrichmentFailed {
            return "exclamationmark.triangle.fill"
        }
        return capture.processingStatus.systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(capture.previewText)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                statusBadge
            }

            if !associatedItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Extracted items (\(associatedItems.count))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(associatedItems) { item in
                        associatedItemRow(item)
                    }
                }
                .padding(8)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            HStack(spacing: 8) {
                if let date = capture.createdAt {
                    HStack(spacing: 3) {
                        Text(date, style: .relative)
                        Text("ago")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                if isMutating {
                    ProgressView()
                        .controlSize(.mini)
                }

                if allowsMutations, capture.canRetry, let onRetry {
                    Button(action: onRetry) {
                        Label("Retry AI", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(.orange)
                            .background(Color.orange.opacity(0.12), in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isMutating)
                    .accessibilityLabel("Retry AI extraction")
                    .accessibilityIdentifier("retryCapture-\(capture.id.uuidString)")
                }

                if allowsMutations, let onDelete {
                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isMutating)
                    .accessibilityLabel("Delete capture")
                    .accessibilityIdentifier("deleteCapture-\(capture.id.uuidString)")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Capture: \(capture.previewText), status: \(capture.statusDisplayLabel)")
        .accessibilityIdentifier("captureRow-\(capture.id.uuidString)")
    }

    @ViewBuilder
    private func associatedItemRow(_ item: LifeItem) -> some View {
        let isItemMutating = mutatingItemIDs.contains(item.id)
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(item.status == .completed ? .secondary : .primary)
                    .strikethrough(item.status == .completed, color: .secondary)
                    .lineLimit(2)

                Text(itemStatusLabel(item))
                    .font(.caption2)
                    .foregroundStyle(item.status == .pendingReview ? .orange : .secondary)
            }

            Spacer(minLength: 4)

            if isItemMutating {
                ProgressView()
                    .controlSize(.mini)
            }

            if allowsMutations, item.status == .pendingReview, let onConfirmItem {
                Button {
                    onConfirmItem(item)
                } label: {
                    Text("Confirm")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(.white)
                        .background(Color.orange, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isItemMutating)
                .accessibilityLabel("Confirm \(item.title)")
                .accessibilityIdentifier("captureConfirmItem-\(item.id.uuidString)")
            }

            if allowsMutations, let onEditItem {
                Button {
                    onEditItem(item)
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isItemMutating)
                .accessibilityLabel("Edit \(item.title)")
                .accessibilityIdentifier("captureEditItem-\(item.id.uuidString)")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("captureItem-\(item.id.uuidString)")
    }

    private func itemStatusLabel(_ item: LifeItem) -> String {
        switch item.status {
        case .pendingReview:
            if let pct = item.confidencePercentage {
                return "Needs Review (\(pct)%)"
            }
            return "Needs Review"
        case .active: return "Active"
        case .completed: return "Completed"
        case .snoozed: return "Snoozed"
        case .archived: return "Archived"
        case .unknown(let raw): return raw.capitalized
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: statusIcon)
                .font(.caption2)
            Text(capture.statusDisplayLabel)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.12), in: Capsule())
        .foregroundStyle(statusColor)
    }
}
