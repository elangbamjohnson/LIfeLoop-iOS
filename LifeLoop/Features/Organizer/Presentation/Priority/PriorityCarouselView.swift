//
//  PriorityCarouselView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 18/11/26.
//

import SwiftUI

struct PriorityCarouselView: View {
    let items: [LifeItem]
    let mutatingItemIDs: Set<UUID>
    let capabilities: OrganizerCapabilities
    var onComplete: (LifeItem) -> Void
    var onSnooze: (LifeItem) -> Void
    var onEdit: (LifeItem) -> Void
    var onConfirmReview: ((LifeItem) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bell")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.orange)
                Text("REMINDERS & DUE TODAY (\(items.count))")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.orange)
                Spacer()
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        PriorityCarouselCard(
                            item: item,
                            isMutating: mutatingItemIDs.contains(item.id),
                            onComplete: { onComplete(item) },
                            onSnooze: { onSnooze(item) },
                            onEdit: { onEdit(item) },
                            onConfirmReview: onConfirmReview != nil ? { onConfirmReview?(item) } : nil
                        )
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
            }
        }
        .padding(.vertical, 6)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }
}
