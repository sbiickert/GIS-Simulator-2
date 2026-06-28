//
//  ConnectionEditorView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct ConnectionEditorView: View {
    @Bindable var design: Design
    var editing: Connection?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var sourceIndex = 0
    @State private var destIndex = 0
    @State private var bandwidth = 1000
    @State private var latency = 0
    @State private var reciprocal = true
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                Picker("Source", selection: $sourceIndex) {
                    ForEach(Array(design.zones.enumerated()), id: \.offset) { i, zone in
                        Text(zone.name).tag(i)
                    }
                }
                Picker("Destination", selection: $destIndex) {
                    ForEach(Array(design.zones.enumerated()), id: \.offset) { i, zone in
                        Text(zone.name).tag(i)
                    }
                }
            }
            Section {
                Stepper("Bandwidth: \(bandwidth) Mbps", value: $bandwidth, in: 1...100_000, step: 100)
                Stepper("Latency: \(latency) ms", value: $latency, in: 0...1_000)
            }
            if editing == nil {
                Section {
                    Toggle("Add Reciprocal", isOn: $reciprocal)
                }
            }
            if editing != nil {
                Section {
                    Button("Delete Connection", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog(
            "Delete this connection?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
        .navigationTitle(editing == nil ? "New Connection" : "Edit Connection")
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
        if let conn = editing {
            sourceIndex = design.zones.firstIndex(of: conn.source) ?? 0
            destIndex = design.zones.firstIndex(of: conn.destination) ?? 0
            bandwidth = conn.bandwidthMbps
            latency = conn.latencyMs
        }
    }

    private func save() {
        guard !design.zones.isEmpty else {
            errorMessage = "Add zones before creating connections."
            return
        }
        guard sourceIndex != destIndex else {
            errorMessage = "Source and destination must be different zones."
            return
        }

        let source = design.zones[sourceIndex]
        let dest = design.zones[destIndex]

        if let conn = editing {
            conn.bandwidthMbps = bandwidth
            conn.latencyMs = latency
        } else {
            let conn = Connection(source: source, destination: dest, bandwidthMbps: bandwidth, latencyMs: latency)
            modelContext.insert(conn)
            var inverse: Connection?
            if reciprocal {
                let i = conn.inverted()
                modelContext.insert(i)
                inverse = i
            }
            try? modelContext.save()
            design.network.append(conn)
            if let inverse { design.network.append(inverse) }
            try? modelContext.save()
        }
        dismiss()
    }

    private func delete() {
        guard let conn = editing else { return }
        design.removeConnection(conn)
        try? modelContext.save()
        dismiss()
    }
}
