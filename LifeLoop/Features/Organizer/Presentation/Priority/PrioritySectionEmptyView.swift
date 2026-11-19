//
//  PrioritySectionEmptyView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 18/11/26.
//

import SwiftUI

struct PrioritySectionEmptyView: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .green

    var body: some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 14))
                    .foregroundStyle(tint)
            }
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
        )
        .listRowInsets(EdgeInsets(top: 5, leading: 14, bottom: 5, trailing: 14))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
}
