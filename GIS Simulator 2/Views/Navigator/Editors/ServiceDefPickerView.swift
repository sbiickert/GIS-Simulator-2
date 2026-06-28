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

    @State private var selected: Set<String> = []

    /// The minimal set of service types present in every design.
    private let minimalServiceTypes: Set<String> = [
        "browser", "dbms", "feature", "file", "image", "map",
        "mobile", "portal", "pro", "relational", "web"
    ]

    private var availableServices: [(String, ServiceDef)] {
        let existing = Set(design.services.keys)
        return library.serviceDefinitions
            .sorted(by: { $0.key < $1.key })
            .filter { !existing.contains($0.key) }
    }

    var body: some View {
        List {
            if !availableServices.isEmpty {
                Section {
                    Button("Select Minimal Set") { selectMinimalSet() }
                }
            }
            Section {
                if availableServices.isEmpty {
                    Text("All service types have been added")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(availableServices, id: \.0) { _, def in
                        Button {
                            toggle(def.serviceType)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(def.name)
                                        .foregroundStyle(.primary)
                                    Text("\(def.serviceType) - \(def.balancingModel.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selected.contains(def.serviceType) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                Text(availableServices.isEmpty ? "" : "Select service types to add")
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

    private func selectMinimalSet() {
        for (_, def) in availableServices where minimalServiceTypes.contains(def.serviceType) {
            selected.insert(def.serviceType)
        }
    }

    private func toggle(_ type: String) {
        if selected.contains(type) {
            selected.remove(type)
        } else {
            selected.insert(type)
        }
    }

    private func commit() {
        for (_, def) in availableServices where selected.contains(def.serviceType) {
            design.addServiceDef(def)
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
