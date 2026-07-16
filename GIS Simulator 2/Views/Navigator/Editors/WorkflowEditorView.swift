//
//  WorkflowEditorView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct WorkflowEditorView: View {
    @Bindable var design: Design
    var editing: Workflow?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    @State private var type: WorkflowType = .user
    @State private var defKey = ""
    @State private var userCount = 10
    @State private var productivity = 6
    @State private var tph = 5000
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var hasLoaded = false

    /// Predefined ∪ custom definitions, favorites first. Rows are keyed by
    /// `libraryKey` (the definition name) rather than array index because
    /// SwiftData to-many arrays are not order-stable.
    private var catalogEntries: [CatalogEntry<WorkflowDef>] {
        design.workflowDefCatalog(library)
    }

    private var selectedEntry: CatalogEntry<WorkflowDef>? {
        catalogEntries.first { $0.key == defKey }
    }

    /// Mirrors `Workflow.transactionRate` for the current form values so the
    /// rate updates live as the user adjusts the steppers.
    private var transactionRate: Int {
        switch type {
        case .user:
            return userCount * productivity * 60
        case .transactional:
            return tph
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Description", text: $desc)
                Picker("Type", selection: $type) {
                    Text("User").tag(WorkflowType.user)
                    Text("Transactional").tag(WorkflowType.transactional)
                }
            }
            Section {
                Picker("Definition", selection: $defKey) {
                    ForEach(catalogEntries, id: \.key) { entry in
                        Text(entry.isCustom ? entry.item.name : "\(entry.item.name) (predefined)")
                            .tag(entry.key)
                    }
                }
                if let entry = selectedEntry {
                    NavigationLink {
                        if entry.isCustom {
                            WorkflowDefEditorView(design: design, editing: entry.item)
                        } else {
                            WorkflowDefEditorView(design: design, viewing: entry.item)
                        }
                    } label: {
                        Label("Definition Details", systemImage: "flowchart")
                    }
                    .isDetailLink(false)
                }
            } footer: {
                if selectedEntry?.isCustom == false {
                    Text("Saving will add an editable copy of this predefined definition to the design.")
                }
            }
            Section {
                if type == .user {
                    Stepper("Users: \(userCount)", value: $userCount, in: 1...100_000)
                    Stepper(value: $productivity, in: 1...10) {
                        VStack(alignment: .leading) {
                            Text("Productivity: \(productivity)")
                            Text("transactions per user per minute")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Stepper("Transactions/Hour: \(tph)", value: $tph, in: 1...1_000_000, step: 500)
                }
                LabeledContent("Transaction rate") {
                    Text("\(transactionRate.formatted()) transactions/hour")
                }
            }
            if editing != nil {
                Section {
                    Button("Delete Workflow", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this workflow?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
        .navigationTitle(editing == nil ? "New Workflow" : "Edit Workflow")
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
        // onAppear fires again when a pushed view pops; don't clobber edits,
        // but re-validate the selection in case the definition was renamed or
        // deleted in the drill-down.
        guard !hasLoaded else {
            if selectedEntry == nil {
                defKey = editing?.definition.libraryKey ?? catalogEntries.first?.key ?? ""
            }
            return
        }
        hasLoaded = true
        if let wf = editing {
            name = wf.name
            desc = wf.desc
            type = wf.type
            defKey = wf.definition.libraryKey
            userCount = wf.userCount
            productivity = wf.productivity
            tph = wf.tph
        } else {
            defKey = catalogEntries.first?.key ?? ""
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Workflow name is required."
            return
        }
        guard let entry = selectedEntry else {
            errorMessage = "Select a workflow definition."
            return
        }
        let wfDef = designDefinition(for: entry)

        if let wf = editing {
            wf.name = trimmed
            wf.desc = desc
            wf.type = type
            wf.definition = wfDef
            wf.userCount = userCount
            wf.productivity = productivity
            wf.tph = tph
            try? modelContext.save()
        } else {
            let wf: Workflow
            switch type {
            case .user:
                wf = Workflow(name: trimmed, desc: desc, definition: wfDef, type: .user, userCount: userCount, productivity: productivity)
            case .transactional:
                wf = Workflow(name: trimmed, desc: desc, definition: wfDef, type: .transactional, tph: tph)
            }
            modelContext.insert(wf)
            try? modelContext.save()
            design.workflows.append(wf)
            try? modelContext.save()
        }
        dismiss()
    }

    /// Returns a design-owned definition for the chosen catalog entry. A custom
    /// entry is used as-is; a predefined entry is copied into the design (with
    /// fresh chain copies) the same way the library's Duplicate action does, so
    /// the workflow always references a definition the user can assign
    /// service providers to.
    private func designDefinition(for entry: CatalogEntry<WorkflowDef>) -> WorkflowDef {
        if entry.isCustom { return entry.item }
        let src = entry.item
        let chainCopies = src.chains.map {
            WorkflowChain(name: $0.name, description: $0.desc, steps: $0.steps, serviceProviders: [:])
        }
        for chain in chainCopies { modelContext.insert(chain) }
        let copy = WorkflowDef(name: src.name, desc: src.desc, thinkTimeSeconds: src.thinkTimeSeconds, chains: chainCopies)
        modelContext.insert(copy)
        try? modelContext.save()
        design.workflowDefinitions.append(copy)
        design.addFavorite(copy.name, in: \.favoriteWorkflowDefs)
        try? modelContext.save()
        return copy
    }

    private func delete() {
        guard let wf = editing else { return }
        design.removeWorkflow(wf)
        try? modelContext.save()
        dismiss()
    }
}
