//
//  DesignCanvasView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData

/// The three ways to visualise a design. The network (zones + connections) is
/// not its own mode; it appears inside each mode as zone boundary boxes.
enum CanvasMode: String, CaseIterable, Identifiable {
    case compute
    case serviceProviders
    case workflow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compute:          return "Compute"
        case .serviceProviders: return "Service Providers"
        case .workflow:         return "Workflow"
        }
    }
}

struct DesignCanvasView: View {
    let design: Design?
    @State private var mode: CanvasMode

    init(design: Design?, initialMode: CanvasMode = .compute) {
        self.design = design
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        Canvas { context, size in
            guard let design else { return }
            switch mode {
            case .compute:          drawZonedCompute(design, into: &context, size: size, showProviders: false)
            case .serviceProviders: drawZonedCompute(design, into: &context, size: size, showProviders: true)
            case .workflow:         drawWorkflow(design, into: &context, size: size)
            }
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Picker("View", selection: $mode) {
                ForEach(CanvasMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()
            .padding(6)
            .background(.thinMaterial, in: Capsule())
            .padding(.top, 8)
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
            if let message = emptyMessage {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var emptyMessage: String? {
        guard let design else { return "Select a design" }
        switch mode {
        case .compute, .serviceProviders:
            return design.zones.isEmpty ? "No zones defined" : nil
        case .workflow:
            return design.allWorkflows.isEmpty ? "No workflows configured" : nil
        }
    }
}

// MARK: - Style

private enum CanvasStyle {
    static let host = Color(red: 0.50, green: 0.55, blue: 0.95)     // navy
    static let client = Color(red: 0.74, green: 0.36, blue: 0.95)   // magenta
    static let vm = Color(red: 0.72, green: 0.73, blue: 0.95)       // lavender
    static let provider = Color(white: 0.30)                        // dark gray
    static let zoneStroke = Color.gray
    static let zoneFill = Color.gray.opacity(0.08)
    static let arrow = Color.gray
    static let edge = Color.teal

    // Workflow node colors
    static let workflow = Color(red: 0.36, green: 0.40, blue: 0.90) // blue
    static let workflowDef = Color(red: 0.95, green: 0.60, blue: 0.15) // orange
    static let chain = Color(white: 0.82)
    static let step = Color.white

    static let hostRadius: CGFloat = 32
    static let vmRadius: CGFloat = 28
    static let providerRadius: CGFloat = 18
    static let wfRadius: CGFloat = 24
    static let topInset: CGFloat = 56
}

// MARK: - Compute / Service Providers

private struct NodePlacement {
    let center: CGPoint
    let radius: CGFloat
}

extension DesignCanvasView {

    /// Draws the zone boxes, inter-zone connection arrows and the compute nodes
    /// inside their zone. When `showProviders` is true it also overlays the
    /// service-provider nodes and their links (Service Providers mode).
    fileprivate func drawZonedCompute(_ design: Design, into ctx: inout GraphicsContext, size: CGSize, showProviders: Bool) {
        let regions = zoneRegions(design.zones, in: size)

        // 1. Zone boxes
        for zone in design.zones {
            if let rect = regions[ObjectIdentifier(zone)] {
                drawZoneBox(zone, in: rect, network: design.network, into: &ctx)
            }
        }

        // 2. Inter-zone connection arrows
        drawConnectionArrows(design, regions: regions, into: &ctx)

        // 3. Place all compute nodes (hosts, clients, vms) within their zone box
        let placements = placeComputeNodes(design, regions: regions)

        // 4. Host -> VM edges
        for host in design.physicalComputeNodes where host.type == .host {
            guard let hp = placements[ObjectIdentifier(host)] else { continue }
            for vm in host.vmList {
                if let vp = placements[ObjectIdentifier(vm)] {
                    drawEdge(from: hp.center, to: vp.center, into: &ctx)
                }
            }
        }

        // 5. Provider links (behind nodes) + record positions. Providers are
        // anchored at their handler node and fanned out when several share one
        // node, so their labels don't stack. Links reach every node they run on
        // (crossing zone boxes for multi-zone providers).
        var providerPositions: [ObjectIdentifier: CGPoint] = [:]
        if showProviders {
            var byHandler: [ObjectIdentifier: [ServiceProvider]] = [:]
            var handlerOrder: [ObjectIdentifier] = []
            for sp in design.serviceProviders {
                guard let handler = sp.handlerNode, placements[ObjectIdentifier(handler)] != nil else { continue }
                let hid = ObjectIdentifier(handler)
                if byHandler[hid] == nil { handlerOrder.append(hid) }
                byHandler[hid, default: []].append(sp)
            }
            for hid in handlerOrder {
                guard let anchor = placements[hid], let sps = byHandler[hid] else { continue }
                let ringR = anchor.radius + 30
                for (i, sp) in sps.enumerated() {
                    let spread = sps.count > 1 ? (CGFloat(i) - CGFloat(sps.count - 1) / 2) * 0.7 : 0
                    let angle = -CGFloat.pi / 2 + spread
                    let pos = anchor.center + CGPoint(x: ringR * cos(angle), y: ringR * sin(angle))
                    providerPositions[ObjectIdentifier(sp)] = pos
                    for node in sp.nodes {
                        if let target = placements[ObjectIdentifier(node)] {
                            drawEdge(from: pos, to: target.center, into: &ctx)
                        }
                    }
                }
            }
        }

        // 6. Compute node circles + captions
        for node in design.allComputeNodes {
            if let p = placements[ObjectIdentifier(node)] {
                drawComputeNode(node, at: p.center, radius: p.radius, into: &ctx)
            }
        }

        // 7. Provider circles on top, name below
        if showProviders {
            for sp in design.serviceProviders {
                if let pos = providerPositions[ObjectIdentifier(sp)] {
                    drawNodeCircle(pos, radius: CanvasStyle.providerRadius, fill: CanvasStyle.provider,
                                   stroke: .white, label: "", labelColor: .clear, into: &ctx)
                    drawText(sp.name, at: CGPoint(x: pos.x, y: pos.y + CanvasStyle.providerRadius + 3),
                             size: 8, weight: .semibold, color: .primary, anchor: .top, into: &ctx)
                }
            }
        }
    }

    /// Packs zones into a grid; every zone (even empty) gets a cell.
    fileprivate func zoneRegions(_ zones: [Zone], in size: CGSize) -> [ObjectIdentifier: CGRect] {
        guard !zones.isEmpty else { return [:] }
        let n = zones.count
        let cols = max(1, Int(ceil(sqrt(Double(n)))))
        let rows = max(1, Int(ceil(Double(n) / Double(cols))))
        let outerPad: CGFloat = 24
        let gap: CGFloat = 64
        let cellW = (size.width - outerPad * 2 - gap * CGFloat(cols - 1)) / CGFloat(cols)
        let cellH = (size.height - CanvasStyle.topInset - outerPad - gap * CGFloat(rows - 1)) / CGFloat(rows)
        var result: [ObjectIdentifier: CGRect] = [:]
        for (i, zone) in zones.enumerated() {
            let r = i / cols, c = i % cols
            let x = outerPad + CGFloat(c) * (cellW + gap)
            let y = CanvasStyle.topInset + CGFloat(r) * (cellH + gap)
            result[ObjectIdentifier(zone)] = CGRect(x: x, y: y, width: max(1, cellW), height: max(1, cellH))
        }
        return result
    }

    fileprivate func drawZoneBox(_ zone: Zone, in rect: CGRect, network: [Connection], into ctx: inout GraphicsContext) {
        let path = Path(roundedRect: rect, cornerRadius: 24)
        ctx.fill(path, with: .color(CanvasStyle.zoneFill))
        ctx.stroke(path, with: .color(CanvasStyle.zoneStroke), lineWidth: 1.5)
        drawText(zone.name, at: CGPoint(x: rect.minX + 18, y: rect.minY + 7),
                 size: 12, weight: .semibold, color: .primary, anchor: .topLeading, into: &ctx)
        if let local = zone.localConnection(in: network) {
            drawText("local \(local.bandwidthMbps)/\(local.latencyMs)",
                     at: CGPoint(x: rect.minX + 18, y: rect.minY + 24),
                     size: 9, color: .secondary, anchor: .topLeading, into: &ctx)
        }
    }

    /// One directional arrow per inter-zone connection, box edge to box edge.
    /// Reciprocal connections bow to opposite sides automatically.
    fileprivate func drawConnectionArrows(_ design: Design, regions: [ObjectIdentifier: CGRect], into ctx: inout GraphicsContext) {
        for conn in design.network where conn.source !== conn.destination {
            guard let sr = regions[ObjectIdentifier(conn.source)],
                  let dr = regions[ObjectIdentifier(conn.destination)] else { continue }
            let start = edgePoint(of: sr, towards: dr.center)
            let end = edgePoint(of: dr, towards: sr.center)
            let dir = (end - start).normalized()
            let perp = CGPoint(x: -dir.y, y: dir.x)
            let mid = (start + end) * 0.5
            let control = mid + perp * 26
            var path = Path()
            path.move(to: start)
            path.addQuadCurve(to: end, control: control)
            ctx.stroke(path, with: .color(CanvasStyle.arrow), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            drawArrowhead(at: end, direction: (end - control).normalized(), color: CanvasStyle.arrow, into: &ctx)
            let labelPos = bezierPoint(start, control, end, 0.5)
            drawPill("\(conn.bandwidthMbps)/\(conn.latencyMs)", at: labelPos, into: &ctx)
        }
    }

    /// Grid-packs each zone's hosts and clients into its box, and rings each
    /// host's VMs around it.
    fileprivate func placeComputeNodes(_ design: Design, regions: [ObjectIdentifier: CGRect]) -> [ObjectIdentifier: NodePlacement] {
        var placements: [ObjectIdentifier: NodePlacement] = [:]
        for zone in design.zones {
            guard let rect = regions[ObjectIdentifier(zone)] else { continue }
            let units = design.physicalComputeNodes.filter { $0.zone === zone }
            guard !units.isEmpty else { continue }

            let inner = CGRect(x: rect.minX + 14, y: rect.minY + 42,
                               width: max(1, rect.width - 28), height: max(1, rect.height - 56))
            let n = units.count
            let cols = max(1, Int(ceil(sqrt(Double(n)))))
            let rows = max(1, Int(ceil(Double(n) / Double(cols))))
            let cellW = inner.width / CGFloat(cols)
            let cellH = inner.height / CGFloat(rows)

            for (i, unit) in units.enumerated() {
                let r = i / cols, c = i % cols
                let center = CGPoint(x: inner.minX + (CGFloat(c) + 0.5) * cellW,
                                     y: inner.minY + (CGFloat(r) + 0.5) * cellH)
                placements[ObjectIdentifier(unit)] = NodePlacement(center: center, radius: CanvasStyle.hostRadius)

                if unit.type == .host, !unit.vmList.isEmpty {
                    let ringR = max(CanvasStyle.hostRadius + CanvasStyle.vmRadius + 8,
                                    min(cellW, cellH) * 0.32)
                    for (j, vm) in unit.vmList.enumerated() {
                        let a = -CGFloat.pi / 2 + 2 * .pi * CGFloat(j) / CGFloat(unit.vmList.count)
                        let p = CGPoint(x: center.x + ringR * cos(a), y: center.y + ringR * sin(a))
                        placements[ObjectIdentifier(vm)] = NodePlacement(center: p, radius: CanvasStyle.vmRadius)
                    }
                }
            }
        }
        return placements
    }

    fileprivate func drawComputeNode(_ node: ComputeNode, at center: CGPoint, radius: CGFloat, into ctx: inout GraphicsContext) {
        // Color conveys the type; name and spec go below to stay legible in the
        // small circles.
        drawNodeCircle(center, radius: radius, fill: fillColor(for: node.type), stroke: .white,
                       label: "", labelColor: .clear, into: &ctx)
        drawText(node.name, at: CGPoint(x: center.x, y: center.y - 4),
				 size: 10, weight: .bold, color: .primary, anchor: .center, into: &ctx)

        var y = center.y + 12
		if node.type != .vm {
			let spec = node.hwDef.processor
			drawText(spec, at: CGPoint(x: center.x, y: y),
					 size: 9, weight: .semibold, color: .primary, anchor: .center, into: &ctx)
			y += 12
		}
        let spec = "\(node.displayCpuCount) CPU · \(node.memoryGB) GB"
        drawText(spec, at: CGPoint(x: center.x, y: y),
				 size: 9, weight: .semibold, color: .primary, anchor: .center, into: &ctx)
    }

    fileprivate func fillColor(for type: ComputeNodeType) -> Color {
        switch type {
        case .host:   return CanvasStyle.host
        case .client: return CanvasStyle.client
        case .vm:     return CanvasStyle.vm
        }
    }

}

// MARK: - Workflow

private enum WFKind { case workflow, def, chain, provider }

private struct WFNode {
    let id: AnyHashable
    let label: String
    let kind: WFKind
    let zone: Zone?
}

private struct WFEdge: Hashable {
    let from: AnyHashable
    let to: AnyHashable
}

private struct WFGraph {
    private(set) var nodes: [AnyHashable: WFNode] = [:]
    private(set) var order: [AnyHashable] = []
    private(set) var edges: Set<WFEdge> = []

    mutating func add(_ node: WFNode) {
        if nodes[node.id] == nil {
            nodes[node.id] = node
            order.append(node.id)
        }
    }

    mutating func connect(_ from: AnyHashable, _ to: AnyHashable) {
        guard from != to else { return }
        edges.insert(WFEdge(from: from, to: to))
    }

    /// Longest-path rank from the roots (workflow nodes at rank 0), relaxed
    /// enough times to settle any DAG and self-limiting on stray cycles.
    func ranks() -> [AnyHashable: Int] {
        var rank: [AnyHashable: Int] = [:]
        for id in order { rank[id] = 0 }
        let list = Array(edges)
        for _ in 0..<max(1, order.count) {
            var changed = false
            for e in list {
                let candidate = (rank[e.from] ?? 0) + 1
                if candidate > (rank[e.to] ?? 0) {
                    rank[e.to] = candidate
                    changed = true
                }
            }
            if !changed { break }
        }
        return rank
    }

    func parents(of id: AnyHashable) -> [AnyHashable] {
        edges.filter { $0.to == id }.map(\.from)
    }
}

extension DesignCanvasView {

    fileprivate func drawWorkflow(_ design: Design, into ctx: inout GraphicsContext, size: CGSize) {
        let graph = buildWorkflowGraph(design)
        guard !graph.order.isEmpty else { return }

        let positions = layoutWorkflow(graph, in: size)

        // Zone grouping boxes behind everything (provider nodes only)
        drawWorkflowZoneBoxes(graph, positions: positions, into: &ctx)

        // Edges
        for edge in graph.edges {
            guard let a = positions[edge.from], let b = positions[edge.to] else { continue }
            let dy = (b.y - a.y) * 0.5
            var path = Path()
            path.move(to: a)
            path.addCurve(to: b,
                          control1: CGPoint(x: a.x, y: a.y + dy),
                          control2: CGPoint(x: b.x, y: b.y - dy))
            ctx.stroke(path, with: .color(Color(white: 0.25)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        }

        // Nodes
        for id in graph.order {
            guard let node = graph.nodes[id], let p = positions[id] else { continue }
            let style = workflowNodeStyle(node.kind)
            drawNodeCircle(p, radius: CanvasStyle.wfRadius, fill: style.fill, stroke: style.stroke,
                           label: node.label, labelColor: style.labelColor, into: &ctx)
        }
    }

    private func workflowNodeStyle(_ kind: WFKind) -> (fill: Color, stroke: Color, labelColor: Color) {
        switch kind {
        case .workflow: return (CanvasStyle.workflow, .white, .black)
        case .def:      return (CanvasStyle.workflowDef, .white, .black)
        case .chain:    return (CanvasStyle.chain, .gray, .black)
        case .provider: return (CanvasStyle.step, .gray, .black)
        }
    }

    private func buildWorkflowGraph(_ design: Design) -> WFGraph {
        var graph = WFGraph()
        var synthetic = 0
        for wf in design.allWorkflows {
            let wfId = AnyHashable(ObjectIdentifier(wf))
            graph.add(WFNode(id: wfId, label: wf.name, kind: .workflow, zone: nil))

            let def = wf.definition
            let defId = AnyHashable(ObjectIdentifier(def))
            graph.add(WFNode(id: defId, label: def.name, kind: .def, zone: nil))
            graph.connect(wfId, defId)

            for chain in def.chains {
                let chainId = AnyHashable(ObjectIdentifier(chain))
                graph.add(WFNode(id: chainId, label: chain.name, kind: .chain, zone: nil))
                graph.connect(defId, chainId)

                var prev = chainId
                for step in chain.steps {
                    let nid: AnyHashable
                    let label: String
                    let zone: Zone?
                    if let sp = chain.serviceProvider(for: step) {
                        nid = AnyHashable(ObjectIdentifier(sp))
                        label = sp.name
                        zone = sp.handlerNode?.zone
                    } else {
                        synthetic += 1
                        nid = AnyHashable("unassigned-\(synthetic)")
                        label = step.serviceType
                        zone = nil
                    }
                    graph.add(WFNode(id: nid, label: label, kind: .provider, zone: zone))
                    graph.connect(prev, nid)
                    prev = nid
                }
            }
        }
        return graph
    }

    private func layoutWorkflow(_ graph: WFGraph, in size: CGSize) -> [AnyHashable: CGPoint] {
        let rank = graph.ranks()
        let maxRank = rank.values.max() ?? 0
        var byRank: [Int: [AnyHashable]] = [:]
        for id in graph.order { byRank[rank[id] ?? 0, default: []].append(id) }

        let top = CanvasStyle.topInset + 10
        let usableH = max(1, size.height - top - 30)
        let rowH = usableH / CGFloat(maxRank + 1)

        var positions: [AnyHashable: CGPoint] = [:]
        var xByNode: [AnyHashable: CGFloat] = [:]
        for r in 0...maxRank {
            var ids = byRank[r] ?? []
            if r > 0 {
                // Barycenter ordering to reduce edge crossings.
                ids.sort { lhs, rhs in
                    barycenter(lhs, graph: graph, x: xByNode) < barycenter(rhs, graph: graph, x: xByNode)
                }
            }
            let count = ids.count
            let y = top + (CGFloat(r) + 0.5) * rowH
            for (i, id) in ids.enumerated() {
                let x = size.width * (CGFloat(i) + 0.5) / CGFloat(count)
                positions[id] = CGPoint(x: x, y: y)
                xByNode[id] = x
            }
        }
        return positions
    }

    private func barycenter(_ id: AnyHashable, graph: WFGraph, x: [AnyHashable: CGFloat]) -> CGFloat {
        let ps = graph.parents(of: id).compactMap { x[$0] }
        guard !ps.isEmpty else { return .greatestFiniteMagnitude }
        return ps.reduce(0, +) / CGFloat(ps.count)
    }

    private func drawWorkflowZoneBoxes(_ graph: WFGraph, positions: [AnyHashable: CGPoint], into ctx: inout GraphicsContext) {
        var byZone: [ObjectIdentifier: (zone: Zone, points: [CGPoint])] = [:]
        for id in graph.order {
            guard let node = graph.nodes[id], node.kind == .provider,
                  let zone = node.zone, let p = positions[id] else { continue }
            byZone[ObjectIdentifier(zone), default: (zone, [])].points.append(p)
        }
        for (_, group) in byZone {
            guard let first = group.points.first else { continue }
            let pad = CanvasStyle.wfRadius + 16
            var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
            for p in group.points {
                minX = min(minX, p.x); maxX = max(maxX, p.x)
                minY = min(minY, p.y); maxY = max(maxY, p.y)
            }
            let rect = CGRect(x: minX - pad, y: minY - pad,
                              width: (maxX - minX) + pad * 2, height: (maxY - minY) + pad * 2)
            // Stroke only (no fill) so overlapping zone groups don't hide each
            // other's borders and labels.
            let path = Path(roundedRect: rect, cornerRadius: 14)
            ctx.stroke(path, with: .color(CanvasStyle.zoneStroke), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
            drawText(group.zone.name, at: CGPoint(x: rect.minX + 8, y: rect.minY + 6),
                     size: 11, weight: .semibold, color: .secondary, anchor: .topLeading, into: &ctx)
        }
    }
}

// MARK: - Shared drawing primitives

extension DesignCanvasView {

    fileprivate func drawNodeCircle(_ center: CGPoint, radius: CGFloat, fill: Color, stroke: Color,
                                    label: String, labelColor: Color, into ctx: inout GraphicsContext) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(fill))
        ctx.stroke(Path(ellipseIn: rect), with: .color(stroke), lineWidth: 1.5)
        if !label.isEmpty {
			drawText(label, at: center, size: 9, weight: .bold, color: labelColor, anchor: .center, into: &ctx)
        }
    }

    fileprivate func drawEdge(from a: CGPoint, to b: CGPoint, color: Color = CanvasStyle.edge, into ctx: inout GraphicsContext) {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.5))
    }

    fileprivate func drawArrowhead(at tip: CGPoint, direction d: CGPoint, size: CGFloat = 10, color: Color, into ctx: inout GraphicsContext) {
        let perp = CGPoint(x: -d.y, y: d.x)
        let base = tip - d * size
        var path = Path()
        path.move(to: tip)
        path.addLine(to: base + perp * (size * 0.5))
        path.addLine(to: base - perp * (size * 0.5))
        path.closeSubpath()
        ctx.fill(path, with: .color(color))
    }

    fileprivate func drawPill(_ s: String, at center: CGPoint, into ctx: inout GraphicsContext) {
        let resolved = ctx.resolve(Text(s).font(.system(size: 9)))
        let sz = resolved.measure(in: CGSize(width: 200, height: 40))
        let pad: CGFloat = 5
        let rect = CGRect(x: center.x - sz.width / 2 - pad, y: center.y - sz.height / 2 - pad,
                          width: sz.width + pad * 2, height: sz.height + pad * 2)
        let path = Path(roundedRect: rect, cornerRadius: 5)
        ctx.fill(path, with: .color(Color(.systemBackground)))
        ctx.stroke(path, with: .color(.gray), lineWidth: 1)
        ctx.draw(resolved, at: center, anchor: .center)
    }

    fileprivate func drawText(_ s: String, at p: CGPoint, size: CGFloat, weight: Font.Weight = .regular,
                              color: Color, anchor: UnitPoint = .center, into ctx: inout GraphicsContext) {
		var resolved = ctx.resolve(Text(s).font(.system(size: size, weight: weight))
			.foregroundStyle(Color.white))
		ctx.drawLayer { layer in
			layer.addFilter(.blur(radius: 1.2))
			layer.draw(resolved, at: p, anchor: anchor)
		}
		resolved = ctx.resolve(Text(s).font(.system(size: size, weight: weight)).foregroundStyle(color))
		ctx.draw(resolved, at: p, anchor: anchor)
    }

    /// Intersection of the segment from a rect's center towards `p` with the rect boundary.
    fileprivate func edgePoint(of rect: CGRect, towards p: CGPoint) -> CGPoint {
        let c = rect.center
        let d = p - c
        if d.x == 0 && d.y == 0 { return c }
        let halfW = rect.width / 2, halfH = rect.height / 2
        let scaleX = d.x == 0 ? CGFloat.greatestFiniteMagnitude : halfW / abs(d.x)
        let scaleY = d.y == 0 ? CGFloat.greatestFiniteMagnitude : halfH / abs(d.y)
        let scale = min(scaleX, scaleY)
        return CGPoint(x: c.x + d.x * scale, y: c.y + d.y * scale)
    }

    fileprivate func bezierPoint(_ a: CGPoint, _ control: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let mt = 1 - t
        let x = mt * mt * a.x + 2 * mt * t * control.x + t * t * b.x
        let y = mt * mt * a.y + 2 * mt * t * control.y + t * t * b.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Small helpers

private extension ComputeNode {
    /// CPU count to display: VMs report allocated virtual cores; hosts and
    /// clients report their hardware core count.
    var displayCpuCount: Int { type == .vm ? vCores : hwDef.cores }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

private extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (p: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: p.x * s, y: p.y * s) }

    var length: CGFloat { (x * x + y * y).squareRoot() }

    func normalized() -> CGPoint {
        let len = length
        return len == 0 ? .zero : CGPoint(x: x / len, y: y / len)
    }
}

// MARK: - Previews

@MainActor
private func sampleContainer() -> ModelContainer {
    let container = try! ModelContainer(
        for: Design.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let design = Design(name: "Sample Deployment", desc: "")
    ctx.insert(design)

    let serverHW = HardwareDef(processor: "Xeon Gold 6338", cores: 16, specIntRate2017: 160)
    let clientHW = HardwareDef(processor: "Core i7", cores: 8, specIntRate2017: 80)

    let local = Zone(name: "Local Zone", description: "On-prem")
    let dmz = Zone(name: "DMZ Zone", description: "Edge")
    design.addZone(local, localBandwidthMbps: 10_000, localLatencyMS: 0)
    design.addZone(dmz, localBandwidthMbps: 1_000, localLatencyMS: 1)
    design.addConnection(local.connect(to: dmz, bandwidth: 500, latency: 2), addReciprocal: true)

    let host = ComputeNode(name: "Local Server", desc: "", hwDef: serverHW, memoryGB: 128, zone: local, type: .host)
    ctx.insert(host)
    design.addCompute(host)
    let vmWeb = host.addVirtualMachine(name: "VMWeb", vCores: 4, memoryGB: 16)
    let vmSQL = host.addVirtualMachine(name: "VMSQL", vCores: 4, memoryGB: 32)

    let client = ComputeNode(name: "Client PC", desc: "", hwDef: clientHW, memoryGB: 16, zone: local, type: .client)
    ctx.insert(client)
    design.addCompute(client)

    let edge = ComputeNode(name: "Edge Server", desc: "", hwDef: serverHW, memoryGB: 64, zone: dmz, type: .host)
    ctx.insert(edge)
    design.addCompute(edge)
    let vmMap = edge.addVirtualMachine(name: "VMMap", vCores: 4, memoryGB: 16)

    func service(_ name: String, _ type: String, _ model: BalancingModel = .single) -> ServiceDef {
        ServiceDef(name: name, desc: "", serviceType: type, balancingModel: model)
    }
    let clientSP = ServiceProvider(name: "Client Service 002", desc: "", service: service("Client", "client"))
    clientSP.addNode(client)
    let webSP = ServiceProvider(name: "Web Service 001", desc: "", service: service("Web", "web"))
    webSP.addNode(vmWeb)
    let portalSP = ServiceProvider(name: "Portal Service 001", desc: "", service: service("Portal", "portal"))
    portalSP.addNode(vmWeb)
    let hostedSP = ServiceProvider(name: "Hosted Service 001", desc: "", service: service("Hosted", "hosted"))
    hostedSP.addNode(vmSQL)
    let mapSP = ServiceProvider(name: "Map Service 002", desc: "", service: service("Map", "map", .roundRobin))
    mapSP.addNode(vmMap)
    mapSP.addNode(vmSQL) // spans two zones -> cross-box link
    for sp in [clientSP, webSP, portalSP, hostedSP, mapSP] {
        ctx.insert(sp)
        design.addServiceProvider(sp)
    }

    func step(_ name: String, _ type: String, _ ds: DataSourceType = .none) -> WorkflowDefStep {
        WorkflowDefStep(name: name, desc: "", serviceType: type, serviceTime: 10, chatter: 1,
                        requestSizeKB: 10, responseSizeKB: 20, dataSourceType: ds, cachePercent: 0)
    }
    let shared = [step("Client", "client"), step("Web", "web"), step("Portal", "portal")]
    let chainA = WorkflowChain(name: "Browser Web Hosted", description: "",
                               steps: shared + [step("Hosted", "hosted", .relational)],
                               serviceProviders: ["client": clientSP, "web": webSP, "portal": portalSP, "hosted": hostedSP])
    let chainB = WorkflowChain(name: "Browser Basemap", description: "",
                               steps: shared + [step("Map", "map", .file)],
                               serviceProviders: ["client": clientSP, "web": webSP, "portal": portalSP, "map": mapSP])
    ctx.insert(chainA)
    ctx.insert(chainB)
    let def = WorkflowDef(name: "Simple Viewer Web App", desc: "", thinkTimeSeconds: 6, chains: [chainA, chainB])
    ctx.insert(def)
    design.addWorkflowDefinition(def)
    _ = design.addUserWorkflow(name: "Web Workflow", description: "", wdefName: def.name, users: 100, productivity: 10)

    try? ctx.save()
    return container
}

@MainActor
private func sampleDesign(_ container: ModelContainer) -> Design {
    try! container.mainContext.fetch(FetchDescriptor<Design>()).first!
}

#Preview("Compute") {
    let container = sampleContainer()
    DesignCanvasView(design: sampleDesign(container), initialMode: .compute)
        .modelContainer(container)
        .frame(width: 700, height: 500)
}

#Preview("Service Providers") {
    let container = sampleContainer()
    DesignCanvasView(design: sampleDesign(container), initialMode: .serviceProviders)
        .modelContainer(container)
        .frame(width: 700, height: 500)
}

#Preview("Workflow") {
    let container = sampleContainer()
    DesignCanvasView(design: sampleDesign(container), initialMode: .workflow)
        .modelContainer(container)
        .frame(width: 700, height: 640)
}
