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
    let onSave: (LifeItem) -> Void

    @State private var draftTitle: String
    @Environment(\.dismiss) private var dismiss

    init(
        item: LifeItem,
        onSave: @escaping (LifeItem) -> Void
    ) {
        self.item = item
        self.onSave = onSave
        self.draftTitle = item.title
    }

    var body: some View {
        Form {
            Section("Title") {
                TextField("Item title", text: $draftTitle)
            }
        }
        .navigationTitle("Edit item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                }
                .disabled(trimmedTitle.isEmpty)
            }
        }
        .interactiveDismissDisabled()
    }

    private var trimmedTitle: String {
        draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        guard !trimmedTitle.isEmpty else {
            return
        }

        var updatedItem = item
        updatedItem.title = trimmedTitle

        onSave(updatedItem)
        dismiss()
    }
}
