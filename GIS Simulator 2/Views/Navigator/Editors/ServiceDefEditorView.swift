//
//  ServiceDefEditorView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI
import SwiftData

/// Creates or edits a custom `ServiceDef` stored on the design. Predefined
/// library services are read-only and reach this editor only via `duplicating`
/// (which prefills an independent copy with a unique service type).
struct ServiceDefEditorView: View {
    @Bindable var design: Design
    /// The custom item being edited, or `nil` when creating/duplicating.
    var editing: ServiceDef?
    /// A source item to prefill an independent copy from.
    var duplicating: ServiceDef?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var serviceType = ""
    @State private var desc = ""
    @State private var balancingModel: BalancingModel = .single
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    private var isEditingCustom: Bool { editing != nil }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Service type", text: $serviceType)
                TextField("Description", text: $desc)
                Picker("Balancing", selection: $balancingModel) {
                    ForEach(BalancingModel.allCases, id: \.self) { model in
                        Text(model.rawValue).tag(model)
                    }
                }
            }
            if isEditingCustom {
                Section {
                    Button("Delete Service", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this service definition?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("If it is in use, it will also be removed from the design and its providers updated.")
        }
        .navigationTitle(isEditingCustom ? "Edit Service" : "New Service")
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
        if let def = editing {
            name = def.name
            serviceType = def.serviceType
            desc = def.desc
            balancingModel = def.balancingModel
        } else if let src = duplicating {
            let existing = Set(design.serviceCatalog(library).map(\.key))
            name = "\(src.name) copy"
            serviceType = design.uniqueCopyName(base: src.serviceType, existingKeys: existing)
            desc = src.desc
            balancingModel = src.balancingModel
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedType = serviceType.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            errorMessage = "Service name is required."
            return
        }
        guard !trimmedType.isEmpty else {
            errorMessage = "Service type is required."
            return
        }
        // The service type (key) must be unique across predefined + custom.
        var existing = Set(design.serviceCatalog(library).map(\.key))
        if let editing { existing.remove(editing.serviceType) }
        guard !existing.contains(trimmedType) else {
            errorMessage = "A service of type \"\(trimmedType)\" already exists."
            return
        }

        if let editing, editing.serviceType != trimmedType {
            design.removeCustomServiceDef(key: editing.serviceType)
        }
        design.upsertCustomServiceDef(
            ServiceDef(name: trimmedName, desc: desc, serviceType: trimmedType, balancingModel: balancingModel)
        )
        if editing == nil {
            design.addFavorite(trimmedType, in: \.favoriteServices)
        }
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let editing else { return }
        design.removeCustomServiceDef(key: editing.serviceType)
        try? modelContext.save()
        dismiss()
    }
}
