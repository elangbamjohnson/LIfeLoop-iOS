import Foundation
import SwiftData

@Model
final class LocalRecord {
    @Attribute(.unique) var key: String
    var scope: String
    var payload: Data
    var savedAt: Date

    init(key: String, scope: String, payload: Data, savedAt: Date) {
        self.key = key
        self.scope = scope
        self.payload = payload
        self.savedAt = savedAt
    }
}

struct ItemDraft: Codable, Equatable {
    let title: String
    let baseRevision: String?
    let baseItemRevision: Int?

    init(title: String, baseRevision: String? = nil, baseItemRevision: Int? = nil) {
        self.title = title
        self.baseRevision = baseRevision
        self.baseItemRevision = baseItemRevision
    }

    enum CodingKeys: String, CodingKey {
        case title
        case baseRevision
        case baseItemRevision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.baseRevision = try container.decodeIfPresent(String.self, forKey: .baseRevision)
        self.baseItemRevision = try container.decodeIfPresent(Int.self, forKey: .baseItemRevision)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(baseRevision, forKey: .baseRevision)
        try container.encodeIfPresent(baseItemRevision, forKey: .baseItemRevision)
    }
}

/// Every query includes both the server and account identity. Shared items are never cached here.
@MainActor
final class AccountLocalStore {
    private let context: ModelContext
    private let scope: String
    private var active = true
    private var deletedCaptureIDs: Set<UUID> = []
    private var itemMutationEpoch = 0

    var currentItemMutationEpoch: Int {
        itemMutationEpoch
    }

    func filterActiveCaptureItems(_ items: [LifeItem]) -> [LifeItem] {
        items.filter { item in
            guard let captureId = item.captureId else { return true }
            return !deletedCaptureIDs.contains(captureId)
        }
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        if !inMemory {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                                                        in: .userDomainMask, appropriateFor: nil, create: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return try ModelContainer(for: LocalRecord.self, configurations: ModelConfiguration(
            "LifeLoopLocalV1", isStoredInMemoryOnly: inMemory, cloudKitDatabase: .none
        ))
    }

    init(container: ModelContainer, server: URL, accountID: UUID) {
        context = ModelContext(container)
        context.autosaveEnabled = false
        scope = server.absoluteString + "|" + accountID.uuidString
    }

    func saveItems(_ items: [LifeItem]) throws {
        try write(filterActiveCaptureItems(items), name: "items")
    }

    func updateItem(_ updatedItem: LifeItem) throws {
        if let captureId = updatedItem.captureId, deletedCaptureIDs.contains(captureId) {
            return
        }
        guard let snapshot = try readItems() else { return }
        var items = snapshot.items
        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[index] = updatedItem
            itemMutationEpoch += 1
            try write(items, name: "items")
        }
    }

    func insertItem(_ newItem: LifeItem) throws {
        if let captureId = newItem.captureId, deletedCaptureIDs.contains(captureId) {
            return
        }
        guard let snapshot = try readItems() else {
            itemMutationEpoch += 1
            try saveItems([newItem])
            return
        }
        var items = snapshot.items
        if let index = items.firstIndex(where: { $0.id == newItem.id }) {
            items[index] = newItem
        } else {
            items.insert(newItem, at: 0)
        }
        itemMutationEpoch += 1
        try write(items, name: "items")
    }

    func deleteItem(id: UUID) throws {
        guard let snapshot = try readItems() else { return }
        var items = snapshot.items
        let originalCount = items.count
        items.removeAll(where: { $0.id == id })
        if items.count != originalCount {
            itemMutationEpoch += 1
            try write(items, name: "items")
        }
    }

    func deleteItems(forCaptureID captureID: UUID) throws {
        guard active else { throw CancellationError() }
        deletedCaptureIDs.insert(captureID)
        guard let snapshot = try readItems() else { return }
        var items = snapshot.items
        let originalCount = items.count
        items.removeAll(where: { $0.captureId == captureID })
        if items.count != originalCount {
            try write(items, name: "items")
        }
    }

    func readItems() throws -> (items: [LifeItem], date: Date)? {
        guard let record = try record("items") else { return nil }
        return (try JSONDecoder().decode([LifeItem].self, from: record.payload), record.savedAt)
    }

    func saveDraft(_ draft: ItemDraft, itemID: UUID) throws {
        try write(draft, name: "draft-" + itemID.uuidString)
    }

    func draft(itemID: UUID) throws -> ItemDraft? {
        guard let record = try record("draft-" + itemID.uuidString) else { return nil }
        return try JSONDecoder().decode(ItemDraft.self, from: record.payload)
    }

    func removeDraft(itemID: UUID) throws {
        if let record = try record("draft-" + itemID.uuidString) {
            context.delete(record)
            try save()
        }
    }

    func purgeAndInvalidate() throws {
        active = false // A late request using this store cannot recreate purged data.
        deletedCaptureIDs.removeAll()
        itemMutationEpoch += 1
        let scope = scope
        let records = try context.fetch(FetchDescriptor<LocalRecord>(predicate: #Predicate { $0.scope == scope }))
        for record in records { context.delete(record) }
        try save()
    }

    private func record(_ name: String) throws -> LocalRecord? {
        guard active else { throw CancellationError() }
        let key = scope + "|" + name
        return try context.fetch(FetchDescriptor<LocalRecord>(predicate: #Predicate { $0.key == key })).first
    }

    private func write<T: Encodable>(_ value: T, name: String) throws {
        let data = try JSONEncoder().encode(value)
        if let record = try record(name) {
            record.payload = data
            record.savedAt = Date()
        } else {
            context.insert(LocalRecord(key: scope + "|" + name, scope: scope, payload: data, savedAt: Date()))
        }
        try save()
    }

    private func save() throws {
        do { try context.save() }
        catch { context.rollback(); throw error }
    }
}
