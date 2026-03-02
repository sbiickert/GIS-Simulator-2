//
//  ZoneTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-02.
//

import Testing
@testable import GIS_Simulator_2

struct ZoneTest {

    @Test func createZone() async throws {
		let z1 = ZoneTest.sampleInternetZone
		let z2 = ZoneTest.sampleEdgeZone
		#expect(z1 != z2)
		#expect(z1.name == "Internet")
		#expect(z2.name == "DMZ")
		let z3 = ZoneTest.sampleInternetZone
		#expect(z1 == z3)
    }

	private static var _sampleInternetZone: Zone? = nil
	public static var sampleInternetZone: Zone {
		if let _sampleInternetZone { return _sampleInternetZone }
		_sampleInternetZone = Zone(name: "Internet", description: "Internet Zone")
		return _sampleInternetZone!
	}

	private static var _sampleIntranetZone: Zone? = nil
	public static var sampleIntranetZone: Zone {
		if let _sampleIntranetZone { return _sampleIntranetZone }
		_sampleIntranetZone = Zone(name: "Local", description: "Intranet Zone")
		return _sampleIntranetZone!
	}

	private static var _sampleEdgeZone: Zone? = nil
	public static var sampleEdgeZone: Zone {
		if let _sampleEdgeZone { return _sampleEdgeZone }
		_sampleEdgeZone = Zone(name: "DMZ", description: "Edge Zone")
		return _sampleEdgeZone!
	}

	private static var _sampleAgolZone: Zone? = nil
	public static var sampleAgolZone: Zone {
		if let _sampleAgolZone { return _sampleAgolZone }
		_sampleAgolZone = Zone(name: "AGOL", description: "ArcGIS Online Zone")
		return _sampleAgolZone!
	}

	private static var _sampleWanZone: Zone? = nil
	public static var sampleWanZone: Zone {
		if let _sampleWanZone { return _sampleWanZone }
		_sampleWanZone = Zone(name: "WAN Site", description: "Second Office")
		return _sampleWanZone!
	}
}
