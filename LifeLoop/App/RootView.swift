//
//  RootView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import SwiftUI

struct RootView: View {
    var body: some View {
        ItemsListView(items: SampleItems.all)
    }
}

#Preview {
    RootView()
}
