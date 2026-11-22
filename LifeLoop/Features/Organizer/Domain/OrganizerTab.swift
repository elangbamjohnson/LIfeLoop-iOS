//
//  OrganizerTab.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 18/11/26.
//

import Foundation

enum OrganizerTab: String, CaseIterable, Identifiable {
    case priority = "Priority"
    case timeline = "Timeline"
    case inbox = "Inbox"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .priority: return "sparkles"
        case .timeline: return "clock"
        case .inbox: return "tray"
        }
    }
}
