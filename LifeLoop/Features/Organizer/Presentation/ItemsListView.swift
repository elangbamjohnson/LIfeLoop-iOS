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
  var allowsEditing = true

  @Binding var selectedItemID: UUID?
  @State private var retryCount = 0
  @State private var itemToDelete: LifeItem?
  @State private var showDeleteConfirmation = false
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        ProgressView("Loading items…")

      case .loaded(let items):
        List(items, selection: $selectedItemID) { item in
          NavigationLink(value: item.id) {
            ItemRowView(
              item: item,
              isMutating: viewModel.mutatingItemIDs.contains(item.id)
            )
          }
          .accessibilityIdentifier("item-\(item.id.uuidString)")
          .swipeActions(edge: .leading) {
            if allowsEditing {
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
            if allowsEditing {
              Button(role: .destructive) {
                itemToDelete = item
                showDeleteConfirmation = true
              } label: {
                Label("Delete", systemImage: "trash")
              }
            }
          }
          .contextMenu {
            if allowsEditing {
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
        .refreshable { await viewModel.forceLoad() }
        .confirmationDialog(
          "Delete item?",
          isPresented: $showDeleteConfirmation,
          presenting: itemToDelete
        ) { item in
          Button("Delete \"\(item.title)\"", role: .destructive) {
            Task { await viewModel.deleteItem(item) }
          }
          Button("Cancel", role: .cancel) {}
        } message: { _ in
          Text("This item will be permanently removed.")
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
}
