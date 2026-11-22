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
  var tab: OrganizerTab = .priority
  var capabilities: OrganizerCapabilities = .demo
  var onEditItem: ((LifeItem) -> Void)? = nil
  var onSelectItem: ((LifeItem) -> Void)? = nil

  var allowsEditing: Bool {
    get { capabilities.allowsItemMutations }
    set { capabilities = OrganizerCapabilities(allowsEditing: newValue) }
  }

  @Binding var selectedItemID: UUID?
  @State private var retryCount = 0
  @State private var itemToDelete: LifeItem?
  @State private var showDeleteConfirmation = false
  @State private var itemToSnooze: LifeItem?
  @State private var showSnoozeDialog = false
  @State private var searchText = ""
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var expandedIDs: Set<UUID> = []

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        ProgressView("Loading items…")

      case .loaded(let allItems):
        let filteredItems = filterItems(allItems)
        if filteredItems.isEmpty && !allItems.isEmpty {
          ContentUnavailableView.search(text: searchText)
        } else {
          listContent(for: filteredItems)
        }

      case .empty:
        ContentUnavailableView(
          "No items yet",
          systemImage: "tray",
          description: Text("Your items will appear here.")
        )

      case .failed(let message):
        ContentUnavailableView {
          Label("Unable to load items", systemImage: "exclamationmark.triangle")
        } description: {
          Text(message)
        } actions: {
          Button("Try again") {
            retryCount += 1
          }
        }
      }
    }
    .searchable(text: $searchText, prompt: "Search bills, renewals, tasks...")
    .overlay(alignment: .bottomTrailing) {
      if capabilities.allowsItemCreation {
        Button {
          if let onEditItem {
            let newItem = LifeItem(id: UUID(), title: "", status: .active)
            onEditItem(newItem)
          }
        } label: {
          Image(systemName: "plus")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(Color(uiColor: .systemBackground))
            .frame(width: 52, height: 52)
            .background(Color(uiColor: .label), in: Circle())
            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityLabel("Quick Capture")
        .accessibilityIdentifier("quickCaptureButton")
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .alert(
      "Action Failed",
      isPresented: Binding(
        get: { viewModel.actionError != nil },
        set: { if !$0 { viewModel.actionError = nil } }
      )
    ) {
      Button("OK", role: .cancel) { viewModel.actionError = nil }
    } message: {
      if let error = viewModel.actionError {
        Text(error)
      }
    }
    .task(id: retryCount) {
      if retryCount == 0 { await viewModel.loadIfNeeded() } else { await viewModel.forceLoad() }
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active && viewModel.isStale { retryCount += 1 }
    }
  }

  // MARK: - List Content by Tab

  @ViewBuilder
  private func listContent(for items: [LifeItem]) -> some View {
    let grouping = TimelineGrouping.group(items: items)

    switch tab {
    case .priority:
      priorityList(grouping: grouping)
    case .timeline:
      timelineList(grouping: grouping)
    case .inbox:
      inboxList(items: items)
    }
  }

  @ViewBuilder
  private func priorityList(grouping: TimelineGrouping) -> some View {
    let priority = PriorityGrouping(from: grouping)

    if priority.isEmpty {
      ContentUnavailableView(
        "Your LifeLoop is peaceful and clear.",
        systemImage: "sparkles",
        description: Text("No items or deadlines require your attention right now.")
      )
    } else {
      List(selection: $selectedItemID) {
        if !priority.carouselItems.isEmpty {
          Section {
            PriorityCarouselView(
              items: priority.carouselItems,
              mutatingItemIDs: viewModel.mutatingItemIDs,
              capabilities: capabilities,
              onComplete: { item in
                Task { await viewModel.completeItem(item) }
              },
              onSnooze: { item in
                Task { await viewModel.snoozeItem(item, days: 1) }
              },
              onEdit: { item in
                if let onEditItem {
                  onEditItem(item)
                } else {
                  selectedItemID = item.id
                }
              },
              onConfirmReview: { item in
                Task { await viewModel.confirmReview(item) }
              }
            )
          }
          .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
          .listRowBackground(Color.clear)
          .listRowSeparator(.hidden)
        }

        if !priority.needsAttention.isEmpty {
          Section {
            ForEach(priority.needsAttention) { item in
              row(for: item)
            }
          } header: {
            HStack(spacing: 6) {
              Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.orange)
              Text("NEEDS ATTENTION (\(priority.needsAttention.count))")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.orange)
            }
            .textCase(nil)
          }
        }

        Section {
          if !priority.today.isEmpty {
            ForEach(priority.today) { item in
              row(for: item)
            }
          } else {
            PrioritySectionEmptyView(
              title: "Nothing due today. You are completely on track!",
              systemImage: "checkmark.circle.fill",
              tint: .green
            )
          }
        } header: {
          HStack(spacing: 6) {
            Image(systemName: "checkmark.circle")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(.red)
            Text("TODAY (\(priority.today.count))")
              .font(.system(size: 11, weight: .bold))
              .tracking(0.5)
              .foregroundStyle(.red)
          }
          .textCase(nil)
        }

        Section {
          if !priority.upcoming.isEmpty {
            ForEach(priority.upcoming) { item in
              row(for: item)
            }
          } else {
            PrioritySectionEmptyView(
              title: "No upcoming deadlines detected yet.",
              systemImage: "calendar",
              tint: .secondary
            )
          }
        } header: {
          HStack(spacing: 6) {
            Image(systemName: "calendar")
              .font(.system(size: 13, weight: .bold))
              .foregroundStyle(.blue)
            Text("UPCOMING (\(priority.upcoming.count))")
              .font(.system(size: 11, weight: .bold))
              .tracking(0.5)
              .foregroundStyle(.blue)
          }
          .textCase(nil)
        }

        if !priority.waitingFor.isEmpty {
          Section {
            ForEach(priority.waitingFor) { item in
              row(for: item)
            }
          } header: {
            HStack(spacing: 6) {
              Image(systemName: "hourglass")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.purple)
              Text("WAITING FOR (\(priority.waitingFor.count))")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(.purple)
            }
            .textCase(nil)
          }
        }

        demoFooter
      }
      .listStyle(.insetGrouped)
      .refreshable { await viewModel.forceLoad() }
      .dialogModifiers(
        itemToDelete: $itemToDelete,
        showDeleteConfirmation: $showDeleteConfirmation,
        itemToSnooze: $itemToSnooze,
        showSnoozeDialog: $showSnoozeDialog,
        viewModel: viewModel
      )
    }
  }


  @ViewBuilder
  private func timelineList(grouping: TimelineGrouping) -> some View {
    List(selection: $selectedItemID) {
      if !grouping.needsAttention.isEmpty {
        Section {
          ForEach(grouping.needsAttention) { item in
            row(for: item)
          }
        } header: {
          Label("Overdue / Attention (\(grouping.needsAttention.count))", systemImage: "exclamationmark.circle.fill")
            .foregroundStyle(.red)
            .font(.caption.bold())
        }
      }

      if !grouping.today.isEmpty {
        Section {
          ForEach(grouping.today) { item in
            row(for: item)
          }
        } header: {
          Label("Today (\(grouping.today.count))", systemImage: "sun.max.fill")
            .foregroundStyle(.orange)
            .font(.caption.bold())
        }
      }

      if !grouping.tomorrow.isEmpty {
        Section {
          ForEach(grouping.tomorrow) { item in
            row(for: item)
          }
        } header: {
          Label("Tomorrow (\(grouping.tomorrow.count))", systemImage: "calendar")
            .foregroundStyle(.blue)
            .font(.caption.bold())
        }
      }

      if !grouping.thisWeek.isEmpty {
        Section {
          ForEach(grouping.thisWeek) { item in
            row(for: item)
          }
        } header: {
          Label("This Week (\(grouping.thisWeek.count))", systemImage: "calendar.badge.clock")
            .foregroundStyle(.indigo)
            .font(.caption.bold())
        }
      }

      if !grouping.upcoming.isEmpty {
        Section {
          ForEach(grouping.upcoming) { item in
            row(for: item)
          }
        } header: {
          Label("Later (\(grouping.upcoming.count))", systemImage: "clock.arrow.circlepath")
            .foregroundStyle(.secondary)
            .font(.caption.bold())
        }
      }

      if !grouping.past.isEmpty {
        Section {
          ForEach(grouping.past) { item in
            row(for: item)
          }
        } header: {
          Label("Completed / History (\(grouping.past.count))", systemImage: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .font(.caption.bold())
        }
      }

      demoFooter
    }
    .listStyle(.insetGrouped)
    .refreshable { await viewModel.forceLoad() }
    .dialogModifiers(
      itemToDelete: $itemToDelete,
      showDeleteConfirmation: $showDeleteConfirmation,
      itemToSnooze: $itemToSnooze,
      showSnoozeDialog: $showSnoozeDialog,
      viewModel: viewModel
    )
  }

  @ViewBuilder
  private func inboxList(items: [LifeItem]) -> some View {
    let pendingItems = items.filter { $0.status == .pendingReview }
    if pendingItems.isEmpty {
      ContentUnavailableView(
        "Inbox",
        systemImage: "tray",
        description: Text("Captures and incoming items will appear here.")
      )
    } else {
      List(selection: $selectedItemID) {
        Section {
          ForEach(pendingItems) { item in
            row(for: item)
          }
        } header: {
          Label("Needs Review (\(pendingItems.count))", systemImage: "sparkles")
            .foregroundStyle(.orange)
            .font(.caption.bold())
        }

        demoFooter
      }
      .listStyle(.insetGrouped)
      .refreshable { await viewModel.forceLoad() }
      .dialogModifiers(
        itemToDelete: $itemToDelete,
        showDeleteConfirmation: $showDeleteConfirmation,
        itemToSnooze: $itemToSnooze,
        showSnoozeDialog: $showSnoozeDialog,
        viewModel: viewModel
      )
    }
  }

  // MARK: - Row Rendering

  @ViewBuilder
  private func row(for item: LifeItem) -> some View {
    Button {
      if let onSelectItem {
        onSelectItem(item)
      } else {
        selectedItemID = item.id
      }
    } label: {
      ItemRowView(
        item: item,
        expanded: tab == .priority ? expandedIDs.contains(item.id) : nil,
        onToggleExpand: tab == .priority ? {
          withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            if expandedIDs.contains(item.id) {
              expandedIDs.remove(item.id)
            } else {
              expandedIDs.insert(item.id)
            }
          }
        } : nil,
        isMutating: viewModel.mutatingItemIDs.contains(item.id),
        onToggleComplete: {
          Task { await viewModel.toggleComplete(for: item) }
        },
        onConfirmReview: item.status == .pendingReview ? {
          Task { await viewModel.confirmReview(item) }
        } : nil,
        onSnooze: capabilities.allowsItemMutations ? { days in
          Task { await viewModel.snoozeItem(item, days: days) }
        } : nil,
        onEdit: capabilities.allowsItemMutations ? {
          if let onEditItem {
            onEditItem(item)
          } else if let onSelectItem {
            onSelectItem(item)
          } else {
            selectedItemID = item.id
          }
        } : nil,
        onDelete: capabilities.allowsItemMutations ? {
          itemToDelete = item
          showDeleteConfirmation = true
        } : nil
      )
    }
    .buttonStyle(.plain)
    .tag(item.id)
    .accessibilityIdentifier("item-\(item.id.uuidString)")
    .accessibilityLabel(item.title)
    .frame(maxWidth: .infinity)
    .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
    .swipeActions(edge: .leading) {
      if capabilities.allowsItemMutations {
        if item.status == .pendingReview {
          Button {
            Task { await viewModel.confirmReview(item) }
          } label: {
            Label("Confirm", systemImage: "sparkles")
          }
          .tint(.orange)
        }
        if item.status == .completed {
          Button {
            Task { await viewModel.reopenItem(item) }
          } label: {
            Label("Reopen", systemImage: "arrow.uturn.backward")
          }
          .tint(.blue)
        } else {
          Button {
            Task { await viewModel.completeItem(item) }
          } label: {
            Label("Complete", systemImage: "checkmark")
          }
          .tint(.green)
        }
      }
    }

    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      if capabilities.allowsItemMutations {
        Button(role: .destructive) {
          itemToDelete = item
          showDeleteConfirmation = true
        } label: {
          Label("Delete", systemImage: "trash")
        }
        Button {
          itemToSnooze = item
          showSnoozeDialog = true
        } label: {
          Label("Snooze", systemImage: "clock.arrow.circlepath")
        }
        .tint(.yellow)
      }
    }
    .contextMenu {
      if capabilities.allowsItemMutations {
        if item.status == .pendingReview {
          Button {
            Task { await viewModel.confirmReview(item) }
          } label: {
            Label("Confirm AI", systemImage: "sparkles")
          }
        }

        if item.status == .completed {
          Button {
            Task { await viewModel.reopenItem(item) }
          } label: {
            Label("Reopen", systemImage: "arrow.uturn.backward")
          }
        } else {
          Button {
            Task { await viewModel.completeItem(item) }
          } label: {
            Label("Complete", systemImage: "checkmark")
          }
        }

        Button {
          itemToSnooze = item
          showSnoozeDialog = true
        } label: {
          Label("Snooze", systemImage: "clock.arrow.circlepath")
        }

        Divider()

        Button(role: .destructive) {
          itemToDelete = item
          showDeleteConfirmation = true
        } label: {
          Label("Delete", systemImage: "trash")
        }
      }
    }
  }

  @ViewBuilder
  private var demoFooter: some View {
    if capabilities.isDemo {
      Section {
      } footer: {
        Text("Demo items reset on restart · Unsaved drafts are kept")
          .font(.caption2)
          .foregroundStyle(.tertiary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 4)
      }
    }
  }

  private func filterItems(_ items: [LifeItem]) -> [LifeItem] {
    guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
      return items
    }
    let query = searchText.lowercased()
    return items.filter { item in
      item.title.lowercased().contains(query)
        || item.itemType.lowercased().contains(query)
    }
  }
}

// MARK: - Dialog Modifiers Helper

private extension View {
  func dialogModifiers(
    itemToDelete: Binding<LifeItem?>,
    showDeleteConfirmation: Binding<Bool>,
    itemToSnooze: Binding<LifeItem?>,
    showSnoozeDialog: Binding<Bool>,
    viewModel: ItemsListViewModel
  ) -> some View {
    self
      .confirmationDialog(
        "Delete item?",
        isPresented: showDeleteConfirmation,
        presenting: itemToDelete.wrappedValue
      ) { item in
        Button("Delete \"\(item.title)\"", role: .destructive) {
          Task { await viewModel.deleteItem(item) }
        }
        Button("Cancel", role: .cancel) {}
      } message: { _ in
        Text("This item will be permanently removed.")
      }
      .confirmationDialog(
        "Snooze Item",
        isPresented: showSnoozeDialog,
        titleVisibility: .visible,
        presenting: itemToSnooze.wrappedValue
      ) { item in
        Button("Tomorrow (+1 Day)") { Task { await viewModel.snoozeItem(item, days: 1) } }
        Button("+3 Days") { Task { await viewModel.snoozeItem(item, days: 3) } }
        Button("Next Week (+7 Days)") { Task { await viewModel.snoozeItem(item, days: 7) } }
        Button("Cancel", role: .cancel) {}
      }
  }
}
