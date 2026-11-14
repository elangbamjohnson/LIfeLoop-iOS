//
//  SampleItemRepository.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

import Foundation

@MainActor
struct SampleItemRepository: ItemRepository {
    let items: [LifeItem]
    let shouldFail: Bool

    init(items: [LifeItem], shouldFail: Bool = false) {
        self.items = items
        self.shouldFail = shouldFail
    }

    func fetchItems() async throws -> [LifeItem] {
        try await Task.sleep(for: .seconds(1))

        if shouldFail {
            throw SampleError.unavailable
        }

        return items
    }

    private enum SampleError: Error {
        case unavailable
    }
}
