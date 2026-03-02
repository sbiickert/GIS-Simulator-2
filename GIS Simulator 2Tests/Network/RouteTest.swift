//
//  RouteTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-03.
//

import Testing
@testable import GIS_Simulator_2

@Suite(.serialized)
struct RouteTest {

    @Test func networkFind() async throws {
		let z1 = ZoneTest.sampleIntranetZone
		let z2 = ZoneTest.sampleEdgeZone
		let z3 = ZoneTest.sampleInternetZone
		let c1 = await z1.selfConnect(bandwidth: 1000, latency: 0)
		let c2 = await z2.selfConnect(bandwidth: 1000, latency: 0)
		let c3 = await z3.selfConnect(bandwidth: 1000, latency: 0)
		let c12 = ConnectionTest.sampleConnectionToDmz
		let c21 = await c12.inverted()
		let c23 = ConnectionTest.sampleConnectionToInternet
		let c32 = ConnectionTest.sampleConnectionFromInternet
		#expect(c21.name == "DMZ to Local")
		var network = [c1, c2, c3, c12, c21, c23, c32]
		#expect(c1 == z1.localConnection(in: network))
		#expect(c2 == z2.localConnection(in: network))
		#expect(c3 == z3.localConnection(in: network))
		#expect(1 == z1.entryConnections(in: network).count)
		#expect(1 == z1.exitConnections(in: network).count)
		let z1Exit = await z1.exitConnections(in: network).first!
		#expect(c12 == z1Exit)
		let z4 = await Zone(name: "Zone 4", description: "The fourth zone")
		let c34 = await z3.connect(to: z4, bandwidth: 13, latency: 1)
		network.append(c34)
		#expect(true == z4.isDestination(in: network))
		#expect(false == z4.isSource(in: network))
	}

	@Test func findRoute() async throws {
		let z1 = ZoneTest.sampleIntranetZone
		let z2 = ZoneTest.sampleEdgeZone
		let z3 = ZoneTest.sampleInternetZone
		let z4 = ZoneTest.sampleAgolZone
		let c1 = await z1.selfConnect(bandwidth: 100, latency: 0)
		let c2 = await z2.selfConnect(bandwidth: 100, latency: 0)
		let c3 = await z3.selfConnect(bandwidth: 100, latency: 0)
		let c4 = await z4.selfConnect(bandwidth: 100, latency: 0)
		let c12 = ConnectionTest.sampleConnectionToDmz
		let c21 = await c12.inverted()
		let c23 = ConnectionTest.sampleConnectionToInternet
		let c32 = ConnectionTest.sampleConnectionFromInternet
		let c34 = ConnectionTest.sampleConnectionToAgol
		let network = [c1, c2, c3, c4, c12, c21, c23, c32, c34]

		let r14 = await Route.findRoute(from: z1, to: z4, in: network)
		#expect(r14 != nil)
		#expect(r14!.connections == [c1, c12, c23, c34])
		let r41 = await Route.findRoute(from: z4, to: z1, in: network)
		#expect(r41 == nil)
		let r31 = await Route.findRoute(from: z3, to: z1, in: network)
		#expect(r31 != nil)
		#expect(r31!.connections == [c3, c32, c21])
	}
	
	@Test func intranet() async throws {
		let network = RouteTest.sampleIntranet
		let src = ZoneTest.sampleIntranetZone
		let route = await Route.findRoute(from: src, to: src, in: network)
		#expect(route != nil)
		#expect(route!.connections.count == 1)
	}
	
	@Test func network() async throws {
		let network = RouteTest.sampleNetwork
		let src = ZoneTest.sampleIntranetZone
		let dst = ZoneTest.sampleInternetZone
		let route = await Route.findRoute(from: src, to: dst, in: network)
		#expect(route != nil)
		#expect(route!.connections.count == 3)
		await #expect(route!.connections.first!.source == src)
		await #expect(route!.connections.last!.destination == dst)
	}
	
	@Test func complexNetwork() async throws {
		let network = RouteTest.sampleComplexNetwork
		let src = ZoneTest.sampleIntranetZone
		var dst = ZoneTest.sampleAgolZone
		var route = await Route.findRoute(from: src, to: dst, in: network)
		#expect(route != nil)
		#expect(route!.connections.count == 4)
		await #expect(route!.connections.first!.source == src)
		await #expect(route!.connections.last!.destination == dst)

		dst = ZoneTest.sampleWanZone
		route = await Route.findRoute(from: src, to: dst, in: network)
		#expect(route != nil)
		#expect(route!.connections.count == 2)
		await #expect(route!.connections.first!.source == src)
		await #expect(route!.connections.last!.destination == dst)
	}
	
	@Test func loopingNetwork() async throws {
		let network = RouteTest.sampleLoopingNetwork
		
		let routeAC = await Route.findRoute(from: RouteTest.zoneA, to: RouteTest.zoneC, in: network)
		#expect(await routeAC != nil)
		#expect(routeAC!.connections.count == 2)
		let routeAB = await Route.findRoute(from: RouteTest.zoneA, to: RouteTest.zoneB, in: network)
		#expect(await routeAB != nil)
		#expect(routeAB!.connections.count == 2)
		let routeBC = await Route.findRoute(from: RouteTest.zoneB, to: RouteTest.zoneC, in: network)
		#expect(await routeBC != nil)
		#expect(routeBC!.connections.count == 2)
	}
	
	
	
	public static var sampleIntranet: [Connection] {
		let local = ZoneTest.sampleIntranetZone.selfConnect(bandwidth: 1000, latency: 0)
		return [local]
	}
	
	public static var sampleNetwork: [Connection] {
		var network = [Connection]()
		let intranet = ZoneTest.sampleIntranetZone
		let dmz = ZoneTest.sampleEdgeZone
		let internet = ZoneTest.sampleInternetZone
		
		network.append(intranet.selfConnect(bandwidth: 1000, latency: 0))
		network.append(dmz.selfConnect(bandwidth: 1000, latency: 0))
		network.append(internet.selfConnect(bandwidth: 1000, latency: 0))
		
		network.append(ConnectionTest.sampleConnectionToDmz)
		network.append(ConnectionTest.sampleConnectionToDmz.inverted())
		network.append(ConnectionTest.sampleConnectionToInternet)
		network.append(ConnectionTest.sampleConnectionToInternet.inverted())

		return network
	}
	
	public static var sampleComplexNetwork: [Connection] {
		var network = sampleNetwork
		let intranet = ZoneTest.sampleIntranetZone
		let internet = ZoneTest.sampleInternetZone
		let wan = ZoneTest.sampleWanZone
		let agol = ZoneTest.sampleAgolZone
		
		network.append(wan.selfConnect(bandwidth: 1000, latency: 0))
		network.append(wan.connect(to: intranet, bandwidth: 300, latency: 7))
		network.append(intranet.connect(to: wan, bandwidth: 300, latency: 7))
		
		network.append(agol.selfConnect(bandwidth: 1000, latency: 0))
		network.append(agol.connect(to: internet, bandwidth: 1000, latency: 10))
		network.append(internet.connect(to: agol, bandwidth: 1000, latency: 10))
		
		return network
	}
	
	private static var zoneA = Zone(name: "Zone A", description: "")
	private static var zoneB = Zone(name: "Zone B", description: "")
	private static var zoneC = Zone(name: "Zone C", description: "")
	
	public static var sampleLoopingNetwork: [Connection] {
		var network: [Connection] = []
		
		network.append(zoneA.selfConnect(bandwidth: 1000, latency: 0))
		network.append(zoneB.selfConnect(bandwidth: 1000, latency: 0))
		network.append(zoneC.selfConnect(bandwidth: 1000, latency: 0))
		
		network.append(zoneA.connect(to: zoneB, bandwidth: 100, latency: 1))
		network.append(zoneA.connect(to: zoneC, bandwidth: 100, latency: 1))
		
		network.append(zoneB.connect(to: zoneA, bandwidth: 100, latency: 1))
		network.append(zoneB.connect(to: zoneC, bandwidth: 100, latency: 1))
		
		network.append(zoneC.connect(to: zoneB, bandwidth: 100, latency: 1))
		network.append(zoneC.connect(to: zoneA, bandwidth: 100, latency: 1))

		return network
	}

}
