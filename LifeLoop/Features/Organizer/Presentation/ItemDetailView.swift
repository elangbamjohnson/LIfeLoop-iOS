//
//  ItemDetailView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

struct ItemDetailView: View {
    @State private var item: LifeItem
    @State private var isEditing = false

    let onSave: (LifeItem) -> Void

    init(item: LifeItem, onSave: @escaping (LifeItem) -> Void) {
        self.item = item
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("Item") {
                ItemRowView(item: item)
            }
        }
        .navigationTitle("Item details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                ItemEditView(item: item) { updatedItem in
                    item = updatedItem
                    onSave(updatedItem)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(
            item: LifeItem(
                id: UUID(),
                title: "Pay electricity bill",
                status: .active
            ),
            onSave: { _ in }
        )
    }
}
