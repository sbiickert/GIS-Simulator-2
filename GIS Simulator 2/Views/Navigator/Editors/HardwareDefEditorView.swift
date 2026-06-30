//
//  HardwareDefEditorView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI
import SwiftData

/// Creates or edits a custom `HardwareDef` stored on the design. Predefined
/// library hardware is read-only and reaches this editor only via `duplicating`
/// (which prefills an independent copy with a unique name).
struct HardwareDefEditorView: View {
    @Bindable var design: Design
    /// The custom item being edited, or `nil` when creating/duplicating.
    var editing: HardwareDef?
    /// A source item to prefill an independent copy from.
    var duplicating: HardwareDef?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    @State private var processor = ""
    @State private var cores = 8
    @State private var spec = 100.0
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    private var isEditingCustom: Bool { editing != nil }

    var body: some View {
        Form {
            Section {
                TextField("Processor", text: $processor)
                Stepper("Cores: \(cores)", value: $cores, in: 1...1024)
                LabeledContent("SPECint rate 2017") {
                    TextField("SPEC", value: $spec, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.decimalPad)
                }
            }
            if isEditingCustom {
                Section {
                    Button("Delete Hardware", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this hardware definition?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Compute nodes already using it keep their own copy.")
        }
        .navigationTitle(isEditingCustom ? "Edit Hardware" : "New Hardware")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear(perform: loadInitial)
    }

    private func loadInitial() {
        if let hw = editing {
            processor = hw.processor
            cores = hw.cores
            spec = hw.specIntRate2017
        } else if let src = duplicating {
            let existing = Set(design.hardwareCatalog(library).map(\.key))
            processor = design.uniqueCopyName(base: src.processor, existingKeys: existing)
            cores = src.cores
            spec = src.specIntRate2017
        }
    }

    private func save() {
        let trimmed = processor.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Processor name is required."
            return
        }
        // The key must be unique across predefined + custom (except this item's own).
        var existing = Set(design.hardwareCatalog(library).map(\.key))
        if let editing { existing.remove(editing.processor) }
        guard !existing.contains(trimmed) else {
            errorMessage = "A hardware definition named \"\(trimmed)\" already exists."
            return
        }

        // If a rename changed the key, drop the old custom entry first.
        if let editing, editing.processor != trimmed {
            design.removeCustomHardware(key: editing.processor)
        }
        design.upsertCustomHardware(HardwareDef(processor: trimmed, cores: cores, specIntRate2017: spec))
        if editing == nil {
            design.addFavorite(trimmed, in: \.favoriteHardware)
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let editing else { return }
        design.removeCustomHardware(key: editing.processor)
        try? modelContext.save()
        dismiss()
    }
}
