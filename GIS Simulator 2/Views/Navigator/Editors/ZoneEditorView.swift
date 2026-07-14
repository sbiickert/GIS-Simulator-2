//
//  ZoneEditorView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct ZoneEditorView: View {
    @Bindable var design: Design
    var editing: Zone?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    @State private var bandwidth = 1000
    @State private var latency = 0
    @State private var errorMessage: String?
    @State private var agolMessage: String?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                TextField("Zone name", text: $name)
                TextField("Description", text: $desc)
            }
            if editing == nil {
                Section("Local Network") {
                    Stepper("Bandwidth: \(bandwidth) Mbps", value: $bandwidth, in: 1...100_000, step: 100)
                    Stepper("Latency: \(latency) ms", value: $latency, in: 0...1_000)
                }
            }
            if editing != nil {
                Section {
                    Button {
                        createArcGISOnline()
                    } label: {
                        Label("Create ArcGIS Online", systemImage: "cloud")
                            .frame(maxWidth: .infinity)
                    }
                } footer: {
                    Text("Adds the ArcGIS Online hosts and service providers to this zone. Anything that already exists is skipped.")
                }
                Section {
                    Button("Delete Zone", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this zone?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Deleting this zone will also remove its network connections and any compute nodes inside it.")
        }
        .navigationTitle(editing == nil ? "New Zone" : "Edit Zone")
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
        .alert("ArcGIS Online", isPresented: Binding(get: { agolMessage != nil }, set: { if !$0 { agolMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(agolMessage ?? "")
        }
        .onAppear(perform: loadInitial)
    }

    private func loadInitial() {
        if let zone = editing {
            name = zone.name
            desc = zone.desc
            if let local = zone.localConnection(in: design.network) {
                bandwidth = local.bandwidthMbps
                latency = local.latencyMs
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "Zone name is required."
            return
        }
        if let zone = editing {
            zone.name = trimmed
            zone.desc = desc
        } else {
            let zone = Zone(name: trimmed, description: desc)
            let local = zone.selfConnect(bandwidth: bandwidth, latency: latency)
            modelContext.insert(zone)
            modelContext.insert(local)
            try? modelContext.save()
            design.zones.append(zone)
            design.network.append(local)
            try? modelContext.save()
        }
        dismiss()
    }

    private func delete() {
        guard let zone = editing else { return }
        design.removeZone(zone)
        try? modelContext.save()
        dismiss()
    }

    /// Provisions the ArcGIS Online hosts and service providers described in
    /// the bundled agol.json into the zone being edited. Idempotent: hosts and
    /// providers that already exist (matched by name) are reused or skipped.
    private func createArcGISOnline() {
        guard let zone = editing else { return }

        let template: AGOLTemplate
        do {
            template = try AGOLTemplate.load()
        } catch {
            errorMessage = "Could not read the ArcGIS Online template: \(error)"
            return
        }

        guard let hardware = design.hardwareCatalog(library)
            .first(where: { $0.key == template.hardware.definition })?.item else {
            errorMessage = "Hardware definition \"\(template.hardware.definition)\" was not found in the library."
            return
        }

        var nodesCreated = 0
        var providersCreated = 0
        var providersRepaired = 0
        var servicesAdded = 0

        // Hosts: "<name> 1" … "<name> count", reusing any that already exist.
        var hosts: [ComputeNode] = []
        for i in 1...template.hardware.count {
            let nodeName = "\(template.hardware.name) \(i)"
            if let existing = design.findCompute(named: nodeName) {
                hosts.append(existing)
                continue
            }
            let node = ComputeNode(name: nodeName, desc: "", hwDef: hardware,
                                   memoryGB: template.hardware.memoryGB, zone: zone, type: .host)
            modelContext.insert(node)
            try? modelContext.save()
            design.physicalComputeNodes.append(node)
            try? modelContext.save()
            hosts.append(node)
            nodesCreated += 1
        }

        let tags = Set(template.tags)
        let serviceCatalog = design.serviceCatalog(library)

        for spec in template.serviceProviders {
            // Make sure the service type is configured in the design,
            // pulling from the merged custom/predefined catalog if not.
            if design.services[spec.service] == nil {
                guard let def = serviceCatalog.first(where: { $0.item.serviceType == spec.service })?.item else {
                    errorMessage = "Service type \"\(spec.service)\" was not found in the library."
                    return
                }
                design.addServiceDef(def)
                servicesAdded += 1
            }
            guard let service = design.services[spec.service] else { continue }

            // addNode respects the service's balancing model, so failover
            // providers take only the first two hosts.
            if let existing = design.serviceProviders.first(where: { $0.name == spec.name && !$0.tags.isDisjoint(with: tags) }) {
                // Provider from an earlier run: top up any missing node assignments.
                let before = existing.nodes.count
                for host in hosts where !existing.nodes.contains(where: { $0 === host }) {
                    existing.addNode(host)
                }
                if existing.nodes.count != before {
                    try? modelContext.save()
                    providersRepaired += 1
                }
                continue
            }

            let sp = ServiceProvider(name: spec.name, desc: spec.desc, service: service, tags: tags)
            modelContext.insert(sp)
            try? modelContext.save()
            for host in hosts {
                sp.addNode(host)
            }
            design.serviceProviders.append(sp)
            try? modelContext.save()
            providersCreated += 1
        }

        if nodesCreated == 0 && providersCreated == 0 && providersRepaired == 0 && servicesAdded == 0 {
            agolMessage = "ArcGIS Online is already set up: nothing to create."
        } else {
            var summary = "Created \(nodesCreated) compute node(s), \(providersCreated) service provider(s) and added \(servicesAdded) service type(s)."
            if providersRepaired > 0 {
                summary += " Restored node assignments on \(providersRepaired) existing provider(s)."
            }
            agolMessage = summary
        }
    }
}
