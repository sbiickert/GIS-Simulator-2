//
//  ValueCatalogManagerView.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI
import SwiftData

/// A reusable management list for a value-type library catalog (predefined ∪
/// custom). Each row can be favorited; custom rows are editable/deletable while
/// predefined rows are copy-only. "Duplicate" creates an independent copy with a
/// unique name. Used for hardware, services, and workflow steps.
struct ValueCatalogManagerView<Item: LibraryItem, Editor: View>: View {
    @Bindable var design: Design
    let title: String
    let entries: [CatalogEntry<Item>]
    let favoritePath: ReferenceWritableKeyPath<Design, [String]>
    let primary: (Item) -> String
    let subtitle: (Item) -> String
    let onDuplicate: (Item) -> Void
    let onDelete: (String) -> Void
    @ViewBuilder let editor: (_ editing: Item?) -> Editor

    @Environment(\.modelContext) private var modelContext
    @State private var deleteKey: String?
    @State private var searchText = ""

    /// Entries whose name matches the current search (case-insensitive).
    private var filteredEntries: [CatalogEntry<Item>] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return entries }
        return entries.filter { primary($0.item).localizedCaseInsensitiveContains(query) }
    }

    private var favorites: [CatalogEntry<Item>] { filteredEntries.filter(\.isFavorite) }
    private var others: [CatalogEntry<Item>] { filteredEntries.filter { !$0.isFavorite } }

    var body: some View {
        List {
            if !favorites.isEmpty {
                Section("Favorites") {
                    ForEach(favorites, id: \.key) { row($0) }
                }
            }
            Section(favorites.isEmpty ? "All" : "Others") {
                ForEach(others, id: \.key) { row($0) }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by name")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavigationLink {
                editor(nil)
            } label: {
                Image(systemName: "plus")
            }
            .isDetailLink(false)
        }
        .confirmationDialog(
            "Delete \"\(deleteKey ?? "")\"?",
            isPresented: Binding(get: { deleteKey != nil }, set: { if !$0 { deleteKey = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let key = deleteKey {
                    onDelete(key)
                    try? modelContext.save()
                }
                deleteKey = nil
            }
            Button("Cancel", role: .cancel) { deleteKey = nil }
        }
    }

    @ViewBuilder
    private func row(_ entry: CatalogEntry<Item>) -> some View {
        let label = HStack {
            FavoriteButton(isFavorite: entry.isFavorite) {
                design.toggleFavorite(entry.key, in: favoritePath)
                try? modelContext.save()
            }
            VStack(alignment: .leading) {
                Text(primary(entry.item))
                Text(subtitle(entry.item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !entry.isCustom {
                Text("Predefined")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }

        Group {
            if entry.isCustom {
                NavigationLink {
                    editor(entry.item)
                } label: {
                    label
                }
                .isDetailLink(false)
            } else {
                label
            }
        }
        .swipeActions(edge: .trailing) {
            if entry.isCustom {
                Button("Delete", role: .destructive) { deleteKey = entry.key }
            }
            Button {
                onDuplicate(entry.item)
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
            }
            .tint(.blue)
        }
    }
}
