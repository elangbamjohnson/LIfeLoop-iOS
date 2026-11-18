//
//  RootView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation
import SwiftUI

struct RootView: View {
    let capabilities: OrganizerCapabilities
    let localStore: AccountLocalStore?
    let onSessionExpired: () -> Void
    @State private var viewModel: ItemsListViewModel
    @State private var selectedItemID: UUID?
    // The root outlives adaptive column changes, so it owns the active editor.
    @State private var editingItem: LifeItem?

    var allowsEditing: Bool {
        capabilities.allowsTitleEditing || capabilities.allowsItemMutations
    }

    init(
        repository: any ItemRepository,
        capabilities: OrganizerCapabilities = .demo,
        localStore: AccountLocalStore? = nil,
        onSessionExpired: @escaping () -> Void = {}
    ) {
        self.capabilities = capabilities
        self.localStore = localStore
        self.onSessionExpired = onSessionExpired
        self.viewModel = ItemsListViewModel(repository: repository)
    }

    init(
        repository: any ItemRepository,
        allowsEditing: Bool,
        localStore: AccountLocalStore? = nil,
        onSessionExpired: @escaping () -> Void = {}
    ) {
        self.init(
            repository: repository,
            capabilities: allowsEditing ? .demo : .none,
            localStore: localStore,
            onSessionExpired: onSessionExpired
        )
    }

    var body: some View {
        NavigationSplitView {
            ItemsListView(
                viewModel: viewModel,
                capabilities: capabilities,
                selectedItemID: $selectedItemID
            )
            .navigationTitle("LifeLoop")
        } detail: {
            if let item = selectedItem {
                ItemDetailView(item: item, capabilities: capabilities) {
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
        .onChange(of: viewModel.requiresSignIn) { _, expired in
            if expired { onSessionExpired() }
        }
        .safeAreaInset(edge: .top) {
            if viewModel.showingCache, let date = viewModel.lastLoadedAt {
                Text("Offline · Saved \(date.formatted())")
                    .font(.footnote).padding(8)
            }
        }
        .fullScreenCover(item: $editingItem) { item in
            NavigationStack {
                ItemEditView(
                    item: item,
                    localStore: localStore,
                    onSave: { updatedItem in
                        _ = try await viewModel.saveTitle(for: updatedItem, newTitle: updatedItem.title)
                    },
                    onReload: {
                        await viewModel.forceLoad()
                        if case .loaded(let items) = viewModel.state,
                           let reloaded = items.first(where: { $0.id == item.id }) {
                            return reloaded
                        }
                        return item
                    }
                )
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
