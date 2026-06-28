//
//  DesignDetailView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct DesignDetailView: View {
    @Bindable var design: Design
    @Environment(AppFocus.self) private var focus

    var body: some View {
        Form {
            InfoSection(design: design)
            ZonesSection(design: design)
            NetworkSection(design: design)
            ComputeSection(design: design)
            ServicesSection(design: design)
            ServiceProvidersSection(design: design)
            WorkflowDefsSection(design: design)
            WorkflowsSection(design: design)
            ValidationSection(design: design)
        }
        .navigationTitle(design.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focus.currentDesign = design }
    }
}

// MARK: - Info

private struct InfoSection: View {
    @Bindable var design: Design

    var body: some View {
        Section {
            TextField("Name", text: $design.name)
            TextField("Description", text: $design.desc)
        } header: {
            Text("Info")
                .font(Font.title2.bold())
        }
    }
}

// MARK: - Zones

private struct ZonesSection: View {
    @Bindable var design: Design
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDelete: IndexSet?

    var body: some View {
        Section {
            ForEach(design.zones, id: \.persistentModelID) { zone in
                NavigationLink {
                    ZoneEditorView(design: design, editing: zone)
                } label: {
                    VStack(alignment: .leading) {
                        Text(zone.name)
                        Text(zone.desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .isDetailLink(false)
            }
            .onDelete { pendingDelete = $0 }
        } header: {
            SectionHeader(title: "Zones") {
                ZoneEditorView(design: design)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.count ?? 0) zone(s)?",
            isPresented: deletionBinding,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { confirmDelete() }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Network connections and compute nodes in these zones will also be removed.")
        }
    }

    private var deletionBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func confirmDelete() {
        guard let offsets = pendingDelete else { return }
        let targets = offsets.map { design.zones[$0] }
        targets.forEach { design.removeZone($0) }
        try? modelContext.save()
        pendingDelete = nil
    }
}

// MARK: - Network

private struct NetworkSection: View {
    @Bindable var design: Design
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDelete: IndexSet?

    var body: some View {
        Section {
            ForEach(design.network, id: \.persistentModelID) { conn in
                NavigationLink {
                    ConnectionEditorView(design: design, editing: conn)
                } label: {
                    VStack(alignment: .leading) {
                        Text(conn.name)
                        Text("\(conn.bandwidthMbps) Mbps, \(conn.latencyMs) ms latency")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .isDetailLink(false)
            }
            .onDelete { pendingDelete = $0 }
        } header: {
            SectionHeader(title: "Network") {
                ConnectionEditorView(design: design)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.count ?? 0) connection(s)?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let offsets = pendingDelete {
                    let targets = offsets.map { design.network[$0] }
                    targets.forEach { design.removeConnection($0) }
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }
}

// MARK: - Compute

private struct ComputeSection: View {
    @Bindable var design: Design
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDelete: IndexSet?

    var body: some View {
        Section {
            ForEach(design.physicalComputeNodes, id: \.persistentModelID) { node in
                NavigationLink {
                    ComputeNodeEditorView(design: design, editing: node)
                } label: {
                    VStack(alignment: .leading) {
                        Text(node.name)
                        Text(computeDetail(node))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .isDetailLink(false)
            }
            .onDelete { pendingDelete = $0 }
        } header: {
            SectionHeader(title: "Compute") {
                ComputeNodeEditorView(design: design)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.count ?? 0) compute node(s)?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let offsets = pendingDelete {
                    let targets = offsets.map { design.physicalComputeNodes[$0] }
                    targets.forEach { design.removeCompute($0) }
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Hosts also remove their virtual machines.")
        }
    }

    private func computeDetail(_ node: ComputeNode) -> String {
        var details = "\(node.type) - \(node.hwDef.processor) - \(node.zone.name)"
        if node.type == .host {
            details += " (\(node.vmCount) VMs)"
        }
        return details
    }
}

// MARK: - Services

private struct ServicesSection: View {
    @Bindable var design: Design
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDelete: IndexSet?

    private var sortedServices: [ServiceDef] {
        design.services.values.sorted(by: { $0.serviceType < $1.serviceType })
    }

    var body: some View {
        Section {
            ForEach(sortedServices, id: \.serviceType) { def in
                VStack(alignment: .leading) {
                    Text(def.name)
                    Text("\(def.serviceType) - \(def.balancingModel.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { pendingDelete = $0 }
        } header: {
            SectionHeader(title: "Services") {
                ServiceDefPickerView(design: design)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.count ?? 0) service(s)?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let offsets = pendingDelete {
                    let services = sortedServices
                    for i in offsets { design.removeServiceDef(services[i]) }
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Service providers using these services will be updated.")
        }
    }
}

// MARK: - Service Providers

private struct ServiceProvidersSection: View {
    @Bindable var design: Design
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDelete: IndexSet?

    var body: some View {
        Section {
            ForEach(design.serviceProviders, id: \.persistentModelID) { sp in
                NavigationLink {
                    ServiceProviderEditorView(design: design, editing: sp)
                } label: {
                    VStack(alignment: .leading) {
                        Text(sp.name)
                        Text(spDetail(sp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .isDetailLink(false)
            }
            .onDelete { pendingDelete = $0 }
        } header: {
            SectionHeader(title: "Service Providers") {
                ServiceProviderEditorView(design: design)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.count ?? 0) service provider(s)?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let offsets = pendingDelete {
                    let targets = offsets.map { design.serviceProviders[$0] }
                    targets.forEach { design.removeServiceProvider($0) }
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    private func spDetail(_ sp: ServiceProvider) -> String {
        let nodeNames = sp.nodes.map(\.name).joined(separator: ", ")
        return "\(sp.service.serviceType) on \(nodeNames.isEmpty ? "no nodes" : nodeNames)"
    }
}

// MARK: - Workflow Defs

private struct WorkflowDefsSection: View {
    @Bindable var design: Design
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDelete: IndexSet?

    var body: some View {
        Section {
            ForEach(design.workflowDefinitions, id: \.persistentModelID) { def in
                NavigationLink {
                    WorkflowChainEditorView(design: design, workflowDef: def)
                } label: {
                    VStack(alignment: .leading) {
                        Text(def.name)
                        wfDefSubtitle(def)
                    }
                }
                .isDetailLink(false)
            }
            .onDelete { pendingDelete = $0 }
        } header: {
            SectionHeader(title: "Workflow Definitions") {
                WorkflowDefPickerView(design: design)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.count ?? 0) workflow definition(s)?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let offsets = pendingDelete {
                    let targets = offsets.map { design.workflowDefinitions[$0] }
                    targets.forEach { design.removeWorkflowDefinition($0) }
                    design.updateConfiguredWorkflows()
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("Workflows that use these definitions will also be removed.")
        }
    }

    @ViewBuilder
    private func wfDefSubtitle(_ def: WorkflowDef) -> some View {
        let missing = def.missingServiceProviders
        if missing.isEmpty {
            Text("\(def.chains.count) chains, think time: \(def.thinkTimeSeconds)s")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            Text("Missing providers: \(missing.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - Workflows

private struct WorkflowsSection: View {
    @Bindable var design: Design
    @Environment(\.modelContext) private var modelContext
    @State private var pendingDelete: IndexSet?

    var body: some View {
        Section {
            ForEach(design.allWorkflows, id: \.persistentModelID) { wf in
                NavigationLink {
                    WorkflowEditorView(design: design, editing: wf)
                } label: {
                    VStack(alignment: .leading) {
                        Text(wf.name)
                        Text(workflowDetail(wf))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .isDetailLink(false)
            }
            .onDelete { pendingDelete = $0 }
        } header: {
            SectionHeader(title: "Workflows") {
                WorkflowEditorView(design: design)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.count ?? 0) workflow(s)?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let offsets = pendingDelete {
                    let targets = offsets.map { design.allWorkflows[$0] }
                    targets.forEach { design.removeWorkflow($0) }
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        }
    }

    private func workflowDetail(_ wf: Workflow) -> String {
        switch wf.type {
        case .user:
            return "User: \(wf.userCount) users, productivity \(wf.productivity)"
        case .transactional:
            return "Transactional: \(wf.tph) tph"
        }
    }
}

// MARK: - Validation

private struct ValidationSection: View {
    let design: Design

    var body: some View {
        Section {
            let messages = design.validate()
            if messages.isEmpty {
                Label("Design is valid", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                ForEach(Array(messages.enumerated()), id: \.offset) { _, msg in
                    Label {
                        VStack(alignment: .leading) {
                            Text(msg.message)
                            Text(msg.source)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }
            }
        } header: {
			Text("Validation")
	   .font(Font.title2.bold())
}
    }
}

// MARK: - Section header with add button

struct SectionHeader<Destination: View>: View {
    let title: String
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        HStack {
            Text(title)
				.font(Font.title2.bold())
            Spacer()
            NavigationLink {
                destination()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.tint)
            }
            .isDetailLink(false)
        }
    }
}

// MARK: - Previews

@MainActor
private func previewContainer() -> ModelContainer {
    let container = try! ModelContainer(
        for: Design.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let design = Design(name: "Production Cluster", desc: "Primary GIS deployment")
    container.mainContext.insert(design)
    design.addZone(Zone(name: "Data Center", description: "On-prem core"),
                   localBandwidthMbps: 10_000, localLatencyMS: 1)
    design.addZone(Zone(name: "Branch Office", description: "Remote site"),
                   localBandwidthMbps: 1_000, localLatencyMS: 5)
    try? container.mainContext.save()
    return container
}

#Preview("Populated") {
    let container = previewContainer()
    let design = try! container.mainContext.fetch(FetchDescriptor<Design>()).first!
    return NavigationStack {
        DesignDetailView(design: design)
    }
    .environment(AppFocus())
    .environment(\.library, Library())
    .modelContainer(container)
}

#Preview("New Design") {
    let container = try! ModelContainer(
        for: Design.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let design = Design(name: "Untitled Design", desc: "")
    container.mainContext.insert(design)
    return NavigationStack {
        DesignDetailView(design: design)
    }
    .environment(AppFocus())
    .environment(\.library, Library())
    .modelContainer(container)
}
