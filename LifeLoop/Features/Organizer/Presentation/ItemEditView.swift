//
//  ItemEditView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation
import SwiftUI

struct ItemEditView: View {
    let item: LifeItem
    let onSave: (LifeItem) async throws -> Void

    @State private var draftTitle: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(
        item: LifeItem,
        onSave: @escaping (LifeItem) async throws -> Void
    ) {
        self.item = item
        self.onSave = onSave
        self.draftTitle = item.title
    }

    var body: some View {
        Form {
            Section {
                TextField("Item title", text: $draftTitle, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityLabel("Item title")
                    .accessibilityIdentifier("itemTitleField")
                    .disabled(isSaving)
            } header: {
                Text("Title")
            } footer: {
                Text("A title is required to save this item.")
            }

            if isSaving {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Saving changes…")
                        Spacer()
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Edit item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isSaving)
                .accessibilityIdentifier("cancelItemEdit")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(trimmedTitle.isEmpty || isSaving)
                .accessibilityIdentifier("saveItemEdit")
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private var trimmedTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        guard !trimmedTitle.isEmpty, !isSaving else {
            return
        }

        isSaving = true
        errorMessage = nil

        var updatedItem = item
        updatedItem.title = trimmedTitle

        do {
            try await onSave(updatedItem)
            dismiss()
        } catch {
            isSaving = false
            if error is CancellationError { return }
            if case APIError.conflict = error {
                errorMessage = "This item has changed on the server. Please cancel, refresh, and try editing again."
            } else if let apiError = error as? APIError {
                errorMessage = apiError.errorDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview("Large text editor") {
    NavigationStack {
        ItemEditView(item: SampleItems.all[0], onSave: { _ in })
    }
    .environment(\.dynamicTypeSize, .accessibility5)
}
