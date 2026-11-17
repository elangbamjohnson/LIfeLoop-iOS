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
    let localStore: AccountLocalStore?
    private let draftBaseRevision: String?
    let onSave: (LifeItem) async throws -> Void

    @State private var draftTitle: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    init(
        item: LifeItem,
        localStore: AccountLocalStore? = nil,
        onSave: @escaping (LifeItem) async throws -> Void
    ) {
        self.item = item
        self.localStore = localStore
        self.onSave = onSave
        do {
            let savedDraft = try localStore?.draft(itemID: item.id)
            self.draftTitle = savedDraft?.title ?? item.title
            self.draftBaseRevision = savedDraft.map { $0.baseRevision } ?? item.updatedAt
            if let savedDraft, savedDraft.baseRevision != item.updatedAt {
                self.errorMessage = "This draft was made before the item changed. Review your draft before continuing."
            }
        } catch {
            self.draftTitle = item.title
            self.draftBaseRevision = item.updatedAt
            self.errorMessage = "The saved draft could not be read."
        }
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
                    do {
                        try localStore?.removeDraft(itemID: item.id)
                        dismiss()
                    } catch { errorMessage = "Could not discard the saved draft. Please try again." }
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
        .interactiveDismissDisabled()
        .onChange(of: draftTitle) { _, title in
            do {
                try localStore?.saveDraft(ItemDraft(title: title, baseRevision: draftBaseRevision), itemID: item.id)
            } catch { errorMessage = "This draft could not be saved on this device." }
        }
    }

    private var trimmedTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() async {
        guard !trimmedTitle.isEmpty, !isSaving else {
            return
        }

        guard draftBaseRevision == item.updatedAt else {
            errorMessage = "The item has changed since this draft was saved. Your draft is retained; saving requires conflict resolution."
            return
        }
        isSaving = true
        errorMessage = nil

        var updatedItem = item
        updatedItem.title = trimmedTitle

        do {
            try await onSave(updatedItem)
            do { try localStore?.removeDraft(itemID: item.id) }
            catch {
                errorMessage = "Changes were saved, but the local draft could not be removed."
                isSaving = false
                return
            }
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
