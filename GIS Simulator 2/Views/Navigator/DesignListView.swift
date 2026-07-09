//
//  DesignListView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct DesignListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Design.name) private var designs: [Design]

    @State private var showingNewDesignSheet = false
    @State private var pendingDelete: IndexSet?

    var body: some View {
        List {
            ForEach(designs) { design in
                NavigationLink {
                    DesignDetailView(design: design)
                } label: {
                    DesignRow(design: design)
                }
                .isDetailLink(false)
            }
            .onDelete { pendingDelete = $0 }
        }
        .navigationTitle("Designs")
        .toolbar {
            Button {
                showingNewDesignSheet = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingNewDesignSheet) {
            NewDesignSheet { name, desc, topology in
                addDesign(name: name, desc: desc, topology: topology)
            }
        }
        .confirmationDialog(
            "Delete \(pendingDelete?.count ?? 0) design(s)?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let offsets = pendingDelete {
                    for i in offsets { modelContext.delete(designs[i]) }
                    try? modelContext.save()
                }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("This will permanently delete the design and all its contents.")
        }
    }

    private func addDesign(name: String, desc: String, topology: StarterTopology) {
        let design = Design(name: name, desc: desc)
        modelContext.insert(design)
        try? modelContext.save()

        let (zones, connections) = topology.build()
        guard !zones.isEmpty else { return }
        for zone in zones { modelContext.insert(zone) }
        for conn in connections { modelContext.insert(conn) }
        try? modelContext.save()
        design.zones.append(contentsOf: zones)
        design.network.append(contentsOf: connections)
        try? modelContext.save()
    }
}

/// Starting network topologies offered when creating a new design.
enum StarterTopology: String, CaseIterable, Identifiable {
    case empty = "Empty"
    case lanOnly = "LAN Only"
    case lanDmzInternet = "LAN, DMZ & Internet"
    case lanDmzInternetAGOL = "LAN, DMZ, Internet & ArcGIS Online"

    var id: String { rawValue }

    var summary: String {
        switch self {
        case .empty:
            return "No zones. Build the network from scratch."
        case .lanOnly:
            return "A single local area network with its internal connection."
        case .lanDmzInternet:
            return "Three zones connected LAN — DMZ — Internet."
        case .lanDmzInternetAGOL:
            return "LAN — DMZ — Internet, plus an ArcGIS Online data center reached over the Internet."
        }
    }

    /// Builds the zones and connections for this topology. The caller is
    /// responsible for inserting them into the model context and attaching
    /// them to a Design.
    func build() -> (zones: [Zone], connections: [Connection]) {
        guard self != .empty else { return ([], []) }

        let lan = Zone(name: "LAN", description: "Local area network")
        var zones = [lan]
        var connections = [lan.selfConnect(bandwidth: 1000, latency: 0)]

        if self != .lanOnly {
            let dmz = Zone(name: "DMZ", description: "Perimeter network")
            let internet = Zone(name: "Internet", description: "Public internet")
            zones += [dmz, internet]
            connections.append(dmz.selfConnect(bandwidth: 1000, latency: 0))
            connections.append(internet.selfConnect(bandwidth: 1000, latency: 10))
            connections += lan.connectBothWays(to: dmz, bandwidth: 1000, latency: 0)
            connections += dmz.connectBothWays(to: internet, bandwidth: 100, latency: 10)

            if self == .lanDmzInternetAGOL {
                let agol = Zone(name: "ArcGIS Online", description: "Esri SaaS data center")
                zones.append(agol)
                connections.append(agol.selfConnect(bandwidth: 10_000, latency: 0))
                connections += internet.connectBothWays(to: agol, bandwidth: 1000, latency: 10)
            }
        }

        return (zones, connections)
    }
}

private struct NewDesignSheet: View {
    var onCreate: (String, String, StarterTopology) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var desc = ""
    @State private var topology: StarterTopology = .lanOnly

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Design name", text: $name)
                    TextField("Description", text: $desc)
                }
                Section("Starting Network") {
                    Picker("Topology", selection: $topology) {
                        ForEach(StarterTopology.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                    Text(topology.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Design")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(trimmedName, desc.trimmingCharacters(in: .whitespaces), topology)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }
}

private struct DesignRow: View {
    let design: Design

    var body: some View {
        HStack {
            Image(systemName: design.isValid ? "checkmark.seal.fill" : "exclamationmark.triangle")
                .foregroundStyle(design.isValid ? .green : .orange)
            VStack(alignment: .leading) {
                Text(design.name)
                if !design.desc.isEmpty {
                    Text(design.desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview("Design List") {
    let container = try! ModelContainer(
        for: Design.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(Design(name: "Production Cluster", desc: "Primary GIS deployment"))
    container.mainContext.insert(Design(name: "Disaster Recovery", desc: "Standby site"))
    container.mainContext.insert(Design(name: "Lab", desc: ""))

    return NavigationStack {
        DesignListView()
    }
    .modelContainer(container)
}

#Preview("Empty") {
    NavigationStack {
        DesignListView()
    }
    .modelContainer(for: Design.self, inMemory: true)
}
