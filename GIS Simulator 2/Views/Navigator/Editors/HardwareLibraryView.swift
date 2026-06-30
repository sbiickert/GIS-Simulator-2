//
//  HardwareLibraryView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI
import SwiftData

/// Manages this design's hardware catalog: favorite, duplicate, and create/
/// edit/delete custom hardware definitions.
struct HardwareLibraryView: View {
    @Bindable var design: Design
    @Environment(\.library) private var library
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ValueCatalogManagerView(
            design: design,
            title: "Hardware Definitions",
            entries: design.hardwareCatalog(library),
            favoritePath: \.favoriteHardware,
            primary: { $0.processor },
            subtitle: { "\($0.cores) cores · SPEC \(Int($0.specIntRate2017))" },
            onDuplicate: { src in
                let existing = Set(design.hardwareCatalog(library).map(\.key))
                let name = design.uniqueCopyName(base: src.processor, existingKeys: existing)
                design.upsertCustomHardware(HardwareDef(processor: name, cores: src.cores, specIntRate2017: src.specIntRate2017))
                design.addFavorite(name, in: \.favoriteHardware)
                try? modelContext.save()
            },
            onDelete: { design.removeCustomHardware(key: $0) },
            editor: { editing in
                HardwareDefEditorView(design: design, editing: editing)
            }
        )
    }
}
