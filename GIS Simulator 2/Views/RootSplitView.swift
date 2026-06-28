//
//  RootSplitView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

struct RootSplitView: View {
    @Environment(AppFocus.self) private var focus

    var body: some View {
        NavigationSplitView {
            NavigationStack {
                DesignListView()
            }
        } detail: {
            DesignCanvasView(design: focus.currentDesign)
        }
    }
}
