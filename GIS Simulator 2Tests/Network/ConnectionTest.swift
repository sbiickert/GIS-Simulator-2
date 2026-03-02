//
//  ConnectionTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-02.
//

import Testing
@testable import GIS_Simulator_2

struct ConnectionTest {

    @Test func createConnection() async throws {
		let z1 = ZoneTest.sampleIntranetZone
		let z2 = ZoneTest.sampleEdgeZone
		let c1 = await z1.connect(to: z2, bandwidth: 100, latency: 1)
		#expect(c1.source == z1)
		#expect(c1.destination == z2)
		let cInv = await c1.inverted()
		#expect(cInv.source == z2)
		#expect(cInv.destination == z1)
		let cLocal = await z1.selfConnect(bandwidth: 500, latency: 5)
		#expect(cLocal.source == z1)
		#expect(cLocal.destination == z1)
		#expect(cLocal.bandwidthMbps == 500)
    }
	
	public static var sampleConnectionIntranet: Connection {
		return ZoneTest.sampleIntranetZone.selfConnect(bandwidth: 1000, latency: 1)
	}
	
	public static var sampleConnectionToDmz: Connection {
		return Connection(source: ZoneTest.sampleIntranetZone, destination: ZoneTest.sampleEdgeZone, bandwidthMbps: 1000, latencyMs: 1)
	}
	
	public static var sampleConnectionToInternet: Connection {
		return Connection(source: ZoneTest.sampleEdgeZone, destination: ZoneTest.sampleInternetZone, bandwidthMbps: 100, latencyMs: 10)
	}
	
	public static var sampleConnectionFromInternet: Connection {
		return Connection(source: ZoneTest.sampleInternetZone, destination: ZoneTest.sampleEdgeZone, bandwidthMbps: 500, latencyMs: 10)
	}
	
	public static var sampleConnectionToAgol: Connection {
		return Connection(source: ZoneTest.sampleInternetZone, destination: ZoneTest.sampleAgolZone, bandwidthMbps: 1000, latencyMs: 10)
	}

}
