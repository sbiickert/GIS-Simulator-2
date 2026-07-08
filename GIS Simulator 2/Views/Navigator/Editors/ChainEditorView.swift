//
//  ChainEditorView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI
import SwiftData

/// Creates or edits a custom `WorkflowChain` (an ordered list of steps) stored
/// on the design. Predefined library chains are shown read-only via `viewing`,
/// with a "Duplicate & Edit" button that turns the screen into an editable
/// independent copy.
struct ChainEditorView: View {
    @Bindable var design: Design
    var editing: WorkflowChain?
    var duplicating: WorkflowChain?
    /// A predefined item to display read-only until the user duplicates it.
    var viewing: WorkflowChain?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    @State private var steps: [WorkflowDefStep] = []
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var isEditingCopy = false
    @State private var hasLoaded = false

    private var isEditingCustom: Bool { editing != nil }
    private var isReadOnly: Bool { viewing != nil && !isEditingCopy }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Description", text: $desc)
            }
            .disabled(isReadOnly)
            Section {
                if steps.isEmpty {
                    Text("No steps yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                        VStack(alignment: .leading) {
                            Text(step.name)
                            Text("\(step.serviceType.isEmpty ? "no service" : step.serviceType) · \(step.serviceTime) ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    .deleteDisabled(isReadOnly)
                    .moveDisabled(isReadOnly)
                }
            } header: {
                HStack {
                    Text("Steps")
                    Spacer()
                    if !isReadOnly {
                        NavigationLink {
                            StepChooserView(design: design, steps: $steps)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.tint)
                        }
                        .isDetailLink(false)
                    }
                }
            }
            if isReadOnly {
                Section {
                    Button("Duplicate & Edit") { startEditingCopy() }
                        .frame(maxWidth: .infinity)
                } footer: {
                    Text("Predefined chains can't be changed. Duplicating creates an editable copy.")
                }
            }
            if isEditingCustom {
                Section {
                    Button("Delete Chain", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this chain?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workflow definitions that already include it keep their own copy.")
        }
        .navigationTitle(isEditingCustom ? "Edit Chain" : (isReadOnly ? "Chain Details" : "New Chain"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isReadOnly {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
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
        // onAppear fires again when a pushed picker pops; don't clobber edits.
        guard !hasLoaded else { return }
        hasLoaded = true
        if let chain = editing ?? viewing {
            name = chain.name
            desc = chain.desc
            steps = chain.steps
        } else if let src = duplicating {
            let existing = Set(design.chainCatalog(library).map(\.key))
            name = design.uniqueCopyName(base: src.name, existingKeys: existing)
            desc = src.desc
            steps = src.steps
        }
    }

    /// Switches the read-only view of a predefined item into an editable
    /// independent copy with a unique name; saving creates a new custom entry.
    private func startEditingCopy() {
        guard let src = viewing else { return }
        let existing = Set(design.chainCatalog(library).map(\.key))
        name = design.uniqueCopyName(base: src.name, existingKeys: existing)
        isEditingCopy = true
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Chain name is required."
            return
        }
        var existing = Set(design.chainCatalog(library).map(\.key))
        if let editing { existing.remove(editing.name) }
        guard !existing.contains(trimmed) else {
            errorMessage = "A chain named \"\(trimmed)\" already exists."
            return
        }

        if let chain = editing {
            chain.name = trimmed
            chain.desc = desc
            chain.steps = steps
            try? modelContext.save()
        } else {
            let chain = WorkflowChain(name: trimmed, description: desc, steps: steps, serviceProviders: [:])
            modelContext.insert(chain)
            try? modelContext.save()
            design.addCustomChain(chain)
            design.addFavorite(trimmed, in: \.favoriteChains)
            try? modelContext.save()
        }
        dismiss()
    }

    private func delete() {
        guard let chain = editing else { return }
        design.removeCustomChain(chain)
        modelContext.delete(chain)
        try? modelContext.save()
        dismiss()
    }
}

/// Multi-select picker that appends chosen steps (favorites first) to a chain's
/// ordered step list.
private struct StepChooserView: View {
    @Bindable var design: Design
    @Binding var steps: [WorkflowDefStep]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library

    @State private var selected: Set<String> = []

    private var entries: [CatalogEntry<WorkflowDefStep>] {
        design.stepCatalog(library)
    }

    var body: some View {
        List {
            ForEach(entries, id: \.key) { entry in
                Button {
                    toggle(entry.key)
                } label: {
                    HStack {
                        if entry.isFavorite {
                            Image(systemName: "star.fill").foregroundStyle(.yellow)
                        }
                        VStack(alignment: .leading) {
                            Text(entry.item.name).foregroundStyle(.primary)
                            Text("\(entry.item.serviceType.isEmpty ? "no service" : entry.item.serviceType) · \(entry.item.serviceTime) ms")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if selected.contains(entry.key) {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Add Steps")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") { commit() }
            }
        }
    }

    private func toggle(_ key: String) {
        if selected.contains(key) {
            selected.remove(key)
        } else {
            selected.insert(key)
        }
    }

    private func commit() {
        for entry in entries where selected.contains(entry.key) {
            steps.append(entry.item)
        }
        dismiss()
    }
}
