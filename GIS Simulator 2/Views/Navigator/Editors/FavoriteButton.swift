//
//  FavoriteButton.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import SwiftUI

/// A small star toggle used in library pick lists to favorite an item so it
/// floats to the top. Rendered as a borderless button so it can live alongside
/// another tappable control in the same list row.
struct FavoriteButton: View {
    let isFavorite: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "star.fill" : "star")
                .foregroundStyle(isFavorite ? .yellow : .secondary)
                .imageScale(.medium)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Unfavorite" : "Favorite")
    }
}
