//
//  ServiceDefPickerView.swift
//  GIS Simulator 2
//

import SwiftUI

struct ServiceDefPickerView: View {
    @Bindable var design: Design

    @Environment(\.dismiss) private var dismiss
    @Environment(\.library) private var library

    @State private var selected: Set<String> = []

    private var availableServices: [(String, ServiceDef)] {
        let existing = Set(design.services.keys)
        return library.serviceDefinitions
            .sorted(by: { $0.key < $1.key })
            .filter { !existing.contains($0.key) }
    }

    var body: some View {
        List {
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
