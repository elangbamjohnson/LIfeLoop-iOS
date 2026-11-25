//
//  CaptureComposerView.swift
//  LifeLoop
//
//  Created by Johnson Elangbam on 22/11/26.
//

import SwiftUI

struct CaptureComposerView: View {
    let onCapture: (String) async throws -> Void
    var onOpenManualCreation: (() -> Void)? = nil

    @State private var text: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    @Environment(\.dismiss) private var dismiss

    private let maxCharacters: Int = 10_000

    private var utf16Count: Int {
        text.utf16.count
    }

    private var isValid: Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && utf16Count <= maxCharacters
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Capture thoughts, tasks, bills, appointments, or deadlines. LifeLoop AI will organize them in the background.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 12)

                        ZStack(alignment: .topLeading) {
                            if text.isEmpty {
                                Text("e.g. Pay electricity bill tomorrow and renew car insurance next month...")
                                    .font(.body)
                                    .foregroundStyle(Color(uiColor: .placeholderText))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .allowsHitTesting(false)
                            }

                            TextEditor(text: $text)
                                .font(.body)
                                .frame(minHeight: 180)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                                .padding(.horizontal)
                                .disabled(isSubmitting)
                                .accessibilityLabel("Quick Capture input")
                                .accessibilityIdentifier("captureTextInput")
                        }

                        // Character Count Indicator
                        HStack {
                            Spacer()
                            Text("\(utf16Count)/\(maxCharacters)")
                                .font(.caption)
                                .foregroundStyle(utf16Count > maxCharacters ? .red : .secondary)
                                .padding(.trailing)
                                .accessibilityLabel("Character count")
                                .accessibilityIdentifier("captureCharacterCount")
                        }

                        if isSubmitting {
                            HStack {
                                Spacer()
                                ProgressView("Saving capture…")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }

                        if let errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                            .padding(.horizontal)
                            .accessibilityIdentifier("captureErrorMessage")
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // Secondary action: Create manually
                        if let onOpenManualCreation {
                            Button {
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                    onOpenManualCreation()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "square.and.pencil")
                                    Text("Create manually")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .padding()
                                .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                                .padding(.horizontal)
                            }
                            .accessibilityLabel("Create manually")
                            .accessibilityIdentifier("openManualCreationButton")
                            .disabled(isSubmitting)
                        }
                    }
                }
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                    .accessibilityIdentifier("cancelCaptureButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Capture") {
                        Task { await submit() }
                    }
                    .font(.body.bold())
                    .disabled(!isValid || isSubmitting)
                    .accessibilityIdentifier("saveCaptureButton")
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    private func submit() async {
        guard isValid, !isSubmitting else { return }
        isSubmitting = true
        errorMessage = nil

        do {
            try await onCapture(text)
            // Clear text only after server acknowledges
            text = ""
            dismiss()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Failed to save capture. Please try again."
            isSubmitting = false
        }
    }
}
