//
//  ComputeNodeEditorView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct ComputeNodeEditorView: View {
    @Bindable var design: Design
    var editing: ComputeNode?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    @State private var nodeType: ComputeNodeType = .host
    @State private var hwIndex = 0
    @State private var memoryGB = 64
    @State private var zoneIndex = 0
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    /// Hardware choices, favorites first (then alphabetical), merging the
    /// design's custom hardware with the predefined library.
    private var sortedHardware: [(String, HardwareDef)] {
        design.hardwareCatalog(library).map { ($0.key, $0.item) }
    }

    /// The hardware currently chosen in the picker (may differ from the saved
    /// host until Save), used to keep the allocation stats live.
    private var selectedHardware: HardwareDef? {
        sortedHardware.indices.contains(hwIndex) ? sortedHardware[hwIndex].1 : nil
    }

    private var canShowVMs: Bool {
        editing?.type == .host
    }

    var body: some View {
        Form {
            Section {
                if editing == nil {
                    Picker("Type", selection: $nodeType) {
                        Text("Client").tag(ComputeNodeType.client)
                        Text("Host").tag(ComputeNodeType.host)
                    }
                }
                TextField("Name", text: $name)
                TextField("Description", text: $desc)
                Picker("Hardware", selection: $hwIndex) {
                    ForEach(Array(sortedHardware.enumerated()), id: \.offset) { i, entry in
                        if design.favoriteHardware.contains(entry.0) {
                            Label(entry.0, systemImage: "star.fill").tag(i)
                        } else {
                            Text(entry.0).tag(i)
                        }
                    }
                }
                Stepper("Memory: \(memoryGB) GB", value: $memoryGB, in: 1...4096, step: 8)
                Picker("Zone", selection: $zoneIndex) {
                    ForEach(Array(design.zones.enumerated()), id: \.offset) { i, zone in
                        Text(zone.name).tag(i)
                    }
                }
            }

            if canShowVMs, let host = editing {
                HostAllocationSection(
                    host: host,
                    cores: selectedHardware?.cores ?? host.hwDef.cores,
                    totalMemory: memoryGB
                )

                Section {
                    ForEach(host.vmList, id: \.persistentModelID) { vm in
                        NavigationLink {
                            VMEditorView(design: design, host: host, editing: vm)
                        } label: {
                            VStack(alignment: .leading) {
                                Text(vm.name)
                                Text("\(vm.vCores) vCores, \(vm.memoryGB) GB")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .isDetailLink(false)
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            if let vm = host.vm(at: i) {
                                host.removeVirtualMachine(vm: vm)
                            }
                        }
                        design.updateServiceProviders()
                        design.updateWorkflowDefinitions()
                    }
                } header: {
                    SectionHeader(title: "Virtual Machines") {
                        VMEditorView(design: design, host: host)
                    }
                }
            }
            if editing != nil {
                Section {
                    Button("Delete Compute Node", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this compute node?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(editing?.type == .host ? "Deleting this host also removes its virtual machines." : "")
        }
        .navigationTitle(editing == nil ? "New Compute Node" : "Edit Compute Node")
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
        if let node = editing {
            name = node.name
            desc = node.desc
            nodeType = node.type
            memoryGB = node.memoryGB
            zoneIndex = design.zones.firstIndex(of: node.zone) ?? 0
            hwIndex = sortedHardware.firstIndex(where: { $0.1.processor == node.hwDef.processor }) ?? 0
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Node name is required."
            return
        }
        guard !design.zones.isEmpty else {
            errorMessage = "Add zones before creating compute nodes."
            return
        }
        guard !sortedHardware.isEmpty else {
            errorMessage = "No hardware definitions available."
            return
        }

        let hw = sortedHardware[hwIndex].1
        let zone = design.zones[zoneIndex]

        if let node = editing {
            node.name = trimmed
            node.desc = desc
            node.hwDef = hw
            node.memoryGB = memoryGB
            node.zone = zone
        } else {
            let node = ComputeNode(name: trimmed, desc: desc, hwDef: hw, memoryGB: memoryGB, zone: zone, type: nodeType)
            modelContext.insert(node)
            try? modelContext.save()
            design.physicalComputeNodes.append(node)
            try? modelContext.save()
        }
        dismiss()
    }

    private func delete() {
        guard let node = editing else { return }
        design.removeCompute(node)
        try? modelContext.save()
        dismiss()
    }
}

/// Summarizes how much of a host's CPU and memory has been allocated to its VMs.
/// Updates live as VMs are added or removed.
private struct HostAllocationSection: View {
    let host: ComputeNode
    /// Physical core count of the hardware currently selected in the editor.
    let cores: Int
    /// Host memory (GB) currently selected in the editor.
    let totalMemory: Int

    /// Allocation above this fraction of capacity triggers a warning.
    private let warningThreshold = 0.8

    /// Schedulable vCPU capacity: physical cores scaled up by the host's
    /// threading model (e.g. a 16-core hyperthreaded host offers 32 vCPUs).
    private var totalCores: Int { Int(Double(cores) / host.threading.factor) }
    private var allocatedVCPU: Int { host.totalVirtualCpuAllocation }
    private var availableVCPU: Int { totalCores - allocatedVCPU }
    private var cpuFraction: Double {
        totalCores > 0 ? Double(allocatedVCPU) / Double(totalCores) : 0
    }

    private var allocatedMemory: Int { host.totalMemoryAllocation }
    private var availableMemory: Int { totalMemory - allocatedMemory }
    private var memoryFraction: Double {
        totalMemory > 0 ? Double(allocatedMemory) / Double(totalMemory) : 0
    }

    var body: some View {
        Section {
            LabeledContent("vCPU") {
                Text("\(allocatedVCPU) of \(totalCores) cores")
            }
            LabeledContent("vCPU Available") {
                Text("\(availableVCPU)")
                    .foregroundStyle(availableVCPU < 0 ? .red : .secondary)
            }
            LabeledContent("Memory") {
                Text("\(allocatedMemory) of \(totalMemory) GB")
            }
            LabeledContent("Memory Available") {
                Text("\(availableMemory) GB")
                    .foregroundStyle(availableMemory < 0 ? .red : .secondary)
            }

            if cpuFraction > warningThreshold {
                warningLabel(for: "vCPU", fraction: cpuFraction)
            }
            if memoryFraction > warningThreshold {
                warningLabel(for: "Memory", fraction: memoryFraction)
            }
        } header: {
            Text("Host Allocation")
        }
    }

    @ViewBuilder
    private func warningLabel(for resource: String, fraction: Double) -> some View {
        let pct = Int((fraction * 100).rounded())
        let overAllocated = fraction > 1.0
        Label(
            "\(resource) \(overAllocated ? "over-allocated" : "near capacity") (\(pct)%)",
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.callout)
        .foregroundStyle(overAllocated ? .red : .orange)
    }
}
