//
//  ItemRowView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

struct ItemRowView: View {
    let item: LifeItem
    var isMutating: Bool = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.body)

                Text(statusTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if isMutating {
                Spacer()
                ProgressView()
                    .controlSize(.small)
            }
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
