//
//  ItemEditView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation
import SwiftUI

struct ItemEditView: View {
    @State private var item: LifeItem
    let localStore: AccountLocalStore?
    let onSave: (LifeItem) async throws -> Void
    let onReload: (() async throws -> LifeItem)?

    @State private var draftTitle: String
    @State private var baseRevision: Int?
    @State private var legacyBaseRevision: String?
    @State private var isSaving = false
    @State private var isReloading = false
    @State private var isConflict = false
    @State private var isMissingRevision = false
    @State private var errorMessage: String?
    @State private var isDismissing = false
    @Environment(\.dismiss) private var dismiss

    init(
        item: LifeItem,
        localStore: AccountLocalStore? = nil,
        onSave: @escaping (LifeItem) async throws -> Void,
        onReload: (() async throws -> LifeItem)? = nil
    ) {
        _item = State(initialValue: item)
        self.localStore = localStore
        self.onSave = onSave
        self.onReload = onReload

        var initialTitle = item.title
        var initialRevision = item.revision
        var initialLegacyRev = item.updatedAt
        var initialError: String? = nil
        var conflict = false
        var missingRev = (item.revision == nil || item.revision! <= 0)

        do {
            if let savedDraft = try localStore?.draft(itemID: item.id) {
                initialTitle = savedDraft.title
                if let draftItemRev = savedDraft.baseItemRevision {
                    initialRevision = draftItemRev
                    if let itemRev = item.revision, draftItemRev != itemRev {
                        initialError = "This draft was made before the item changed on the server. You can reload the item or edit your draft before saving."
                        conflict = true
                    }
                } else if let draftLegacyRev = savedDraft.baseRevision {
                    initialLegacyRev = draftLegacyRev
                    if draftLegacyRev != item.updatedAt {
                        initialError = "This draft was made before the item changed. You can reload the item or edit your draft before saving."
                        conflict = true
                    }
                }
            }
        } catch {
            initialError = "The saved draft could not be read."
        }

        if initialRevision == nil || initialRevision! <= 0 {
            missingRev = true
            if initialError == nil {
                initialError = "This item has no valid revision to save. Please reload the latest item from the server."
            }
        }

        _draftTitle = State(initialValue: initialTitle)
        _baseRevision = State(initialValue: initialRevision)
        _legacyBaseRevision = State(initialValue: initialLegacyRev)
        _errorMessage = State(initialValue: initialError)
        _isConflict = State(initialValue: conflict)
        _isMissingRevision = State(initialValue: missingRev)
    }

    var body: some View {
        Form {
            Section {
                TextField("Item title", text: $draftTitle, axis: .vertical)
                    .lineLimit(1...4)
                    .accessibilityLabel("Item title")
                    .accessibilityIdentifier("itemTitleField")
                    .disabled(isSaving || isReloading)
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

            if isReloading {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Reloading latest item…")
                        Spacer()
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)

                    if onReload != nil && (isConflict || isMissingRevision) {
                        Button("Reload latest item") {
                            Task {
                                await reloadItem()
                            }
                        }
                        .disabled(isSaving || isReloading)
                    }
                }
            }
        }
        .navigationTitle("Edit item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isDismissing = true
                    do {
                        try localStore?.removeDraft(itemID: item.id)
                        dismiss()
                    } catch { errorMessage = "Could not discard the saved draft. Please try again." }
                }
                .disabled(isSaving || isReloading)
                .accessibilityIdentifier("cancelItemEdit")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        await save()
                    }
                }
                .disabled(trimmedTitle.isEmpty || isSaving || isReloading)
                .accessibilityIdentifier("saveItemEdit")
            }
        }
        .interactiveDismissDisabled()
        .onChange(of: draftTitle) { _, title in
            guard !isDismissing else { return }
            do {
                try localStore?.saveDraft(
                    ItemDraft(title: title, baseRevision: legacyBaseRevision, baseItemRevision: baseRevision),
                    itemID: item.id
                )
            } catch { errorMessage = "This draft could not be saved on this device." }
        }
    }

    private var trimmedTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func reloadItem() async {
        guard let onReload else { return }
        isReloading = true
        do {
            let reloaded = try await onReload()
            if let rev = reloaded.revision, rev > 0 {
                baseRevision = rev
                legacyBaseRevision = reloaded.updatedAt
                item = reloaded
                isConflict = false
                isMissingRevision = false
                errorMessage = nil
            } else {
                isMissingRevision = true
                errorMessage = "The reloaded item still lacks a valid revision."
            }
        } catch {
            if error is CancellationError { return }
            errorMessage = "Could not reload the item. Please check your connection and try again."
        }
        isReloading = false
    }

    private func save() async {
        guard !trimmedTitle.isEmpty, !isSaving, !isReloading else {
            return
        }

        guard let baseRevision, baseRevision > 0 else {
            isMissingRevision = true
            errorMessage = "This item has no valid revision to save. Please reload the latest item from the server."
            return
        }
        isSaving = true
        errorMessage = nil
        isConflict = false

        var updatedItem = item
        updatedItem.title = trimmedTitle
        updatedItem.revision = baseRevision

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
            if error as? ItemMutationError == .conflict || error as? APIError == .conflict {
                isConflict = true
                errorMessage = "This item was modified elsewhere. Your draft is preserved. Reload the current item to review its latest revision, or continue editing."
            } else if let errorDescription = (error as? LocalizedError)?.errorDescription {
                errorMessage = errorDescription
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
