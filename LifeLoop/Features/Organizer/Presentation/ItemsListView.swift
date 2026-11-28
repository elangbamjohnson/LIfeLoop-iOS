//
//  ItemsListView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation
import SwiftUI
import UIKit

struct ItemsListView: View {
  let viewModel: ItemsListViewModel
  var captureViewModel: CaptureViewModel? = nil
  var tab: OrganizerTab = .priority
  var capabilities: OrganizerCapabilities = .demo
  var onEditItem: ((LifeItem) -> Void)? = nil
  var onSelectItem: ((LifeItem) -> Void)? = nil
  var onCreateItem: (() -> Void)? = nil

  var allowsEditing: Bool {
    get { capabilities.allowsItemMutations }
    set { capabilities = OrganizerCapabilities(allowsEditing: newValue) }
  }

  @Binding var selectedItemID: UUID?
  @State private var retryCount = 0
  @State private var itemToDelete: LifeItem?
  @State private var showDeleteConfirmation = false
  @State private var captureToDelete: Capture?
  @State private var showDeleteCaptureConfirmation = false
  @State private var itemToSnooze: LifeItem?
  @State private var showSnoozeDialog = false
  @State private var searchText = ""
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var expandedIDs: Set<UUID> = []

  var body: some View {
    Group {
      if tab == .inbox {
        inboxView
      } else {
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
    }
    .searchable(text: $searchText, prompt: "Search bills, renewals, tasks...")
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .bottomTrailing) {
      if capabilities.allowsItemCreation {
        Button {
          onCreateItem?()
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
    .alert(
      "Action Failed",
      isPresented: Binding(
        get: { viewModel.actionError != nil || captureViewModel?.actionError != nil },
        set: {
          if !$0 {
            viewModel.actionError = nil
            captureViewModel?.actionError = nil
          }
        }
      )
    ) {
      Button("OK", role: .cancel) {
        viewModel.actionError = nil
        captureViewModel?.actionError = nil
      }
    } message: {
      if let error = viewModel.actionError ?? captureViewModel?.actionError {
        Text(error)
      }
    }
    .task(id: retryCount) {
      if retryCount == 0 { await viewModel.loadIfNeeded() } else { await viewModel.forceLoad() }
    }
    .onChange(of: scenePhase) { _, newPhase in
      viewModel.setForegroundActive(newPhase == .active)
      if newPhase == .active {
        viewModel.refreshReferenceDate()
        if viewModel.isStale { retryCount += 1 }
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
      viewModel.refreshReferenceDate()
    }
  }

  // MARK: - List Content by Tab

  @ViewBuilder
  private func listContent(for items: [LifeItem]) -> some View {
    let grouping = TimelineGrouping.group(items: items, referenceDate: viewModel.referenceDate)

    switch tab {
    case .priority:
      priorityList(grouping: grouping)
    case .timeline:
      timelineList(grouping: grouping)
    case .inbox:
      inboxView
    }
  }

  @ViewBuilder
  private func priorityList(grouping: TimelineGrouping) -> some View {
    let priority = PriorityGrouping(from: grouping)
    let hasAnyCaptures = !(captureViewModel?.captures.isEmpty ?? true)

    if priority.isEmpty && grouping.past.isEmpty && !hasAnyCaptures {
      ContentUnavailableView(
        "Your LifeLoop is peaceful and clear.",
        systemImage: "sparkles",
        description: Text("No items or deadlines require your attention right now.")
      )
    } else {
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          if !priority.carouselItems.isEmpty {
            Section {
              PriorityCarouselView(
                items: priority.carouselItems,
                mutatingItemIDs: viewModel.mutatingItemIDs,
                capabilities: capabilities,
                referenceDate: viewModel.referenceDate,
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
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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
              .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 20)
              .padding(.top, 28)
              .padding(.bottom, 10)
              .accessibilityAddTraits(.isHeader)
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
              .padding(.horizontal, 14)
              .padding(.vertical, 5)
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
            .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 20)
            .padding(.top, 24)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
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
              .padding(.horizontal, 14)
              .padding(.vertical, 5)
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
            .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 20)
            .padding(.top, 24)
            .padding(.bottom, 10)
            .accessibilityAddTraits(.isHeader)
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
              .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 20)
              .padding(.top, 24)
              .padding(.bottom, 10)
              .accessibilityAddTraits(.isHeader)
            }
          }

          demoFooter
            .padding(.horizontal, 14)
            .padding(.top, 24)
        }
        .padding(.horizontal, horizontalSizeClass == .regular ? 16 : 20)
        .padding(.bottom, 20)
      }
      .background(Color(uiColor: .systemGroupedBackground))
      .accessibilityIdentifier("priorityScrollView")
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
  private var inboxView: some View {
    let allItems: [LifeItem] = {
      if case .loaded(let all) = viewModel.state {
        return filterItems(all)
      }
      return []
    }()
    let pendingItems = allItems.filter { $0.status == .pendingReview }
    let captures = captureViewModel?.captures ?? []
    let captureError = captureViewModel?.errorMessage
    let awaitingHistory = captureViewModel != nil
      && captureViewModel?.lastLoadedAt == nil && captureError == nil
    let itemError: String? = {
      if case .failed(let message) = viewModel.state { return message }
      return viewModel.refreshError
    }()
    let itemsLoading: Bool = {
      switch viewModel.state {
      case .idle, .loading: return true
      default: return false
      }
    }()

    List(selection: $selectedItemID) {
      if awaitingHistory {
        ProgressView("Loading captures…")
      }
      if let captureError {
        Section {
          Text(captureError).foregroundStyle(.secondary)
          Button("Retry captures") { Task { await refreshInbox() } }
            .accessibilityIdentifier("retryCaptureHistory")
        } header: {
          Text("Unable to refresh captures")
        }
      }
      if let itemError {
        Section {
          Text(itemError).foregroundStyle(.secondary)
          Button("Retry items") { Task { await viewModel.refreshAfterCapture() } }
        } header: {
          Text("Unable to refresh items")
        }
      }
      if !captures.isEmpty {
        Section {
          ForEach(captures) { capture in
            let linkedItems = allItems.filter { $0.captureId == capture.id }
            CaptureHistoryRowView(
              capture: capture,
              associatedItems: linkedItems,
              isMutating: captureViewModel?.mutatingCaptureIDs.contains(capture.id) ?? false,
              mutatingItemIDs: viewModel.mutatingItemIDs,
              allowsMutations: capabilities.allowsItemMutations,
              onConfirmItem: { item in
                Task { await viewModel.confirmReview(item) }
              },
              onEditItem: { item in
                if let onEditItem {
                  onEditItem(item)
                } else if let onSelectItem {
                  onSelectItem(item)
                } else {
                  selectedItemID = item.id
                }
              },
              onRetry: {
                Task { await captureViewModel?.retryCapture(capture) }
              },
              onDelete: {
                captureToDelete = capture
                showDeleteCaptureConfirmation = true
              }
            )
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              if capabilities.allowsItemMutations {
                Button(role: .destructive) {
                  captureToDelete = capture
                  showDeleteCaptureConfirmation = true
                } label: {
                  Label("Delete", systemImage: "trash")
                }
              }
            }
          }
        } header: {
          Label("Recent Captures (\(captures.count))", systemImage: "tray.and.arrow.down")
            .foregroundStyle(.blue)
            .font(.caption.bold())
        }
      }
      if !pendingItems.isEmpty {
        Section {
          ForEach(pendingItems) { item in row(for: item) }
        } header: {
          Label("Needs Review (\(pendingItems.count))", systemImage: "sparkles")
            .foregroundStyle(.orange)
            .font(.caption.bold())
        }
      }
      if itemsLoading {
        ProgressView("Loading review items…")
      }
      if captures.isEmpty && pendingItems.isEmpty && !awaitingHistory
          && !itemsLoading && captureError == nil && itemError == nil {
        ContentUnavailableView(
          "Inbox",
          systemImage: "tray",
          description: Text("Captures and incoming items will appear here.")
        )
      }
      demoFooter
    }
    .listStyle(.insetGrouped)
    .refreshable { await refreshInbox() }
    .alert(
      "Delete this capture?",
      isPresented: $showDeleteCaptureConfirmation,
      presenting: captureToDelete
    ) { capture in
      Button("Delete Capture", role: .destructive) {
        Task { _ = await captureViewModel?.deleteCapture(capture) }
      }
      .accessibilityIdentifier("confirmDeleteCapture")
      Button("Cancel", role: .cancel) {}
    } message: { _ in
      Text("Original raw capture and any items extracted from it will be permanently removed.")
    }
    .dialogModifiers(
      itemToDelete: $itemToDelete,
      showDeleteConfirmation: $showDeleteConfirmation,
      itemToSnooze: $itemToSnooze,
      showSnoozeDialog: $showSnoozeDialog,
      viewModel: viewModel
    )
  }

  private func refreshInbox() async {
    if let captureViewModel {
      await captureViewModel.loadCaptures()
      if !Task.isCancelled { captureViewModel.startPollingIfNeeded() }
    } else {
      await viewModel.refreshAfterCapture()
    }
  }

  // MARK: - Row Rendering

  @ViewBuilder
  private func row(for item: LifeItem) -> some View {
    if tab == .priority {
      priorityRow(for: item)
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
    } else {
      card(for: item)
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
    }
  }

  private func priorityRow(for item: LifeItem) -> some View {
    card(for: item)
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(Color.accentColor.opacity(selectedItemID == item.id ? 0.08 : 0))
          .allowsHitTesting(false)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color.accentColor.opacity(selectedItemID == item.id ? 0.6 : 0), lineWidth: 2)
          .allowsHitTesting(false)
      }
      .accessibilityAddTraits(selectedItemID == item.id ? .isSelected : [])
      .accessibilityActions {
        if capabilities.allowsItemMutations {
          if item.status == .pendingReview {
            Button("Confirm") {
              Task { await viewModel.confirmReview(item) }
            }
          }
          if item.status == .completed {
            Button("Reopen") {
              Task { await viewModel.reopenItem(item) }
            }
          } else {
            Button("Complete") {
              Task { await viewModel.completeItem(item) }
            }
          }
          Button("Snooze") {
            itemToSnooze = item
            showSnoozeDialog = true
          }
          Button("Delete") {
            itemToDelete = item
            showDeleteConfirmation = true
          }
        }
      }
      .id(item.id)
      .tag(item.id)
  }

  @ViewBuilder
  private func card(for item: LifeItem) -> some View {
    let cardView = ItemRowView(
      item: item,
      referenceDate: viewModel.referenceDate,
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
    .id(item.id)
    .tag(item.id)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(item.title)
    .accessibilityIdentifier("item-\(item.id.uuidString)")
    .accessibilityAddTraits(selectedItemID == item.id ? .isSelected : [])
    .frame(maxWidth: .infinity)
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

    if tab == .priority {
      cardView
    } else {
      cardView
        .contentShape(Rectangle())
        .onTapGesture {
          if let onSelectItem {
            onSelectItem(item)
          } else {
            selectedItemID = item.id
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
    LifeItem.filter(items, matching: searchText)
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
