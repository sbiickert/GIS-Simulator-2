//
//  ChainLibraryView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI
import SwiftData

/// Manages this design's workflow-chain catalog: favorite, duplicate, and
/// create/edit/delete custom chains.
struct ChainLibraryView: View {
    @Bindable var design: Design
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ValueCatalogManagerView(
            design: design,
            title: "Workflow Chains",
            entries: design.chainCatalog(library),
            favoritePath: \.favoriteChains,
            primary: { $0.name },
            subtitle: { "\($0.steps.count) steps" },
            onDuplicate: { src in
                let existing = Set(design.chainCatalog(library).map(\.key))
                let name = design.uniqueCopyName(base: src.name, existingKeys: existing)
                let copy = WorkflowChain(name: name, description: src.desc, steps: src.steps, serviceProviders: [:])
                modelContext.insert(copy)
                try? modelContext.save()
                design.addCustomChain(copy)
                design.addFavorite(name, in: \.favoriteChains)
                try? modelContext.save()
            },
            onDelete: { key in
                if let chain = design.customWorkflowChains.first(where: { $0.name == key }) {
                    design.removeCustomChain(chain)
                    modelContext.delete(chain)
                }
            },
            editor: { editing in
                ChainEditorView(design: design, editing: editing)
            }
        )
    }
}
