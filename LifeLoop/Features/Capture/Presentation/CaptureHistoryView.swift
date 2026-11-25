//
//  CaptureHistoryView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 22/11/26.
//

import SwiftUI

struct CaptureHistoryRowView: View {
    let capture: Capture

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(capture.previewText)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                statusBadge(for: capture.processingStatus)
            }

            HStack {
                if let date = capture.createdAt {
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("ago")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if capture.processingStatus == .fallbackPendingRetry {
                    Text("AI retry scheduled")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Capture: \(capture.previewText), status: \(capture.processingStatus.displayLabel)")
        .accessibilityIdentifier("captureRow-\(capture.id.uuidString)")
    }

    private func statusBadge(for status: CaptureProcessingStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemImage)
                .font(.caption2)
            Text(status.displayLabel)
                .font(.caption2.weight(.medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(status.tintColor.opacity(0.12), in: Capsule())
        .foregroundStyle(status.tintColor)
    }
}
