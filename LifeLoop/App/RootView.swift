//
//  RootView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation
import SwiftUI

struct RootView: View {
    let allowsEditing: Bool
    @State private var viewModel: ItemsListViewModel
    @State private var selectedItemID: UUID?
    // The root outlives adaptive column changes, so it owns the active editor.
    @State private var editingItem: LifeItem?

    init(repository: any ItemRepository, allowsEditing: Bool = true) {
        self.allowsEditing = allowsEditing
        self.viewModel = ItemsListViewModel(repository: repository)
    }

    var body: some View {
        NavigationSplitView {
            ItemsListView(
                viewModel: viewModel,
                allowsEditing: allowsEditing,
                selectedItemID: $selectedItemID
            )
            .navigationTitle("LifeLoop")
        } detail: {
            if let item = selectedItem {
                ItemDetailView(item: item, allowsEditing: allowsEditing) {
                    editingItem = item
                }
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
        .fullScreenCover(item: $editingItem) { item in
            NavigationStack {
                ItemEditView(item: item) { updatedItem in
                    _ = try await viewModel.saveTitle(for: item, newTitle: updatedItem.title)
                }
            }
        }
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
