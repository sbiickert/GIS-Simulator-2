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

    private var availableDefs: [(String, WorkflowDef)] {
        let existing = Set(design.workflowDefinitions.map(\.name))
        return library.workflowDefinitions
            .sorted(by: { $0.key < $1.key })
            .filter { !existing.contains($0.key) }
    }

    var body: some View {
        List {
            Section {
                if availableDefs.isEmpty {
                    Text("All workflow definitions have been added")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableDefs, id: \.0) { _, def in
                        Button {
                            toggle(def.name)
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
                                if selected.contains(def.name) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            } header: {
                Text(availableDefs.isEmpty ? "" : "Select workflow definitions to add")
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

    private func toggle(_ name: String) {
        if selected.contains(name) {
            selected.remove(name)
        } else {
            selected.insert(name)
        }
    }

    private func commit() {
        for (_, def) in availableDefs where selected.contains(def.name) {
            modelContext.insert(def)
            for chain in def.chains {
                modelContext.insert(chain)
            }
        }
        try? modelContext.save()
        for (_, def) in availableDefs where selected.contains(def.name) {
            design.workflowDefinitions.append(def)
        }
        try? modelContext.save()
        dismiss()
    }
}
