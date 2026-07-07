//
//  WorkflowDefLibraryView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-07-07.
//

import SwiftUI
import SwiftData

/// Manages this design's workflow-definition catalog: favorite, duplicate, and
/// create/edit/delete the design's own definitions. Duplicating a predefined
/// definition adds an independent copy (with fresh chain copies) to the design.
struct WorkflowDefLibraryView: View {
    @Bindable var design: Design
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ValueCatalogManagerView(
            design: design,
            title: "Workflow Definitions",
            entries: design.workflowDefCatalog(library),
            favoritePath: \.favoriteWorkflowDefs,
            primary: { $0.name },
            subtitle: subtitle,
            onDuplicate: duplicate,
            onDelete: { key in
                if let def = design.workflowDefinitions.first(where: { $0.name == key }) {
                    design.removeWorkflowDefinition(def)
                    design.updateConfiguredWorkflows()
                    design.favoriteWorkflowDefs.removeAll { $0 == key }
                    modelContext.delete(def)
                }
            },
            editor: { editing in
                if let editing {
                    WorkflowChainEditorView(design: design, workflowDef: editing)
                } else {
                    WorkflowDefEditorView(design: design)
                }
            }
        )
    }

    /// Missing-provider warnings only apply to the design's own definitions;
    /// predefined templates never have providers assigned.
    private func subtitle(_ def: WorkflowDef) -> String {
        let missing = design.workflowDefinitions.contains(def) ? def.missingServiceProviders : []
        guard missing.isEmpty else {
            return "Missing providers: \(missing.joined(separator: ", "))"
        }
        return "\(def.chains.count) chains, think time: \(def.thinkTimeSeconds)s"
    }

    /// Adds an independent copy of a definition (with fresh chain copies) to the
    /// design. A predefined definition keeps its name on first copy so it joins
    /// the design under its familiar name; subsequent copies get unique names.
    private func duplicate(_ src: WorkflowDef) {
        let designNames = Set(design.workflowDefinitions.map(\.name))
        let allKeys = Set(design.workflowDefCatalog(library).map(\.key))
        let name = designNames.contains(src.name)
            ? design.uniqueCopyName(base: src.name, existingKeys: allKeys)
            : src.name
        let chainCopies = src.chains.map {
            WorkflowChain(name: $0.name, description: $0.desc, steps: $0.steps, serviceProviders: [:])
        }
        for chain in chainCopies { modelContext.insert(chain) }
        let copy = WorkflowDef(name: name, desc: src.desc, thinkTimeSeconds: src.thinkTimeSeconds, chains: chainCopies)
        modelContext.insert(copy)
        try? modelContext.save()
        design.workflowDefinitions.append(copy)
        design.addFavorite(name, in: \.favoriteWorkflowDefs)
        try? modelContext.save()
    }
}
