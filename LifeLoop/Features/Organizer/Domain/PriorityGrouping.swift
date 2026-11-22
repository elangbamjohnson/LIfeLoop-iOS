//
//  PriorityGrouping.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 18/11/26.
//

import Foundation

/// Specific derived grouping for the Priority tab.
/// In the web app:
/// 1. Reminders / Due Today Carousel = needsAttention + today (non-completed)
/// 2. Needs Attention = overdue items + pending_review items
/// 3. Today = items due today, excluding pending_review (since they appear in Needs Attention)
/// 4. Upcoming = tomorrow + thisWeek + upcoming, excluding pending_review
/// 5. Waiting For = delegated tasks
struct PriorityGrouping: Equatable {
    let carouselItems: [LifeItem]
    let needsAttention: [LifeItem]
    let today: [LifeItem]
    let upcoming: [LifeItem]
    let waitingFor: [LifeItem]

    var isEmpty: Bool {
        needsAttention.isEmpty && today.isEmpty && upcoming.isEmpty && waitingFor.isEmpty
    }

    init(from timeline: TimelineGrouping) {
        self.needsAttention = timeline.needsAttention
        self.today = timeline.today.filter { $0.status != .pendingReview }
        self.upcoming = (timeline.tomorrow + timeline.thisWeek + timeline.upcoming)
            .filter { $0.status != .pendingReview }
        self.waitingFor = timeline.waitingFor
        self.carouselItems = timeline.needsAttention + self.today
    }
}
