//
//  ItemsListView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

struct ItemsListView: View {
    let viewModel: ItemsListViewModel

    @State private var retryCount = 0

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                ProgressView("Loading items…")

            case .loaded(let items):
                List(items) { item in
                    NavigationLink {
                        ItemDetailView(item: item) { updatedItem in
                            viewModel.updateItem(updatedItem)
                        }
                    } label: {
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
