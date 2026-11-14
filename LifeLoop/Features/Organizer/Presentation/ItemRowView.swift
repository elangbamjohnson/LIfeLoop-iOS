//
//  ItemRowView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

struct ItemRowView: View {
    let item: LifeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.body)

            Text(statusTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var statusTitle: String {
        switch item.status {
        case .pendingReview:
            return "Needs review"
        case .active:
            return "Active"
        case .completed:
            return "Completed"
        case .snoozed:
            return "Snoozed"
        case .archived:
            return "Archived"
        case .unknown(_):
            return "Status unavailable"
        }
    }
}

#Preview("All statuses") {
    List(SampleItems.all) { item in
        ItemRowView(item: item)
    }
}
