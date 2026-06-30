//
//  WorkflowDefPickerView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct WorkflowDefPickerView: View {
    @Bindable var design: Design

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    @State private var selected: Set<String> = []

    /// Workflow definitions not yet added to the design, favorites first.
    private var availableEntries: [CatalogEntry<WorkflowDef>] {
        let existing = Set(design.workflowDefinitions.map(\.name))
        return design.workflowDefCatalog(library).filter { !existing.contains($0.key) }
    }

    private var favoriteEntries: [CatalogEntry<WorkflowDef>] {
        availableEntries.filter(\.isFavorite)
    }

    private var otherEntries: [CatalogEntry<WorkflowDef>] {
        availableEntries.filter { !$0.isFavorite }
    }

    var body: some View {
        List {
            if availableEntries.isEmpty {
                Section {
                    Text("All workflow definitions have been added")
                        .foregroundStyle(.secondary)
                }
            } else {
                if !favoriteEntries.isEmpty {
                    Section("Favorites") {
                        ForEach(favoriteEntries, id: \.key) { row($0) }
                    }
                }
                Section(favoriteEntries.isEmpty ? "Select workflow definitions to add" : "All") {
                    ForEach(otherEntries, id: \.key) { row($0) }
                }
            }
        }
        .navigationTitle("Add Workflow Definition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { commit() }
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: CatalogEntry<WorkflowDef>) -> some View {
        let def = entry.item
        HStack {
            FavoriteButton(isFavorite: entry.isFavorite) { toggleFavorite(entry.key) }
            Button {
                toggle(entry.key)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(def.name)
                            .foregroundStyle(.primary)
                        Text("\(def.chains.count) chains: \(def.chains.map(\.name).joined(separator: ", ")) — think time: \(def.thinkTimeSeconds)s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selected.contains(entry.key) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func toggle(_ name: String) {
        if selected.contains(name) {
            selected.remove(name)
        } else {
            selected.insert(name)
        }
    }

    private func toggleFavorite(_ key: String) {
        design.toggleFavorite(key, in: \.favoriteWorkflowDefs)
        try? modelContext.save()
    }

    private func commit() {
        let toAdd = availableEntries.filter { selected.contains($0.key) }
        for entry in toAdd {
            modelContext.insert(entry.item)
            for chain in entry.item.chains {
                modelContext.insert(chain)
            }
        }
        try? modelContext.save()
        for entry in toAdd {
            design.workflowDefinitions.append(entry.item)
        }
        try? modelContext.save()
        dismiss()
    }
}
