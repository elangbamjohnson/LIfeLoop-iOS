//
//  ItemsListView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

struct ItemsListView: View {
    let items: [LifeItem]

    var body: some View {
        List(items) { item in
            ItemRowView(item: item)
        }
    }
}

#Preview("Sample items") {
    ItemsListView(items: SampleItems.all)
}

#Preview("Empty list") {
    ItemsListView(items: [])
}
