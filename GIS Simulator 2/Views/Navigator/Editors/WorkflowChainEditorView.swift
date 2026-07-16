//
//  WorkflowChainEditorView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

/// Edits a single chain owned by a workflow definition: name/description, the
/// ordered step list (tap a step to edit it in place), and the chain's
/// service-provider assignments. Pushed from `WorkflowDefEditorView`.
struct WorkflowChainEditorView: View {
    @Bindable var design: Design
    @Bindable var chain: WorkflowChain

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    /// Working copy of the chain's steps; written back on Save. Steps are value
    /// types, so edits here never affect other chains.
    @State private var steps: [WorkflowDefStep] = []
    @State private var errorMessage: String?
    @State private var hasLoaded = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Description", text: $desc)
            }
            Section {
                if steps.isEmpty {
                    Text("No steps yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(steps.indices, id: \.self) { i in
                        NavigationLink {
                            WorkflowDefStepEditorView(design: design, inPlace: $steps[i])
                        } label: {
                            VStack(alignment: .leading) {
                                Text(steps[i].name)
                                Text("\(steps[i].serviceType.isEmpty ? "no service" : steps[i].serviceType) · \(steps[i].serviceTime) ms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .isDetailLink(false)
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                }
            } header: {
                HStack {
                    Text("Steps")
                    Spacer()
                    NavigationLink {
                        StepChooserView(design: design, steps: $steps)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                    }
                    .isDetailLink(false)
                }
            }
            // Provider assignment needs an inserted chain: setting the
            // relationship on a pending copy would persist it before the
            // definition itself is saved.
            if chain.modelContext != nil {
                Section("Service Providers") {
                    ChainServiceProviderPickers(design: design, chain: chain)
                }
            } else {
                Section("Service Providers") {
                    Text("Save the definition first to assign service providers.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Edit Chain")
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
        // onAppear fires again when a pushed step editor pops; don't clobber edits.
        guard !hasLoaded else { return }
        hasLoaded = true
        name = chain.name
        desc = chain.desc
        steps = chain.steps
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Chain name is required."
            return
        }
        chain.name = trimmed
        chain.desc = desc
        chain.steps = steps
        // A pending (un-inserted) chain is persisted by the definition
        // editor's own Save; saving the context here would be premature.
        if chain.modelContext != nil {
            try? modelContext.save()
        }
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
