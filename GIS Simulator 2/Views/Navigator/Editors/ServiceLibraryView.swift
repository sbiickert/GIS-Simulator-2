//
//  ServiceLibraryView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI
import SwiftData

/// Manages this design's service-definition catalog: favorite, duplicate, and
/// create/edit/delete custom service definitions.
struct ServiceLibraryView: View {
    @Bindable var design: Design
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ValueCatalogManagerView(
            design: design,
            title: "Services",
            entries: design.serviceCatalog(library),
            favoritePath: \.favoriteServices,
            primary: { $0.name },
            subtitle: { "\($0.serviceType) · \($0.balancingModel.rawValue)" },
            onDuplicate: { src in
                let existing = Set(design.serviceCatalog(library).map(\.key))
                let type = design.uniqueCopyName(base: src.serviceType, existingKeys: existing)
                design.upsertCustomServiceDef(
                    ServiceDef(name: "\(src.name) copy", desc: src.desc, serviceType: type, balancingModel: src.balancingModel)
                )
                design.addFavorite(type, in: \.favoriteServices)
                try? modelContext.save()
            },
            onDelete: { design.removeCustomServiceDef(key: $0) },
            editor: { editing in
                ServiceDefEditorView(design: design, editing: editing)
            }
        )
    }
}
