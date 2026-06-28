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
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var desc = ""
    @State private var bandwidth = 1000
    @State private var latency = 0
    @State private var errorMessage: String?
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
}
