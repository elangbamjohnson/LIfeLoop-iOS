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
    let onSignOut: (() -> Void)?
    @State private var viewModel: ItemsListViewModel
    @State private var captureViewModel: CaptureViewModel
    @State private var selectedItemID: UUID?
    // The root outlives adaptive column changes, so it owns the active editor.
    @State private var editingItem: LifeItem?
    @State private var isQuickCapturePresented = false
    @State private var isCreatingItem = false
    @State private var selectedTab: OrganizerTab = .priority
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    var allowsEditing: Bool {
        capabilities.allowsTitleEditing || capabilities.allowsItemMutations
    }

    init(
        repository: any ItemRepository,
        captureRepository: any CaptureRepository = SampleCaptureRepository(),
        capabilities: OrganizerCapabilities = .demo,
        localStore: AccountLocalStore? = nil,
        onSessionExpired: @escaping () -> Void = {},
        onSignOut: (() -> Void)? = nil
    ) {
        self.capabilities = capabilities
        self.localStore = localStore
        self.onSessionExpired = onSessionExpired
        self.onSignOut = onSignOut
        self.viewModel = ItemsListViewModel(repository: repository)
        self.captureViewModel = CaptureViewModel(repository: captureRepository)
    }

    init(
        repository: any ItemRepository,
        captureRepository: any CaptureRepository = SampleCaptureRepository(),
        allowsEditing: Bool,
        localStore: AccountLocalStore? = nil,
        onSessionExpired: @escaping () -> Void = {},
        onSignOut: (() -> Void)? = nil
    ) {
        self.init(
            repository: repository,
            captureRepository: captureRepository,
            capabilities: allowsEditing ? .demo : .none,
            localStore: localStore,
            onSessionExpired: onSessionExpired,
            onSignOut: onSignOut
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TabNavigationView(
                tab: .priority,
                viewModel: viewModel,
                captureViewModel: captureViewModel,
                capabilities: capabilities,
                editingItem: $editingItem,
                selectedItemID: $selectedItemID,
                onCreateItem: { isQuickCapturePresented = true },
                onSignOut: onSignOut
            )
            .tabItem {
                Label("Priority", systemImage: "sparkles")
            }
            .tag(OrganizerTab.priority)

            TabNavigationView(
                tab: .timeline,
                viewModel: viewModel,
                captureViewModel: captureViewModel,
                capabilities: capabilities,
                editingItem: $editingItem,
                selectedItemID: $selectedItemID,
                onCreateItem: { isQuickCapturePresented = true },
                onSignOut: onSignOut
            )
            .tabItem {
                Label("Timeline", systemImage: "clock")
            }
            .tag(OrganizerTab.timeline)

            TabNavigationView(
                tab: .inbox,
                viewModel: viewModel,
                captureViewModel: captureViewModel,
                capabilities: capabilities,
                editingItem: $editingItem,
                selectedItemID: $selectedItemID,
                onCreateItem: { isQuickCapturePresented = true },
                onSignOut: onSignOut
            )
            .tabItem {
                Label("Inbox", systemImage: "tray")
            }
            .tag(OrganizerTab.inbox)
        }
        .tint(tabTint(for: selectedTab))
        .task(id: scenePhase) {
            captureViewModel.onItemsNeedsRefresh = { [weak viewModel] in
                await viewModel?.refreshAfterCapture()
            }
            captureViewModel.onSessionExpired = onSessionExpired
            captureViewModel.setForegroundActive(scenePhase == .active)
            guard scenePhase == .active else { return }
            await captureViewModel.loadCaptures()
            if !Task.isCancelled { captureViewModel.startPollingIfNeeded() }
        }
        .task(id: selectedTab) {
            guard selectedTab == .inbox, scenePhase == .active else { return }
            await captureViewModel.loadCaptures()
            if !Task.isCancelled { captureViewModel.startPollingIfNeeded() }
        }
        .onChange(of: scenePhase) { _, phase in
            // Invalidate immediately, before a suspended refresh can resume.
            captureViewModel.setForegroundActive(phase == .active)
        }
        .onDisappear { captureViewModel.setForegroundActive(false) }
        .onChange(of: viewModel.requiresSignIn) { _, expired in
            if expired {
                captureViewModel.reset()
                onSessionExpired()
            }
        }
        .sheet(isPresented: $isQuickCapturePresented) {
            CaptureComposerView(
                onCapture: { text in
                    _ = try await captureViewModel.submitTextCapture(text)
                },
                onOpenManualCreation: {
                    isCreatingItem = true
                }
            )
        }
        .sheet(isPresented: $isCreatingItem) {
            NavigationStack {
                ItemCreateView { title, itemType, dueDate in
                    _ = try await viewModel.createItem(title: title, itemType: itemType, dueDate: dueDate)
                }
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

    private func tabTint(for tab: OrganizerTab) -> Color {
        switch tab {
        case .priority: return .orange
        case .timeline: return .blue
        case .inbox: return .green
        }
    }
}

// MARK: - Tab Navigation View Container

private struct TabNavigationView: View {
    let tab: OrganizerTab
    let viewModel: ItemsListViewModel
    let captureViewModel: CaptureViewModel
    let capabilities: OrganizerCapabilities
    @Binding var editingItem: LifeItem?
    @Binding var selectedItemID: UUID?
    var onCreateItem: (() -> Void)? = nil
    var onSignOut: (() -> Void)? = nil
    @State private var navigationPath: [UUID] = []
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .compact {
            NavigationStack(path: $navigationPath) {
                ItemsListView(
                    viewModel: viewModel,
                    captureViewModel: captureViewModel,
                    tab: tab,
                    capabilities: capabilities,
                    onEditItem: { item in
                        editingItem = item
                    },
                    onSelectItem: { item in
                        selectedItemID = item.id
                        navigationPath = [item.id]
                    },
                    onCreateItem: onCreateItem,
                    selectedItemID: $selectedItemID
                )
                .navigationTitle("LifeLoop")
                .toolbar {
                    if let onSignOut {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button(role: .destructive) {
                                    captureViewModel.reset()
                                    onSignOut()
                                } label: {
                                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            } label: {
                                Image(systemName: "person.crop.circle")
                            }
                            .accessibilityLabel("Account menu")
                            .accessibilityIdentifier("accountMenuButton")
                        }
                    }
                }
                .navigationDestination(for: UUID.self) { itemID in
                    if let item = viewModel.items.first(where: { $0.id == itemID }) {
                        ItemDetailView(item: item, capabilities: capabilities) {
                            editingItem = item
                        } onSnooze: { days in
                            Task { await viewModel.snoozeItem(item, days: days) }
                        }
                    }
                }
                .safeAreaInset(edge: .top) {
                    if viewModel.showingCache, let date = viewModel.lastLoadedAt {
                        Text("Offline · Saved \(date.formatted())")
                            .font(.footnote).padding(8)
                    }
                }
            }
        } else {
            NavigationSplitView {
                ItemsListView(
                    viewModel: viewModel,
                    captureViewModel: captureViewModel,
                    tab: tab,
                    capabilities: capabilities,
                    onEditItem: { item in
                        editingItem = item
                    },
                    onSelectItem: { item in
                        selectedItemID = item.id
                    },
                    onCreateItem: onCreateItem,
                    selectedItemID: $selectedItemID
                )
                .navigationTitle("LifeLoop")
                .toolbar {
                    if let onSignOut {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button(role: .destructive) {
                                    captureViewModel.reset()
                                    onSignOut()
                                } label: {
                                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                }
                            } label: {
                                Image(systemName: "person.crop.circle")
                            }
                            .accessibilityLabel("Account menu")
                            .accessibilityIdentifier("accountMenuButton")
                        }
                    }
                }
                .safeAreaInset(edge: .top) {
                    if viewModel.showingCache, let date = viewModel.lastLoadedAt {
                        Text("Offline · Saved \(date.formatted())")
                            .font(.footnote).padding(8)
                    }
                }
            } detail: {
                if let selectedItemID,
                   let item = viewModel.items.first(where: { $0.id == selectedItemID }) {
                    ItemDetailView(item: item, capabilities: capabilities) {
                        editingItem = item
                    } onSnooze: { days in
                        Task { await viewModel.snoozeItem(item, days: days) }
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
        }
    }
}
