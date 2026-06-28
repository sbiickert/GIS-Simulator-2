//
//  WorkflowChainEditorView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct WorkflowChainEditorView: View {
    @Bindable var design: Design
    @Bindable var workflowDef: WorkflowDef

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            ForEach(workflowDef.chains, id: \.persistentModelID) { chain in
                Section("Chain: \(chain.name)") {
                    ChainServiceProviderPickers(design: design, chain: chain)
                }
            }
            Section {
                Button("Delete Workflow Definition", role: .destructive) {
                    showDeleteConfirmation = true
                }
                .frame(maxWidth: .infinity)
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
        .navigationTitle(workflowDef.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func delete() {
        design.removeWorkflowDefinition(workflowDef)
        design.updateConfiguredWorkflows()
        try? modelContext.save()
        dismiss()
    }
}

private struct ChainServiceProviderPickers: View {
    let design: Design
    @Bindable var chain: WorkflowChain

    var body: some View {
        ForEach(Array(chain.allRequiredServiceTypes).sorted(), id: \.self) { serviceType in
            let matching = design.serviceProviders.filter { $0.service.serviceType == serviceType }
            let current = chain.serviceProviders[serviceType]
            let selection = Binding<String>(
                get: { current?.name ?? "" },
                set: { newName in
                    if newName.isEmpty {
                        chain.serviceProviders.removeValue(forKey: serviceType)
                    } else if let sp = matching.first(where: { $0.name == newName }) {
                        chain.serviceProviders[serviceType] = sp
                    }
                }
            )
            Picker(serviceType, selection: selection) {
                Text("(none)").tag("")
                ForEach(matching, id: \.persistentModelID) { sp in
                    Text(sp.name).tag(sp.name)
                }
            }
        }
    }
}
