//
//  WorkflowDefStepEditorView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI
import SwiftData

/// Creates or edits a custom `WorkflowDefStep` stored on the design. Predefined
/// library steps are read-only and reach this editor only via `duplicating`.
struct WorkflowDefStepEditorView: View {
    @Bindable var design: Design
    var editing: WorkflowDefStep?
    var duplicating: WorkflowDefStep?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    @State private var serviceType = ""
    @State private var serviceTime = 100
    @State private var chatter = 1
    @State private var requestSizeKB = 0
    @State private var responseSizeKB = 0
    @State private var dataSourceType: DataSourceType = .none
    @State private var cachePercent = 0
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    private var isEditingCustom: Bool { editing != nil }

    /// Service types the step may reference: the design's catalog keys, plus the
    /// step's current value so an existing reference is never silently dropped.
    private var serviceTypeOptions: [String] {
        var keys = Set(design.serviceCatalog(library).map(\.key))
        if !serviceType.isEmpty { keys.insert(serviceType) }
        return keys.sorted()
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Description", text: $desc)
                Picker("Service type", selection: $serviceType) {
                    Text("(none)").tag("")
                    ForEach(serviceTypeOptions, id: \.self) { Text($0).tag($0) }
                }
            }
            Section("Timing & Sizing") {
                Stepper("Service time: \(serviceTime) ms", value: $serviceTime, in: 0...600_000, step: 10)
                Stepper("Chatter: \(chatter)", value: $chatter, in: 1...1_000)
                LabeledContent("Request size (KB)") {
                    TextField("Request", value: $requestSizeKB, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                LabeledContent("Response size (KB)") {
                    TextField("Response", value: $responseSizeKB, format: .number)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            }
            Section("Data") {
                Picker("Data source", selection: $dataSourceType) {
                    ForEach(DataSourceType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Stepper("Cache: \(cachePercent)%", value: $cachePercent, in: 0...100, step: 5)
            }
            if isEditingCustom {
                Section {
                    Button("Delete Step", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this workflow step?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Chains that already include it keep their own copy.")
        }
        .navigationTitle(isEditingCustom ? "Edit Step" : "New Step")
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
        let source = editing ?? duplicating
        guard let step = source else { return }
        if editing != nil {
            name = step.name
        } else {
            let existing = Set(design.stepCatalog(library).map(\.key))
            name = design.uniqueCopyName(base: step.name, existingKeys: existing)
        }
        desc = step.desc
        serviceType = step.serviceType
        serviceTime = step.serviceTime
        chatter = step.chatter
        requestSizeKB = step.requestSizeKB
        responseSizeKB = step.responseSizeKB
        dataSourceType = step.dataSourceType
        cachePercent = step.cachePercent
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Step name is required."
            return
        }
        var existing = Set(design.stepCatalog(library).map(\.key))
        if let editing { existing.remove(editing.name) }
        guard !existing.contains(trimmed) else {
            errorMessage = "A step named \"\(trimmed)\" already exists."
            return
        }

        if let editing, editing.name != trimmed {
            design.removeCustomWorkflowStep(key: editing.name)
        }
        design.upsertCustomWorkflowStep(
            WorkflowDefStep(name: trimmed,
                            desc: desc,
                            serviceType: serviceType,
                            serviceTime: serviceTime,
                            chatter: chatter,
                            requestSizeKB: requestSizeKB,
                            responseSizeKB: responseSizeKB,
                            dataSourceType: dataSourceType,
                            cachePercent: cachePercent)
        )
        if editing == nil {
            design.addFavorite(trimmed, in: \.favoriteSteps)
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let editing else { return }
        design.removeCustomWorkflowStep(key: editing.name)
        try? modelContext.save()
        dismiss()
    }
}
