//
//  WorkflowDefEditorView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI
import SwiftData

/// Creates or edits a custom `WorkflowDef` in the design by composing chains
/// from the catalog. Each chain in a definition is an independent copy, so the
/// definition owns its chains (matching how predefined definitions are added).
/// Predefined definitions are shown read-only via `viewing`, with a
/// "Duplicate & Edit" button that turns the screen into an editable copy.
struct WorkflowDefEditorView: View {
    @Bindable var design: Design
    var editing: WorkflowDef?
    /// A predefined item to display read-only until the user duplicates it.
    var viewing: WorkflowDef?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    @State private var thinkTimeSeconds = 10
    /// Working chain list. For a new definition these are fresh, not-yet-inserted
    /// copies; for an edit they start as the definition's existing chains.
    @State private var chains: [WorkflowChain] = []
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var isEditingCopy = false
    @State private var hasLoaded = false

    private var isEditing: Bool { editing != nil }
    private var isReadOnly: Bool { viewing != nil && !isEditingCopy }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Description", text: $desc)
                Stepper("Think time: \(thinkTimeSeconds)s", value: $thinkTimeSeconds, in: 0...3_600)
            }
            .disabled(isReadOnly)
            Section {
                if chains.isEmpty {
                    Text("No chains yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(chains, id: \.persistentModelID) { chain in
                        if isReadOnly {
                            chainLabel(chain)
                        } else {
                            NavigationLink {
                                WorkflowChainEditorView(design: design, chain: chain)
                            } label: {
                                chainLabel(chain)
                            }
                            .isDetailLink(false)
                        }
                    }
                    .onDelete { chains.remove(atOffsets: $0) }
                    .onMove { chains.move(fromOffsets: $0, toOffset: $1) }
                    .deleteDisabled(isReadOnly)
                    .moveDisabled(isReadOnly)
                }
            } header: {
                HStack {
                    Text("Chains")
                    Spacer()
                    if !isReadOnly {
                        NavigationLink {
                            ChainChooserView(design: design, chains: $chains)
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
                    Text("Predefined definitions can't be changed. Duplicating adds an editable copy to the design.")
                }
            }
            if isEditing {
                Section {
                    Button("Delete Definition", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this workflow definition?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Workflows that use this definition will also be removed.")
        }
        .navigationTitle(isEditing ? "Edit Definition" : (isReadOnly ? "Definition Details" : "New Definition"))
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

    private func chainLabel(_ chain: WorkflowChain) -> some View {
        VStack(alignment: .leading) {
            Text(chain.name)
            Text("\(chain.steps.count) steps")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func loadInitial() {
        // onAppear fires again when a pushed picker pops; don't clobber edits.
        guard !hasLoaded else { return }
        hasLoaded = true
        if let def = editing ?? viewing {
            name = def.name
            desc = def.desc
            thinkTimeSeconds = def.thinkTimeSeconds
            chains = def.chains
        }
    }

    /// Switches the read-only view of a predefined definition into an editable
    /// copy. The chains are replaced with fresh, not-yet-inserted copies so the
    /// library's own chain objects are never inserted into the design. Naming
    /// matches the list's Duplicate action: keep the predefined name on first
    /// copy, otherwise pick a unique one.
    private func startEditingCopy() {
        guard let src = viewing else { return }
        let designNames = Set(design.workflowDefinitions.map(\.name))
        let allKeys = Set(design.workflowDefCatalog(library).map(\.key))
        name = designNames.contains(src.name)
            ? design.uniqueCopyName(base: src.name, existingKeys: allKeys)
            : src.name
        chains = src.chains.map {
            WorkflowChain(name: $0.name, description: $0.desc, steps: $0.steps, serviceProviders: [:])
        }
        isEditingCopy = true
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Definition name is required."
            return
        }
        var existing = Set(design.workflowDefinitions.map(\.name))
        if let editing { existing.remove(editing.name) }
        guard !existing.contains(trimmed) else {
            errorMessage = "A workflow definition named \"\(trimmed)\" already exists."
            return
        }

        if let def = editing {
            // Reconcile chain membership: insert newly added copies, delete removed ones.
            let oldChains = Set(def.chains)
            let newChains = Set(chains)
            for chain in chains where !oldChains.contains(chain) {
                modelContext.insert(chain)
            }
            for chain in def.chains where !newChains.contains(chain) {
                modelContext.delete(chain)
            }
            def.name = trimmed
            def.desc = desc
            def.thinkTimeSeconds = thinkTimeSeconds
            def.chains = chains
            try? modelContext.save()
        } else {
            for chain in chains {
                modelContext.insert(chain)
            }
            let def = WorkflowDef(name: trimmed, desc: desc, thinkTimeSeconds: thinkTimeSeconds, chains: chains)
            modelContext.insert(def)
            try? modelContext.save()
            design.workflowDefinitions.append(def)
            design.addFavorite(trimmed, in: \.favoriteWorkflowDefs)
            try? modelContext.save()
        }
        dismiss()
    }

    private func delete() {
        guard let def = editing else { return }
        design.removeWorkflowDefinition(def)
        design.updateConfiguredWorkflows()
        modelContext.delete(def)
        try? modelContext.save()
        dismiss()
    }
}

/// Multi-select picker that appends independent copies of chosen catalog chains
/// (favorites first) to a definition's chain list.
private struct ChainChooserView: View {
    @Bindable var design: Design
    @Binding var chains: [WorkflowChain]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library

    @State private var selected: Set<String> = []

    private var entries: [CatalogEntry<WorkflowChain>] {
        design.chainCatalog(library)
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
                            Text("\(entry.item.steps.count) steps")
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
        .navigationTitle("Add Chains")
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
            let src = entry.item
            chains.append(WorkflowChain(name: src.name, description: src.desc, steps: src.steps, serviceProviders: [:]))
        }
        dismiss()
    }
}
