//
//  StepLibraryView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI
import SwiftData

/// Manages this design's workflow-step catalog: favorite, duplicate, and
/// create/edit/delete custom steps.
struct StepLibraryView: View {
    @Bindable var design: Design
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ValueCatalogManagerView(
            design: design,
            title: "Workflow Steps",
            entries: design.stepCatalog(library),
            favoritePath: \.favoriteSteps,
            primary: { $0.name },
            subtitle: { "\($0.serviceType.isEmpty ? "no service" : $0.serviceType) · \($0.serviceTime) ms" },
            onDuplicate: { src in
                let existing = Set(design.stepCatalog(library).map(\.key))
                let name = design.uniqueCopyName(base: src.name, existingKeys: existing)
                var copy = src
                copy.name = name
                design.upsertCustomWorkflowStep(copy)
                design.addFavorite(name, in: \.favoriteSteps)
                try? modelContext.save()
            },
            onDelete: { design.removeCustomWorkflowStep(key: $0) },
            editor: { editing in
                WorkflowDefStepEditorView(design: design, editing: editing)
            }
        )
    }
}
