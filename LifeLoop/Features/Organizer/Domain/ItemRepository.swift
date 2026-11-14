//
//  ItemRepository.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 14/11/26.
//

@MainActor
protocol ItemRepository {
    func fetchItems() async throws -> [LifeItem]
}
