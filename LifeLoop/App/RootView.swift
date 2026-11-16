//
//  RootView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation
import SwiftUI

struct RootView: View {
    @State private var viewModel: ItemsListViewModel
    @State private var selectedItemID: UUID?

    init(repository: any ItemRepository) {
        self.viewModel = ItemsListViewModel(repository: repository)
    }

    var body: some View {
        NavigationSplitView {
            ItemsListView(
                viewModel: viewModel,
                selectedItemID: $selectedItemID
            )
            .navigationTitle("LifeLoop")
        } detail: {
            if let item = selectedItem {
                ItemDetailView(item: item) { updatedItem in
                    viewModel.updateItem(updatedItem)
                }
                .id(item.id)
            } else {
                ContentUnavailableView(
                    "Select an item",
                    systemImage: "doc.text",
                    description: Text(
                        "Choose an item to view its details."
                    )
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var selectedItem: LifeItem? {
        guard let selectedItemID = selectedItemID else {
            return nil
        }

        switch viewModel.state {
        case .loaded(let items):
            return items.first { item in
                item.id == selectedItemID
            }

        default:
            return nil
        }
    }
}

#Preview("Sample items") {
    RootView(
        repository: SampleItemRepository(items: SampleItems.all)
    )
}

#Preview("Empty list") {
    RootView(
        repository: SampleItemRepository(items: [])
    )
}

#Preview("Loading failure") {
    RootView(
        repository: SampleItemRepository(
            items: [],
            shouldFail: true
        )
    )
}
