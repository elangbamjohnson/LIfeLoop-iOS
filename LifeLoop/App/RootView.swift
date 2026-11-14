//
//  RootView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

struct RootView: View {
    @State private var viewModel: ItemsListViewModel

    init(repository: any ItemRepository) {
        self.viewModel = ItemsListViewModel(repository: repository)
    }

    var body: some View {
        ItemsListView(viewModel: viewModel)
    }
}

#Preview("Sample items") {
    RootView(repository: SampleItemRepository(items: SampleItems.all))
}

#Preview("Empty list") {
    RootView(
        repository: SampleItemRepository(items: [])
    )
}

#Preview("Loading failure") {
    RootView(
        repository: SampleItemRepository(
            items: [],
            shouldFail: true
        )
    )
}
