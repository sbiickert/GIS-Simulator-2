//
//  GIS_Simulator_2App.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

@main
struct GIS_Simulator_2App: App {
    @State private var focus = AppFocus()
    private let library = Library()

    var body: some Scene {
        WindowGroup {
            RootSplitView()
                .environment(focus)
                .environment(\.library, library)
        }
        .modelContainer(for: Design.self)
    }
}

@Observable
final class AppFocus {
    var currentDesign: Design?
}

private struct LibraryKey: EnvironmentKey {
    static let defaultValue = Library()
}

extension EnvironmentValues {
    var library: Library {
        get { self[LibraryKey.self] }
        set { self[LibraryKey.self] = newValue }
    }
}
