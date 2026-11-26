//
//  ItemCreateView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 22/11/26.
//

import SwiftUI

struct ItemCreateView: View {
    let onSave: (String, String, Date?) async throws -> Void

    @State private var title: String = ""
    @State private var itemType: String = "task"
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var isSaving: Bool = false
    @State private var errorMessage: String? = nil

    @Environment(\.dismiss) private var dismiss

    private let availableTypes: [(id: String, label: String, icon: String)] = [
        ("task", "Task", "tag"),
        ("bill", "Bill / Financial", "creditcard"),
        ("renewal", "Renewal", "arrow.clockwise"),
        ("subscription", "Subscription", "repeat"),
        ("appointment", "Appointment", "calendar"),
        ("reminder", "Reminder", "bell"),
        ("warranty", "Warranty", "shield.checkerboard"),
        ("waiting_for", "Waiting For", "hourglass"),
        ("document", "Document", "doc.text")
    ]

    var body: some View {
        Form {
            Section {
                TextField("e.g. Pay electricity bill", text: $title, axis: .vertical)
                    .lineLimit(1...3)
                    .disabled(isSaving)
                    .accessibilityLabel("Item title")
                    .accessibilityIdentifier("createItemTitleField")
            } header: {
                Text("Title")
            } footer: {
                Text("A title is required to create an item.")
            }

            Section("Category") {
                Picker("Item Type", selection: $itemType) {
                    ForEach(availableTypes, id: \.id) { type in
                        Label(type.label, systemImage: type.icon).tag(type.id)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isSaving)
                .accessibilityLabel("Item category")
                .accessibilityIdentifier("createItemTypePicker")
            }

            Section("Due Date") {
                Toggle("Set due date", isOn: $hasDueDate)
                    .disabled(isSaving)
                    .accessibilityIdentifier("createItemDueDateToggle")

                if hasDueDate {
                    DatePicker(
                        "Target Date",
                        selection: $dueDate,
                        displayedComponents: [.date]
                    )
                    .datePickerStyle(.graphical)
                    .disabled(isSaving)
                    .accessibilityIdentifier("createItemDatePicker")
                }
            }

            if isSaving {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Creating item…")
                        Spacer()
                    }
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
            }
        }
        .navigationTitle("New Item")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isSaving)
                .accessibilityIdentifier("cancelCreateItem")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                .accessibilityIdentifier("saveCreateItem")
            }
        }
        .interactiveDismissDisabled(isSaving)
    }

    private func save() async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        do {
            try await onSave(trimmed, itemType, hasDueDate ? dueDate : nil)
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Could not create item. Please try again."
            isSaving = false
        }
    }
}
