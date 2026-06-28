//
//  DesignListView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct DesignListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Design.name) private var designs: [Design]

    @State private var showingNewDesignAlert = false
    @State private var newDesignName = ""
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
                newDesignName = ""
                showingNewDesignAlert = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .alert("New Design", isPresented: $showingNewDesignAlert) {
            TextField("Design Name", text: $newDesignName)
            Button("Cancel", role: .cancel) {}
            Button("Create") { addDesign() }
        } message: {
            Text("Enter a name for the new design.")
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

    private func addDesign() {
        let trimmed = newDesignName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let design = Design(name: trimmed, desc: "")
        modelContext.insert(design)
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
