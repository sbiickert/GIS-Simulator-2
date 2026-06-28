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
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    @State private var type: WorkflowType = .user
    @State private var defIndex = 0
    @State private var userCount = 10
    @State private var productivity = 100
    @State private var tph = 100
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                TextField("Description", text: $desc)
                if editing == nil {
                    Picker("Type", selection: $type) {
                        Text("User").tag(WorkflowType.user)
                        Text("Transactional").tag(WorkflowType.transactional)
                    }
                }
                Picker("Definition", selection: $defIndex) {
                    ForEach(Array(design.workflowDefinitions.enumerated()), id: \.offset) { i, def in
                        Text(def.name).tag(i)
                    }
                }
            }
            Section {
                if type == .user {
                    Stepper("Users: \(userCount)", value: $userCount, in: 1...100_000)
                    Stepper("Productivity: \(productivity)", value: $productivity, in: 1...10_000, step: 10)
                } else {
                    Stepper("Transactions/Hour: \(tph)", value: $tph, in: 1...1_000_000, step: 50)
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
        if let wf = editing {
            name = wf.name
            desc = wf.desc
            type = wf.type
            defIndex = design.workflowDefinitions.firstIndex(where: { $0 == wf.definition }) ?? 0
            userCount = wf.userCount
            productivity = wf.productivity
            tph = wf.tph
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Workflow name is required."
            return
        }
        guard !design.workflowDefinitions.isEmpty else {
            errorMessage = "Add workflow definitions before creating workflows."
            return
        }

        let defName = design.workflowDefinitions[defIndex].name

        if let wf = editing {
            wf.name = trimmed
            wf.desc = desc
            wf.userCount = userCount
            wf.productivity = productivity
            wf.tph = tph
        } else {
            guard let wfDef = design.findWorkflowDefinition(named: defName) else {
                errorMessage = "Workflow definition not found."
                return
            }
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

    private func delete() {
        guard let wf = editing else { return }
        design.removeWorkflow(wf)
        try? modelContext.save()
        dismiss()
    }
}
