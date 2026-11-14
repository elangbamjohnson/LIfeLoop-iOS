//
//  ItemDetailView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

struct ItemDetailView: View {
    let item: LifeItem

    var body: some View {
        Form {
            Section("Item") {
                ItemRowView(item: item)
            }
        }
        .navigationTitle("Item details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ItemDetailView(
            item: LifeItem(
                id: UUID(),
                title: "Pay electricity bill",
                status: .active
            )
        )
    }
}
