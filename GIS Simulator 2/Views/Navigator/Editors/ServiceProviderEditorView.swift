//
//  ServiceProviderEditorView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct ServiceProviderEditorView: View {
    @Bindable var design: Design
    var editing: ServiceProvider?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    @State private var serviceIndex = 0
    @State private var selectedNodes: Set<PersistentIdentifier> = []
    @State private var tagsText = ""
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    private var sortedServices: [ServiceDef] {
        design.services.values.sorted(by: { $0.serviceType < $1.serviceType })
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Description", text: $desc)
                Picker("Service", selection: $serviceIndex) {
                    ForEach(Array(sortedServices.enumerated()), id: \.offset) { i, def in
                        Text(def.serviceType).tag(i)
                    }
                }
                TextField("Tags (comma separated)", text: $tagsText)
            }
            Section("Nodes") {
                ForEach(design.allComputeNodes, id: \.persistentModelID) { node in
                    Button {
                        toggleNode(node)
                    } label: {
                        HStack {
                            Text("\(node.name) (\(node.type.rawValue) in \(node.zone.name))")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedNodes.contains(node.persistentModelID) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                }
            }
            if editing != nil {
                Section {
                    Button("Delete Service Provider", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this service provider?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
        .navigationTitle(editing == nil ? "New Service Provider" : "Edit Service Provider")
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

    private func toggleNode(_ node: ComputeNode) {
        if selectedNodes.contains(node.persistentModelID) {
            selectedNodes.remove(node.persistentModelID)
        } else {
            selectedNodes.insert(node.persistentModelID)
        }
    }

    private func loadInitial() {
        if let sp = editing {
            name = sp.name
            desc = sp.desc
            serviceIndex = sortedServices.firstIndex(where: { $0.serviceType == sp.service.serviceType }) ?? 0
            tagsText = sp.tags.sorted().joined(separator: ", ")
            selectedNodes = Set(sp.nodes.map { $0.persistentModelID })
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Provider name is required."
            return
        }
        guard !sortedServices.isEmpty else {
            errorMessage = "Add service definitions before creating providers."
            return
        }

        let service = sortedServices[serviceIndex]
        let nodes = design.allComputeNodes.filter { selectedNodes.contains($0.persistentModelID) }
        let tags = Set(
            tagsText.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        )

        if let sp = editing {
            sp.name = trimmed
            sp.desc = desc
            sp.nodes = nodes
            sp.tags = tags
        } else {
            let sp = ServiceProvider(name: trimmed, desc: desc, service: service, nodes: nodes, tags: tags)
            modelContext.insert(sp)
            try? modelContext.save()
            design.serviceProviders.append(sp)
            try? modelContext.save()
        }
        dismiss()
    }

    private func delete() {
        guard let sp = editing else { return }
        design.removeServiceProvider(sp)
        try? modelContext.save()
        dismiss()
    }
}
