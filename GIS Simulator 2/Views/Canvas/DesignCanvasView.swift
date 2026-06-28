//
//  DesignCanvasView.swift
//  GIS Simulator 2
//

import SwiftUI
import SpriteKit

struct DesignCanvasView: View {
    let design: Design?

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: makeScene(size: geo.size))
                .ignoresSafeArea()
        }
        .overlay(alignment: .topLeading) {
            if let design {
                Text(design.name)
                    .font(.headline)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .padding()
            }
        }
        .overlay {
            if design == nil {
                Text("Select a design")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func makeScene(size: CGSize) -> SKScene {
        let scene = DesignScene(size: size)
        scene.scaleMode = .resizeFill
        scene.design = design
        return scene
    }
}

final class DesignScene: SKScene {
    var design: Design?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        rebuild()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        rebuild()
    }

    private func rebuild() {
        removeAllChildren()
        guard let design else { return }

        let zones = design.zones
        guard !zones.isEmpty else { return }

        let radius: CGFloat = min(size.width, size.height) * 0.35
        let center = CGPoint(x: size.width / 2, y: size.height / 2)

        for (index, zone) in zones.enumerated() {
            let angle = (CGFloat(index) / CGFloat(zones.count)) * 2 * .pi
            let position = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )

            let node = SKShapeNode(circleOfRadius: 28)
            node.position = position
            node.fillColor = .systemTeal
            node.strokeColor = .white
            addChild(node)

            let label = SKLabelNode(text: zone.name)
            label.fontSize = 12
            label.fontColor = .white
            label.position = CGPoint(x: 0, y: -44)
            node.addChild(label)
        }
    }
}
