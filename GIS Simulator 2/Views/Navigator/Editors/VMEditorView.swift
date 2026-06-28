//
//  VMEditorView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct VMEditorView: View {
    @Bindable var design: Design
    @Bindable var host: ComputeNode
    var editing: ComputeNode?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var vCores = 4
    @State private var memoryGB = 16
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                TextField("Name (optional)", text: $name)
                Stepper("vCores: \(vCores)", value: $vCores, in: 1...256)
                Stepper("Memory: \(memoryGB) GB", value: $memoryGB, in: 1...4096, step: 4)
            }
            if editing != nil {
                Section {
                    Button("Delete VM", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this VM?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
        .navigationTitle(editing == nil ? "New VM" : "Edit VM")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear(perform: loadInitial)
    }

    private func loadInitial() {
        if let vm = editing {
            name = vm.name
            vCores = vm.vCores
            memoryGB = vm.memoryGB
        }
    }

    private func save() {
        if let vm = editing {
            vm.name = name
            vm.memoryGB = memoryGB
        } else {
            let vmName = name.isEmpty ? "\(host.name) VM \(host.vmCount)" : name
            let vm = ComputeNode(name: vmName, desc: "", hwDef: host.hwDef, memoryGB: memoryGB, zone: host.zone, type: .vm)
            vm.vCores = vCores
            modelContext.insert(vm)
            try? modelContext.save()
            host.attachVirtualMachine(vm)
            try? modelContext.save()
        }
        dismiss()
    }

    private func delete() {
        guard let vm = editing else { return }
        host.removeVirtualMachine(vm: vm)
        design.updateServiceProviders()
        design.updateWorkflowDefinitions()
        try? modelContext.save()
        dismiss()
    }
}
