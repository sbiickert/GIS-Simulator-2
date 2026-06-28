//
//  DesignDetailView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

/// A pending delete confirmation, hoisted out of the list so swipe-to-delete
/// row reconciliation cannot dismiss the dialog before the user responds.
struct DeleteRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let perform: () -> Void
}

struct DesignDetailView: View {
    @Bindable var design: Design
    @Environment(AppFocus.self) private var focus
    @State private var deleteRequest: DeleteRequest?

    var body: some View {
        Form {
            InfoSection(design: design)
            ZonesSection(design: design, deleteRequest: $deleteRequest)
            NetworkSection(design: design, deleteRequest: $deleteRequest)
            ComputeSection(design: design, deleteRequest: $deleteRequest)
            ServicesSection(design: design, deleteRequest: $deleteRequest)
            ServiceProvidersSection(design: design, deleteRequest: $deleteRequest)
            WorkflowDefsSection(design: design, deleteRequest: $deleteRequest)
            WorkflowsSection(design: design, deleteRequest: $deleteRequest)
            ValidationSection(design: design)
        }
        .navigationTitle(design.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focus.currentDesign = design }
        // Attached to the Form (not a Section) so it survives the swipe-delete
        // row animation and is not auto-dismissed by list reconciliation.
        .confirmationDialog(
            deleteRequest?.title ?? "",
            isPresented: Binding(get: { deleteRequest != nil }, set: { if !$0 { deleteRequest = nil } }),
            titleVisibility: .visible,
            presenting: deleteRequest
        ) { request in
            Button("Delete", role: .destructive) {
                request.perform()
                deleteRequest = nil
            }
            Button("Cancel", role: .cancel) { deleteRequest = nil }
        } message: { request in
            if let message = request.message {
                Text(message)
            }
        }
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
    @Binding var deleteRequest: DeleteRequest?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("section.zones.expanded") private var isExpanded = true

    var body: some View {
        Section(isExpanded: $isExpanded) {
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
            .onDelete { offsets in
                let targets = offsets.map { design.zones[$0] }
                deleteRequest = DeleteRequest(
                    title: "Delete \(targets.count) zone(s)?",
                    message: "Network connections and compute nodes in these zones will also be removed."
                ) {
                    targets.forEach { design.removeZone($0) }
                    try? modelContext.save()
                }
            }
        } header: {
            SectionHeader(title: "Zones", isExpanded: $isExpanded, count: design.zones.count) {
                ZoneEditorView(design: design)
            }
        }
    }
}

// MARK: - Network

private struct NetworkSection: View {
    @Bindable var design: Design
    @Binding var deleteRequest: DeleteRequest?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("section.network.expanded") private var isExpanded = true

    var body: some View {
        Section(isExpanded: $isExpanded) {
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
            .onDelete { offsets in
                let targets = offsets.map { design.network[$0] }
                deleteRequest = DeleteRequest(
                    title: "Delete \(targets.count) connection(s)?",
                    message: nil
                ) {
                    targets.forEach { design.removeConnection($0) }
                    try? modelContext.save()
                }
            }
        } header: {
            SectionHeader(title: "Network", isExpanded: $isExpanded, count: design.network.count) {
                ConnectionEditorView(design: design)
            }
        }
    }
}

// MARK: - Compute

private struct ComputeSection: View {
    @Bindable var design: Design
    @Binding var deleteRequest: DeleteRequest?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("section.compute.expanded") private var isExpanded = true

    var body: some View {
        Section(isExpanded: $isExpanded) {
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
            .onDelete { offsets in
                let targets = offsets.map { design.physicalComputeNodes[$0] }
                deleteRequest = DeleteRequest(
                    title: "Delete \(targets.count) compute node(s)?",
                    message: "Hosts also remove their virtual machines."
                ) {
                    targets.forEach { design.removeCompute($0) }
                    try? modelContext.save()
                }
            }
        } header: {
            SectionHeader(title: "Compute", isExpanded: $isExpanded, count: design.physicalComputeNodes.count) {
                ComputeNodeEditorView(design: design)
            }
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
    @Binding var deleteRequest: DeleteRequest?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("section.services.expanded") private var isExpanded = true

    private var sortedServices: [ServiceDef] {
        design.services.values.sorted(by: { $0.serviceType < $1.serviceType })
    }

    var body: some View {
        Section(isExpanded: $isExpanded) {
            ForEach(sortedServices, id: \.serviceType) { def in
                VStack(alignment: .leading) {
                    Text(def.name)
                    Text("\(def.serviceType) - \(def.balancingModel.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                let services = sortedServices
                let targets = offsets.map { services[$0] }
                deleteRequest = DeleteRequest(
                    title: "Delete \(targets.count) service(s)?",
                    message: "Service providers using these services will be updated."
                ) {
                    targets.forEach { design.removeServiceDef($0) }
                    try? modelContext.save()
                }
            }
        } header: {
            SectionHeader(title: "Services", isExpanded: $isExpanded, count: sortedServices.count) {
                ServiceDefPickerView(design: design)
            }
        }
    }
}

// MARK: - Service Providers

private struct ServiceProvidersSection: View {
    @Bindable var design: Design
    @Binding var deleteRequest: DeleteRequest?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("section.serviceProviders.expanded") private var isExpanded = true

    var body: some View {
        Section(isExpanded: $isExpanded) {
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
            .onDelete { offsets in
                let targets = offsets.map { design.serviceProviders[$0] }
                deleteRequest = DeleteRequest(
                    title: "Delete \(targets.count) service provider(s)?",
                    message: nil
                ) {
                    targets.forEach { design.removeServiceProvider($0) }
                    try? modelContext.save()
                }
            }
        } header: {
            SectionHeader(title: "Service Providers", isExpanded: $isExpanded, count: design.serviceProviders.count) {
                ServiceProviderEditorView(design: design)
            }
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
    @Binding var deleteRequest: DeleteRequest?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("section.workflowDefs.expanded") private var isExpanded = true

    var body: some View {
        Section(isExpanded: $isExpanded) {
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
            .onDelete { offsets in
                let targets = offsets.map { design.workflowDefinitions[$0] }
                deleteRequest = DeleteRequest(
                    title: "Delete \(targets.count) workflow definition(s)?",
                    message: "Workflows that use these definitions will also be removed."
                ) {
                    targets.forEach { design.removeWorkflowDefinition($0) }
                    design.updateConfiguredWorkflows()
                    try? modelContext.save()
                }
            }
        } header: {
            SectionHeader(title: "Workflow Definitions", isExpanded: $isExpanded, count: design.workflowDefinitions.count) {
                WorkflowDefPickerView(design: design)
            }
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
    @Binding var deleteRequest: DeleteRequest?
    @Environment(\.modelContext) private var modelContext
    @AppStorage("section.workflows.expanded") private var isExpanded = true

    var body: some View {
        Section(isExpanded: $isExpanded) {
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
            .onDelete { offsets in
                let targets = offsets.map { design.allWorkflows[$0] }
                deleteRequest = DeleteRequest(
                    title: "Delete \(targets.count) workflow(s)?",
                    message: nil
                ) {
                    targets.forEach { design.removeWorkflow($0) }
                    try? modelContext.save()
                }
            }
        } header: {
            SectionHeader(title: "Workflows", isExpanded: $isExpanded, count: design.allWorkflows.count) {
                WorkflowEditorView(design: design)
            }
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
    /// When supplied, the header shows a tappable chevron that collapses the
    /// section. When `nil`, the title is rendered plainly (non-collapsible).
    var isExpanded: Binding<Bool>? = nil
    /// When supplied, the header shows the item count as a badge so the user
    /// can gauge a section's size without expanding it.
    var count: Int? = nil
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        HStack {
            if let isExpanded {
                Button {
                    withAnimation { isExpanded.wrappedValue.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
                        Text(title)
                            .font(Font.title2.bold())
                        countBadge
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 6) {
                    Text(title)
                        .font(Font.title2.bold())
                    countBadge
                }
            }
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

    @ViewBuilder
    private var countBadge: some View {
        if let count {
            Text("\(count)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(.secondary.opacity(0.15), in: Capsule())
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
