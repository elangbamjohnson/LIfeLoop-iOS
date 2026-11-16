//
//  ItemsListView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation
import SwiftUI

struct ItemsListView: View {
    let viewModel: ItemsListViewModel

    @Binding var selectedItemID: UUID?
    @State private var retryCount = 0

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Loading items…")

            case .loaded(let items):
                List(items, selection: $selectedItemID) { item in
                    NavigationLink(value: item.id) {
                        ItemRowView(item: item)
                    }
                }

            case .empty:
                ContentUnavailableView(
                    "No items yet",
                    systemImage: "tray",
                    description: Text(
                        "Your items will appear here."
                    )
                )

            case .failed(let message):
                ContentUnavailableView {
                    Label(
                        "Unable to load items",
                        systemImage: "exclamationmark.triangle"
                    )
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") {
                        retryCount += 1
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: retryCount) {
            await viewModel.loadIfNeeded()
        }
    }
}
