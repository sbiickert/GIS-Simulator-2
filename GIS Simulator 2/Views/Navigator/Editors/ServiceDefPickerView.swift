//
//  ServiceDefPickerView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct ServiceDefPickerView: View {
    @Bindable var design: Design

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    @State private var selected: Set<String> = []

    /// The minimal set of service types present in every design.
    private let minimalServiceTypes: Set<String> = [
        "browser", "dbms", "feature", "file", "image", "map",
        "mobile", "portal", "pro", "relational", "web"
    ]

    /// Service definitions not yet added to the design, favorites first.
    private var availableEntries: [CatalogEntry<ServiceDef>] {
        let existing = Set(design.services.keys)
        return design.serviceCatalog(library).filter { !existing.contains($0.key) }
    }

    private var favoriteEntries: [CatalogEntry<ServiceDef>] {
        availableEntries.filter(\.isFavorite)
    }

    private var otherEntries: [CatalogEntry<ServiceDef>] {
        availableEntries.filter { !$0.isFavorite }
    }

    var body: some View {
        List {
            if !availableEntries.isEmpty {
                Section {
                    Button("Select Minimal Set") { selectMinimalSet() }
                }
            }
            if availableEntries.isEmpty {
                Section {
                    Text("All service types have been added")
                        .foregroundStyle(.secondary)
                }
            } else {
                if !favoriteEntries.isEmpty {
                    Section("Favorites") {
                        ForEach(favoriteEntries, id: \.key) { row($0) }
                    }
                }
                Section(favoriteEntries.isEmpty ? "Select service types to add" : "All") {
                    ForEach(otherEntries, id: \.key) { row($0) }
                }
            }
        }
        .navigationTitle("Add Services")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { commit() }
            }
        }
    }

    @ViewBuilder
    private func row(_ entry: CatalogEntry<ServiceDef>) -> some View {
        HStack {
            FavoriteButton(isFavorite: entry.isFavorite) { toggleFavorite(entry.key) }
            Button {
                toggle(entry.key)
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(entry.item.name)
                            .foregroundStyle(.primary)
                        Text("\(entry.key) - \(entry.item.balancingModel.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selected.contains(entry.key) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func selectMinimalSet() {
        for entry in availableEntries where minimalServiceTypes.contains(entry.key) {
            selected.insert(entry.key)
        }
    }

    private func toggle(_ type: String) {
        if selected.contains(type) {
            selected.remove(type)
        } else {
            selected.insert(type)
        }
    }

    private func toggleFavorite(_ key: String) {
        design.toggleFavorite(key, in: \.favoriteServices)
        try? modelContext.save()
    }

    private func commit() {
        let toAdd = availableEntries.filter { selected.contains($0.key) }
        for entry in toAdd {
            design.addServiceDef(entry.item)
        }
        dismiss()
    }
}

// MARK: - Previews

@MainActor
private func previewContainer(addExistingServices: Bool) -> ModelContainer {
    let container = try! ModelContainer(
        for: Design.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let design = Design(name: "Production Cluster", desc: "Primary GIS deployment")
    container.mainContext.insert(design)
    if addExistingServices {
        let library = Library()
        for type in ["map", "feature", "portal"] {
            if let def = library.serviceDefinitions[type] {
                design.addServiceDef(def)
            }
        }
    }
    try? container.mainContext.save()
    return container
}

#Preview("All Available") {
    let container = previewContainer(addExistingServices: false)
    let design = try! container.mainContext.fetch(FetchDescriptor<Design>()).first!
    return NavigationStack {
        ServiceDefPickerView(design: design)
    }
    .environment(\.library, Library())
    .modelContainer(container)
}

#Preview("Some Added") {
    let container = previewContainer(addExistingServices: true)
    let design = try! container.mainContext.fetch(FetchDescriptor<Design>()).first!
    return NavigationStack {
        ServiceDefPickerView(design: design)
    }
    .environment(\.library, Library())
    .modelContainer(container)
}
