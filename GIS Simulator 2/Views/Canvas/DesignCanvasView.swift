//
//  DesignCanvasView.swift
//  GIS Simulator 2
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// The three ways to visualise a design. The network (zones + connections) is
/// not its own mode; it appears inside each mode as zone boundary boxes.
enum CanvasMode: String, CaseIterable, Identifiable {
    case compute
    case workflow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .compute:  return "Compute"
        case .workflow: return "Workflow"
        }
    }
}

struct DesignCanvasView: View {
    let design: Design?
    @State private var mode: CanvasMode
    @State private var showProviders = true

    // Compute-mode viewport. The diagram is laid out at its natural size and
    // then scaled to fit, so `zoom` is a multiple of that fit scale (1 = whole
    // diagram visible) and `pan` is a view-space offset on top of it.
    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var dragOffset: CGSize = .zero

    init(design: Design?, initialMode: CanvasMode = .compute) {
        self.design = design
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        Canvas { context, size in
            guard let design else { return }
            switch mode {
            case .compute:
                drawZonedCompute(design, into: &context, size: size, showProviders: showProviders,
                                 zoom: zoom * pinch, pan: pan + dragOffset)
            case .workflow: drawWorkflow(design, into: &context, size: size)
            }
        } symbols: {
            // One icon per service type present in the design, resolved by the
            // service type string. Types without a matching asset fall back to
            // "Custom". These are drawn centered inside each provider node.
            ForEach(serviceTypes, id: \.self) { type in
                Image(iconAssetName(for: type))
                    .resizable()
                    .scaledToFit()
                    .frame(width: CanvasStyle.providerRadius * 1.3,
                           height: CanvasStyle.providerRadius * 1.3)
                    .tag(type)
            }
        }
        .background(Color(.systemBackground))
        .onTapGesture(count: 2) { resetViewport() }
        .gesture(magnifyGesture, isEnabled: mode == .compute)
        .simultaneousGesture(panGesture, isEnabled: mode == .compute)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { viewSize = $0 }
        .onChange(of: mode) { resetViewport() }
        .onChange(of: design?.persistentModelID) { resetViewport() }
        .overlay(alignment: .top) {
            HStack(spacing: 10) {
                Picker("View", selection: $mode) {
                    ForEach(CanvasMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()

                if mode == .compute {
                    Toggle("Service Providers", isOn: $showProviders)
                        .toggleStyle(.switch)
                        .fixedSize()

                    if isZoomed {
                        Button("Fit", systemImage: "arrow.up.left.and.down.right.magnifyingglass") {
                            resetViewport()
                        }
                        .buttonStyle(.bordered)
                        .fixedSize()
                    }
                }
            }
            .padding(6)
            .background(.thinMaterial, in: Capsule())
            .padding(.top, 8)
        }
//        .overlay(alignment: .topLeading) {
//            if let design {
//                Text(design.name)
//                    .font(.headline)
//                    .padding(8)
//                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
//                    .padding()
//            }
//        }
        .overlay {
            if let message = emptyMessage {
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Viewport

    private var isZoomed: Bool { abs(zoom - 1) > 0.001 || pan != .zero }

    /// Back to scale-to-fit, centered.
    private func resetViewport() {
        zoom = 1
        pan = .zero
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($pinch) { value, state, _ in state = value.magnification }
            .onEnded { value in
                zoom = clampZoom(zoom * value.magnification)
                pan = clampPan(pan)
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in state = value.translation }
            .onEnded { value in
                pan = clampPan(pan + value.translation)
            }
    }

    /// Limits the pan to however much of the scaled diagram overflows the
    /// viewport, so it can never be dragged out of sight. Collapses to zero
    /// once the whole diagram fits.
    private func clampPan(_ offset: CGSize) -> CGSize {
        guard let design, mode == .compute else { return .zero }
        let content = computeLayout(design).contentSize
        let viewport = computeViewport(in: viewSize)
        let scale = fitScale(content: content, in: viewport.size) * clampZoom(zoom)
        let slackX = max(0, (content.width * scale - viewport.width) / 2)
        let slackY = max(0, (content.height * scale - viewport.height) / 2)
        return CGSize(width: min(max(offset.width, -slackX), slackX),
                      height: min(max(offset.height, -slackY), slackY))
    }

    /// Distinct service types across every provider in the design, used to build
    /// the canvas symbol set.
    private var serviceTypes: [String] {
        guard let design else { return [] }
        return Array(Set(design.serviceProviders.map(\.service.serviceType))).sorted()
    }

    /// Asset name for a service type. Service types are stored lowercase
    /// (e.g. "web", "dbms") while the catalog assets are cased (e.g. "Web",
    /// "DBMS"), so we probe the common case variants and fall back to the
    /// shared "Custom" icon when none exist.
    private func iconAssetName(for serviceType: String) -> String {
        let candidates = [serviceType, serviceType.capitalized, serviceType.uppercased()]
        return candidates.first(where: assetExists) ?? "Custom"
    }

    private func assetExists(_ name: String) -> Bool {
        #if canImport(UIKit)
        return UIImage(named: name) != nil
        #else
        return NSImage(named: name) != nil
        #endif
    }

    private var emptyMessage: String? {
        guard let design else { return "Select a design" }
        switch mode {
        case .compute:
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

    // Compute-mode label metrics. `footprint(of:)` reserves space from these
    // and `drawComputeNode` draws with them, so they have to stay in step.
    static let nodeNameSize: CGFloat = 17
    static let nodeSpecSize: CGFloat = 15
    static let providerNameSize: CGFloat = 14
    static let zoneNameSize: CGFloat = 20
    static let zoneDetailSize: CGFloat = 15
    static let connectionLabelSize: CGFloat = 15
    /// Offset of the first caption line below a node's center, and the spacing
    /// between caption lines.
    static let captionLead: CGFloat = 15
    static let captionLine: CGFloat = 18

    // Natural-size compute layout metrics (content coordinates)
    static let outerPad: CGFloat = 24
    static let zoneGap: CGFloat = 64
    static let nodeGap: CGFloat = 16
    static let zoneInset = EdgeInsets(top: 60, leading: 14, bottom: 14, trailing: 14)
    static let minZoneSize = CGSize(width: 260, height: 170)
    /// Room reserved per service provider (circle plus its name) when sizing a
    /// zone; providers float into the slack left around the node grid.
    static let providerCell: CGFloat = 96
    /// How far scale-to-fit may magnify a diagram smaller than the canvas.
    static let maxFitScale: CGFloat = 1.6
    static let maxZoom: CGFloat = 8
}

// MARK: - Compute / Service Providers

private struct NodePlacement {
    let center: CGPoint
    let radius: CGFloat
    /// Region the node is kept inside during overlap resolution (its zone box).
    let bounds: CGRect
}

/// One circle fed to the overlap-resolution pass. Compute nodes spring back
/// toward their grid/ring slot (`anchorStrength > 0`); providers float freely.
private struct LayoutCircle {
    let id: ObjectIdentifier
    var center: CGPoint
    let radius: CGFloat
    /// Radius used for collisions. Larger than the drawn circle so the
    /// captions printed beneath a node keep other circles at arm's length.
    let layoutRadius: CGFloat
    let anchor: CGPoint
    let anchorStrength: CGFloat
    let bounds: CGRect
}

/// How one zone's contents pack: the grid its host/client clusters sit in, the
/// cell each needs (captions included) and the VM ring radius per host.
private struct ZonePlan {
    var units: [ComputeNode] = []
    var cols = 1
    var rows = 1
    var cellW: CGFloat = 0
    var cellH: CGFloat = 0
    var ringRadius: [ObjectIdentifier: CGFloat] = [:]
    /// Room the zone's contents need inside its box: the node grid, grown for
    /// the service providers that have to fit around it.
    var innerSize: CGSize = .zero
}

/// The compute diagram at its natural size: zone rects in content coordinates
/// plus the overall size needed to draw it without crowding. The canvas scales
/// this to fit, so a busier design shrinks uniformly instead of squeezing.
private struct ComputeLayout {
    let contentSize: CGSize
    let zoneRects: [ObjectIdentifier: CGRect]
    let plans: [ObjectIdentifier: ZonePlan]
}

extension DesignCanvasView {

    /// Draws the zone boxes, inter-zone connection arrows and the compute nodes
    /// inside their zone. When `showProviders` is true it also overlays the
    /// service-provider nodes and their links.
    ///
    /// The diagram is laid out at its natural size (zones sized to their
    /// contents) and then drawn through a single scale-to-fit transform, so
    /// circles, captions and spacing all shrink together as the design grows.
    /// `zoom` multiplies that fit scale and `pan` offsets it.
    fileprivate func drawZonedCompute(_ design: Design, into ctx: inout GraphicsContext, size: CGSize,
                                      showProviders: Bool, zoom: CGFloat, pan: CGSize) {
        let layout = computeLayout(design)
        guard layout.contentSize.width > 1, layout.contentSize.height > 1 else { return }

        let viewport = computeViewport(in: size)
        let scale = fitScale(content: layout.contentSize, in: viewport.size) * clampZoom(zoom)
        let scaled = CGSize(width: layout.contentSize.width * scale,
                            height: layout.contentSize.height * scale)
        let slackX = max(0, (scaled.width - viewport.width) / 2)
        let slackY = max(0, (scaled.height - viewport.height) / 2)
        ctx.translateBy(x: viewport.midX - scaled.width / 2 + min(max(pan.width, -slackX), slackX),
                        y: viewport.midY - scaled.height / 2 + min(max(pan.height, -slackY), slackY))
        ctx.scaleBy(x: scale, y: scale)

        let regions = layout.zoneRects

        // 1. Zone boxes
        for zone in design.zones {
            if let rect = regions[ObjectIdentifier(zone)] {
                drawZoneBox(zone, in: rect, network: design.network, into: &ctx)
            }
        }

        // 2. Inter-zone connection arrows
        drawConnectionArrows(design, regions: regions, into: &ctx)

        // 3. Place all compute nodes (hosts, clients, vms) at their ideal slot
        let placements = placeComputeNodes(design, layout: layout)

        // 4. Seed provider positions. A provider on a single node is fanned out
        // on an arc just outside that node, so siblings start spread around it
        // instead of stacked in one column; a round-robin / failover provider
        // starts at the centroid of the nodes it connects to. Providers whose
        // nodes all live in one zone are confined to that zone's box; one that
        // spans zones may float anywhere so its links can cross boxes.
        let drawable = CGRect(origin: .zero, size: layout.contentSize)
        var providerInit: [ObjectIdentifier: (position: CGPoint, bounds: CGRect)] = [:]
        if showProviders {
            var hostOfVM: [ObjectIdentifier: ComputeNode] = [:]
            for host in design.physicalComputeNodes {
                for vm in host.vmList { hostOfVM[ObjectIdentifier(vm)] = host }
            }
            // Fan width depends on how many providers share a node, so count
            // them up front and then walk the providers in their stable order.
            var totals: [ObjectIdentifier: Int] = [:]
            for sp in design.serviceProviders {
                let placed = sp.nodes.filter { placements[ObjectIdentifier($0)] != nil }
                if placed.count == 1 { totals[ObjectIdentifier(placed[0]), default: 0] += 1 }
            }

            var seeded: [ObjectIdentifier: Int] = [:]
            for sp in design.serviceProviders {
                let placed = sp.nodes.filter { placements[ObjectIdentifier($0)] != nil }
                guard !placed.isEmpty else { continue }

                let pos: CGPoint
                if placed.count == 1, let p = placements[ObjectIdentifier(placed[0])] {
                    let node = placed[0]
                    let key = ObjectIdentifier(node)
                    let index = seeded[key, default: 0]
                    seeded[key] = index + 1
                    let plan = layout.plans[ObjectIdentifier(node.zone)]
                    pos = providerSeed(node: node, placement: p, index: index, total: totals[key] ?? 1,
                                       clusterCenter: hostOfVM[key].flatMap { placements[ObjectIdentifier($0)]?.center },
                                       ringRadius: plan?.ringRadius[key],
                                       badge: providerBadge(sp))
                } else {
                    let centers = placed.compactMap { placements[ObjectIdentifier($0)]?.center }
                    pos = centers.reduce(.zero, +) * (1 / CGFloat(centers.count))
                }

                let zones = Set(sp.nodes.map { ObjectIdentifier($0.zone) })
                let bounds = zones.count == 1
                    ? (zones.first.flatMap { regions[$0] }?.inset(by: CanvasStyle.zoneInset) ?? drawable)
                    : drawable
                providerInit[ObjectIdentifier(sp)] = (pos, bounds)
            }
        }

        // 5. Resolve overlaps across every circle (nodes lightly anchored to
        // their slot, providers free), in a stable order for determinism.
        var circles: [LayoutCircle] = []
        for node in design.allComputeNodes {
            if let p = placements[ObjectIdentifier(node)] {
                // Collide on the caption block, not just the disc, so nothing
                // settles on top of a node's name and spec lines.
                let f = footprint(of: node)
                circles.append(LayoutCircle(id: ObjectIdentifier(node), center: p.center, radius: p.radius,
                                            layoutRadius: max(p.radius, min(f.width, f.height)) + 6,
                                            anchor: p.center, anchorStrength: 0.2, bounds: p.bounds))
            }
        }
        for sp in design.serviceProviders {
            if let seed = providerInit[ObjectIdentifier(sp)] {
                // Collide on the name badge under the circle too, so provider
                // captions don't end up printed on top of each other.
                let badge = providerBadge(sp)
                circles.append(LayoutCircle(id: ObjectIdentifier(sp), center: seed.position,
                                            radius: CanvasStyle.providerRadius,
                                            layoutRadius: max(CanvasStyle.providerRadius + 8,
                                                              min(badge.width, badge.height)),
                                            anchor: seed.position, anchorStrength: 0, bounds: seed.bounds))
            }
        }
        resolveOverlaps(&circles)
        var resolved: [ObjectIdentifier: CGPoint] = [:]
        for c in circles { resolved[c.id] = c.center }

        // 6. Host -> VM edges
        for host in design.physicalComputeNodes where host.type == .host {
            guard let hc = resolved[ObjectIdentifier(host)] else { continue }
            for vm in host.vmList {
                if let vc = resolved[ObjectIdentifier(vm)] {
                    drawEdge(from: hc, to: vc, into: &ctx)
                }
            }
        }

        // 7. Provider links behind the nodes — one edge to every node the
        // provider runs on (crossing zone boxes for multi-zone providers).
        if showProviders {
            for sp in design.serviceProviders {
                guard let pos = resolved[ObjectIdentifier(sp)] else { continue }
                for node in sp.nodes {
                    if let target = resolved[ObjectIdentifier(node)] {
                        drawEdge(from: pos, to: target, into: &ctx)
                    }
                }
            }
        }

        // 8. Compute node circles + captions
        for node in design.allComputeNodes {
            if let p = placements[ObjectIdentifier(node)], let center = resolved[ObjectIdentifier(node)] {
                drawComputeNode(node, at: center, radius: p.radius, into: &ctx)
            }
        }

        // 9. Provider circles on top, name below
        if showProviders {
            for sp in design.serviceProviders {
                if let pos = resolved[ObjectIdentifier(sp)] {
                    // White disc with an accent-colored outline and the service
                    // type icon centered inside it.
                    drawNodeCircle(pos, radius: CanvasStyle.providerRadius, fill: .white,
                                   stroke: .accentColor, label: "", labelColor: .clear, into: &ctx)
                    if let icon = ctx.resolveSymbol(id: sp.service.serviceType) {
                        ctx.draw(icon, at: pos)
                    }
                    drawText(sp.name, at: CGPoint(x: pos.x, y: pos.y + CanvasStyle.providerRadius + 4),
                             size: CanvasStyle.providerNameSize, weight: .semibold, color: .primary,
                             anchor: .top, into: &ctx)
                }
            }
        }
    }

    // MARK: Natural-size layout

    /// Area of the canvas the diagram is fitted into, below the mode picker.
    fileprivate func computeViewport(in size: CGSize) -> CGRect {
        CGRect(x: 0, y: CanvasStyle.topInset,
               width: max(1, size.width), height: max(1, size.height - CanvasStyle.topInset))
    }

    /// Uniform scale that brings the natural-size diagram inside the viewport.
    /// A sparse diagram is allowed to grow a little so it isn't lost in a large
    /// canvas, but not so far that the captions look oversized.
    fileprivate func fitScale(content: CGSize, in size: CGSize) -> CGFloat {
        guard content.width > 0, content.height > 0 else { return 1 }
        return min(CanvasStyle.maxFitScale,
                   min(size.width / content.width, size.height / content.height))
    }

    fileprivate func clampZoom(_ z: CGFloat) -> CGFloat {
        min(max(z.isFinite ? z : 1, 1), CanvasStyle.maxZoom)
    }

    /// Lays the zones out in a grid whose columns are as wide as their widest
    /// zone and rows as tall as their tallest, so a zone holding one client
    /// stays small while a dense one gets the room it needs. The result is in
    /// content coordinates, independent of the canvas size.
    fileprivate func computeLayout(_ design: Design) -> ComputeLayout {
        let zones = design.zones
        guard !zones.isEmpty else {
            return ComputeLayout(contentSize: CGSize(width: 1, height: 1), zoneRects: [:], plans: [:])
        }

        var plans: [ObjectIdentifier: ZonePlan] = [:]
        var boxes: [CGSize] = []
        for zone in zones {
            let plan = zonePlan(for: zone, in: design)
            plans[ObjectIdentifier(zone)] = plan
            let insets = CanvasStyle.zoneInset
            boxes.append(CGSize(
                width: max(CanvasStyle.minZoneSize.width,
                           plan.innerSize.width + insets.leading + insets.trailing),
                height: max(CanvasStyle.minZoneSize.height,
                            plan.innerSize.height + insets.top + insets.bottom)))
        }

        let cols = max(1, Int(ceil(sqrt(Double(zones.count)))))
        let rows = max(1, Int(ceil(Double(zones.count) / Double(cols))))
        var colW = [CGFloat](repeating: 0, count: cols)
        var rowH = [CGFloat](repeating: 0, count: rows)
        for (i, box) in boxes.enumerated() {
            colW[i % cols] = max(colW[i % cols], box.width)
            rowH[i / cols] = max(rowH[i / cols], box.height)
        }

        let pad = CanvasStyle.outerPad, gap = CanvasStyle.zoneGap
        var rects: [ObjectIdentifier: CGRect] = [:]
        var y = pad
        for r in 0..<rows {
            var x = pad
            for c in 0..<cols {
                let i = r * cols + c
                if i < zones.count {
                    rects[ObjectIdentifier(zones[i])] = CGRect(x: x, y: y, width: colW[c], height: rowH[r])
                }
                x += colW[c] + gap
            }
            y += rowH[r] + gap
        }

        let content = CGSize(width: pad * 2 + colW.reduce(0, +) + gap * CGFloat(cols - 1),
                             height: pad * 2 + rowH.reduce(0, +) + gap * CGFloat(rows - 1))
        return ComputeLayout(contentSize: content, zoneRects: rects, plans: plans)
    }

    /// Works out the grid one zone's hosts and clients pack into, sizing every
    /// cell to the largest host+VM cluster *including its captions*, then grows
    /// the zone by the area its service providers need.
    fileprivate func zonePlan(for zone: Zone, in design: Design) -> ZonePlan {
        var plan = ZonePlan()
        plan.units = design.physicalComputeNodes.filter { $0.zone === zone }
        guard !plan.units.isEmpty else { return plan }

        let gap = CanvasStyle.nodeGap
        for unit in plan.units {
            let own = footprint(of: unit)
            var halfW = own.width, halfH = own.height

            if unit.type == .host, !unit.vmList.isEmpty {
                // Ring the VMs out far enough that neighbouring VMs — captions
                // and all — clear each other and the host's own caption.
                let vm = unit.vmList.reduce(CGSize.zero) { widest, next in
                    let f = footprint(of: next)
                    return CGSize(width: max(widest.width, f.width), height: max(widest.height, f.height))
                }
                let count = unit.vmList.count
                let chord = count > 1 ? (vm.width + gap) / sin(.pi / CGFloat(count)) : 0
                let ring = max(CanvasStyle.hostRadius + vm.height + gap, chord)
                plan.ringRadius[ObjectIdentifier(unit)] = ring
                halfW = max(halfW, ring + vm.width)
                halfH = max(halfH, ring + vm.height)
            }

            // Providers settle around the cluster they run on, so add a band
            // outside it for them — per axis, so a wide caption doesn't force a
            // tall cell too — and check the ring is long enough to hold them all.
            let providers = providerCount(for: unit, in: design)
            if providers > 0 {
                let band = CanvasStyle.providerCell * 0.75
                let minRing = CGFloat(providers) * CanvasStyle.providerCell / (2 * .pi)
                halfW = max(halfW + band, minRing)
                halfH = max(halfH + band, minRing)
            }

            plan.cellW = max(plan.cellW, 2 * halfW + gap)
            plan.cellH = max(plan.cellH, 2 * halfH + gap)
        }

        let n = plan.units.count
        plan.cols = max(1, Int(ceil(sqrt(Double(n)))))
        plan.rows = max(1, Int(ceil(Double(n) / Double(plan.cols))))
        plan.innerSize = CGSize(width: plan.cellW * CGFloat(plan.cols),
                                height: plan.cellH * CGFloat(plan.rows))
        return plan
    }

    /// Starting point for a provider that runs on one node: on an arc outside
    /// that node — beyond the VM ring for a host that has one — centered on the
    /// direction leading away from the cluster, with siblings fanned to either
    /// side. `clusterCenter` is the host center when the node is a VM.
    fileprivate func providerSeed(node: ComputeNode, placement: NodePlacement, index: Int, total: Int,
                                  clusterCenter: CGPoint?, ringRadius: CGFloat?, badge: CGSize) -> CGPoint {
        let clearance = CanvasStyle.providerRadius + CanvasStyle.providerNameSize + 10
        let caption = footprint(of: node)
        let inner = ringRadius.map { $0 + CanvasStyle.vmRadius } ?? placement.radius

        // Point away from the host for a VM; straight up for anything else.
        var outward = clusterCenter.map { (placement.center - $0).normalized() } ?? .zero
        if outward == .zero { outward = CGPoint(x: 0, y: -1) }

        // Fan the siblings out, then push each one clear of the node's caption
        // block in its own direction, allowing for the width of its own name
        // badge. Captions are far wider than they are tall, so a provider off to
        // the side ends up much further out than one directly above.
        let step = min(2 * .pi / CGFloat(max(total, 1)),
                       CanvasStyle.providerCell * 1.5 / max(inner + clearance, 1))
        let angle = atan2(outward.y, outward.x) + step * (CGFloat(index) - CGFloat(total - 1) / 2)
        let dx = abs(cos(angle)), dy = abs(sin(angle))
        let keepOut = min(dx > 0.0001 ? (caption.width + badge.width) / dx : .greatestFiniteMagnitude,
                          dy > 0.0001 ? (caption.height + badge.height) / dy : .greatestFiniteMagnitude)
        let radius = max(inner + clearance, keepOut)
        return placement.center + CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
    }

    /// Half-extents of a provider's circle plus the name printed below it.
    fileprivate func providerBadge(_ sp: ServiceProvider) -> CGSize {
        CGSize(width: max(CanvasStyle.providerRadius,
                          textWidth(sp.name, size: CanvasStyle.providerNameSize) / 2) + 6,
               height: CanvasStyle.providerRadius + CanvasStyle.providerNameSize + 6)
    }

    /// Providers that draw a link to this host, its VMs, or this client.
    fileprivate func providerCount(for unit: ComputeNode, in design: Design) -> Int {
        let cluster = Set(([unit] + unit.vmList).map { ObjectIdentifier($0) })
        return design.serviceProviders.filter { sp in
            sp.nodes.contains { cluster.contains(ObjectIdentifier($0)) }
        }.count
    }

    /// Half-width and half-height a node occupies, captions included. The name
    /// and spec lines are much wider than the circles, so they — not the radii —
    /// decide how much room a node needs.
    fileprivate func footprint(of node: ComputeNode) -> CGSize {
        let radius = node.type == .vm ? CanvasStyle.vmRadius : CanvasStyle.hostRadius
        var widest = textWidth(node.name, size: CanvasStyle.nodeNameSize)
        if node.type != .vm {
            widest = max(widest, textWidth(node.hwDef.processor, size: CanvasStyle.nodeSpecSize))
        }
        widest = max(widest, textWidth("\(node.displayCpuCount) CPU · \(node.memoryGB) GB",
                                       size: CanvasStyle.nodeSpecSize))
        let captionLines = node.type == .vm ? 1 : 2
        return CGSize(width: max(radius, widest / 2),
                      height: max(radius, CanvasStyle.captionLead
                                          + CGFloat(captionLines) * CanvasStyle.captionLine))
    }

    /// Approximate width of a drawn string. Canvas text can only be measured
    /// through a GraphicsContext, and layout runs before drawing, so estimate
    /// from the character count (the system font averages a little over half
    /// its point size per character).
    fileprivate func textWidth(_ s: String, size: CGFloat) -> CGFloat {
        CGFloat(s.count) * size * 0.55
    }

    fileprivate func drawZoneBox(_ zone: Zone, in rect: CGRect, network: [Connection], into ctx: inout GraphicsContext) {
        let path = Path(roundedRect: rect, cornerRadius: 24)
        ctx.fill(path, with: .color(CanvasStyle.zoneFill))
        ctx.stroke(path, with: .color(CanvasStyle.zoneStroke), lineWidth: 1.5)
        drawText(zone.name, at: CGPoint(x: rect.minX + 18, y: rect.minY + 9),
                 size: CanvasStyle.zoneNameSize, weight: .semibold, color: .primary, anchor: .topLeading, into: &ctx)
        if let local = zone.localConnection(in: network) {
            drawText("local \(local.bandwidthMbps)/\(local.latencyMs)",
                     at: CGPoint(x: rect.minX + 18, y: rect.minY + 34),
                     size: CanvasStyle.zoneDetailSize, color: .secondary, anchor: .topLeading, into: &ctx)
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

    /// Grid-packs each zone's hosts and clients into its box and rings each
    /// host's VMs around it, using the cell sizes and ring radii the layout
    /// already reserved room for. No positions are squeezed here: the zone box
    /// is guaranteed to be big enough, so these are both the *ideal* anchors
    /// and, for nodes, very nearly the final positions.
    fileprivate func placeComputeNodes(_ design: Design, layout: ComputeLayout) -> [ObjectIdentifier: NodePlacement] {
        var placements: [ObjectIdentifier: NodePlacement] = [:]

        for zone in design.zones {
            guard let rect = layout.zoneRects[ObjectIdentifier(zone)],
                  let plan = layout.plans[ObjectIdentifier(zone)], !plan.units.isEmpty else { continue }

            let inner = rect.inset(by: CanvasStyle.zoneInset)
            let originX = inner.midX - plan.cellW * CGFloat(plan.cols) / 2
            let originY = inner.midY - plan.cellH * CGFloat(plan.rows) / 2

            for (i, unit) in plan.units.enumerated() {
                let r = i / plan.cols, c = i % plan.cols
                let center = CGPoint(x: originX + (CGFloat(c) + 0.5) * plan.cellW,
                                     y: originY + (CGFloat(r) + 0.5) * plan.cellH)
                placements[ObjectIdentifier(unit)] = NodePlacement(center: center, radius: CanvasStyle.hostRadius, bounds: inner)

                if let ringR = plan.ringRadius[ObjectIdentifier(unit)] {
                    for (j, vm) in unit.vmList.enumerated() {
                        let a = -CGFloat.pi / 2 + 2 * .pi * CGFloat(j) / CGFloat(unit.vmList.count)
                        let p = CGPoint(x: center.x + ringR * cos(a), y: center.y + ringR * sin(a))
                        placements[ObjectIdentifier(vm)] = NodePlacement(center: p, radius: CanvasStyle.vmRadius, bounds: inner)
                    }
                }
            }
        }
        return placements
    }

    /// Iteratively pushes overlapping circles apart. Compute nodes spring back
    /// toward their anchor (grid/ring slot) so the layout stays legible;
    /// providers (`anchorStrength == 0`) float freely to the gaps. Deterministic:
    /// the caller supplies circles in a stable order.
    fileprivate func resolveOverlaps(_ circles: inout [LayoutCircle], iterations: Int = 60) {
        let spacing: CGFloat = 6
        func mobility(_ c: LayoutCircle) -> CGFloat { c.anchorStrength > 0 ? 0.5 : 1.0 }
        func clamped(_ p: CGPoint, in b: CGRect, radius r: CGFloat) -> CGPoint {
            let minX = b.minX + r, maxX = b.maxX - r
            let minY = b.minY + r, maxY = b.maxY - r
            return CGPoint(x: minX <= maxX ? min(max(p.x, minX), maxX) : b.midX,
                           y: minY <= maxY ? min(max(p.y, minY), maxY) : b.midY)
        }

        guard circles.count > 0 else { return }
        for _ in 0..<iterations {
            for i in 0..<circles.count {
                for j in (i + 1)..<circles.count {
                    let a = circles[i], b = circles[j]
                    let delta = b.center - a.center
                    let dist = delta.length
                    let minDist = a.layoutRadius + b.layoutRadius + spacing
                    guard dist < minDist else { continue }
                    let overlap = minDist - dist
                    let dir = dist > 0.0001 ? delta.normalized() : CGPoint(x: 1, y: 0)
                    let ma = mobility(a), mb = mobility(b)
                    let total = ma + mb
                    guard total > 0 else { continue }
                    circles[i].center = a.center - dir * (overlap * ma / total)
                    circles[j].center = b.center + dir * (overlap * mb / total)
                }
            }
            for i in 0..<circles.count {
                let c = circles[i]
                var p = c.center
                if c.anchorStrength > 0 {
                    p = p + (c.anchor - p) * c.anchorStrength
                }
                circles[i].center = clamped(p, in: c.bounds, radius: c.radius)
            }
        }
    }

    fileprivate func drawComputeNode(_ node: ComputeNode, at center: CGPoint, radius: CGFloat, into ctx: inout GraphicsContext) {
        // Color conveys the type; name and spec go below to stay legible in the
        // small circles.
        drawNodeCircle(center, radius: radius, fill: fillColor(for: node.type), stroke: .white,
                       label: "", labelColor: .clear, into: &ctx)
        drawText(node.name, at: CGPoint(x: center.x, y: center.y - 8),
				 size: CanvasStyle.nodeNameSize, weight: .bold, color: .primary, anchor: .center, into: &ctx)

        var y = center.y + CanvasStyle.captionLead
		if node.type != .vm {
			let spec = node.hwDef.processor
			drawText(spec, at: CGPoint(x: center.x, y: y),
					 size: CanvasStyle.nodeSpecSize, weight: .semibold, color: .primary, anchor: .center, into: &ctx)
			y += CanvasStyle.captionLine
		}
        let spec = "\(node.displayCpuCount) CPU · \(node.memoryGB) GB"
        drawText(spec, at: CGPoint(x: center.x, y: y),
				 size: CanvasStyle.nodeSpecSize, weight: .semibold, color: .primary, anchor: .center, into: &ctx)
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

    fileprivate func drawPill(_ s: String, at center: CGPoint,
                              size: CGFloat = CanvasStyle.connectionLabelSize,
                              into ctx: inout GraphicsContext) {
        let resolved = ctx.resolve(Text(s).font(.system(size: size)))
        let sz = resolved.measure(in: CGSize(width: 300, height: 60))
        let pad: CGFloat = 6
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

    func inset(by insets: EdgeInsets) -> CGRect {
        CGRect(x: minX + insets.leading, y: minY + insets.top,
               width: max(1, width - insets.leading - insets.trailing),
               height: max(1, height - insets.top - insets.bottom))
    }
}

private extension CGSize {
    static func + (a: CGSize, b: CGSize) -> CGSize {
        CGSize(width: a.width + b.width, height: a.height + b.height)
    }
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

/// A zone dense enough to exercise the scale-to-fit layout: several hosts with
/// long hardware names and a pile of providers on each.
@MainActor
private func busyContainer() -> ModelContainer {
    let container = try! ModelContainer(
        for: Design.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext
    let design = Design(name: "ArcGIS Online", desc: "")
    ctx.insert(design)

    let zone = Zone(name: "ArcGIS Online", description: "SaaS")
    design.addZone(zone, localBandwidthMbps: 10_000, localLatencyMS: 0)
    let hw = HardwareDef(processor: "AMI db.r3.8xlarge (32vc)", cores: 16, specIntRate2017: 160)

    let types = ["portal", "dbms", "gis", "file", "map", "edge"]
    for h in 1...3 {
        let host = ComputeNode(name: "ArcGIS Online Host \(h)", desc: "", hwDef: hw,
                               memoryGB: 244, zone: zone, type: .host)
        ctx.insert(host)
        design.addCompute(host)
        for type in types.prefix(h == 1 ? 3 : 2) {
            let sp = ServiceProvider(name: "AGOL \(type.capitalized)", desc: "",
                                     service: ServiceDef(name: type.capitalized, desc: "",
                                                         serviceType: type, balancingModel: .single))
            ctx.insert(sp)
            try? ctx.save()
            sp.addNode(host)
            design.addServiceProvider(sp)
            try? ctx.save()
        }
    }
    try? ctx.save()
    return container
}

#Preview("Compute") {
    let container = sampleContainer()
    DesignCanvasView(design: sampleDesign(container), initialMode: .compute)
        .modelContainer(container)
        .frame(width: 700, height: 500)
}

#Preview("Compute (busy)") {
    let container = busyContainer()
    DesignCanvasView(design: sampleDesign(container), initialMode: .compute)
        .modelContainer(container)
        .frame(width: 700, height: 500)
}

#Preview("Workflow") {
    let container = sampleContainer()
    DesignCanvasView(design: sampleDesign(container), initialMode: .workflow)
        .modelContainer(container)
        .frame(width: 700, height: 640)
}
