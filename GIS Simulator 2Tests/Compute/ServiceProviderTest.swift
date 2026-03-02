//
//  ServiceProviderTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-03.
//

import Testing
@testable import GIS_Simulator_2

struct ServiceProviderTest {

    @Test func create() async throws {
		var sp = ServiceProviderTest.sampleWebSP
		#expect(sp.name == "IIS")
		let handler = await sp.handlerNode
		#expect(handler != nil)
		#expect(handler!.name == "Web 001")
		#expect(sp.isValid)
		
		sp = ServiceProviderTest.samplePortalSP
		#expect(sp.name == "Portal")
		#expect(sp.isValid)
		
		sp = ServiceProviderTest.sampleMapSP
		#expect(sp.name == "GIS Site")
		#expect(sp.isValid)
		
		sp = ServiceProviderTest.sampleHaMapSP
		#expect(sp.name == "GIS HA Site")
		#expect(sp.isValid)
		var node1 = await sp.handlerNode
		var node2 = await sp.handlerNode
		#expect(node1 != node2) // Round-robining
		
		sp = ServiceProviderTest.sampleDbmsSP
		#expect(sp.name == "SQL Server")
		#expect(sp.isValid)
		
		sp = ServiceProviderTest.sampleHaDatastoreSP
		#expect(sp.name == "Relational DS")
		#expect(sp.isValid)
		node1 = await sp.handlerNode
		node2 = await sp.handlerNode
		#expect(node1 == node2) // Failover (i.e. got primary twice)
		
		sp = ServiceProviderTest.sampleFileSP
		#expect(sp.name == "File Server")
		#expect(sp.isValid)
		
		sp = ServiceProviderTest.sampleVdiSP
		#expect(sp.name == "VDI")
		#expect(sp.isValid)
		
		sp = ServiceProviderTest.sampleBrowserSP
		#expect(sp.name == "Chrome")
		#expect(sp.isValid)
		
		sp = ServiceProviderTest.sampleProSP
		#expect(sp.name == "Pro")
		#expect(sp.isValid)
    }
	
	private static var host = ComputeNode(name: "Host 001", desc: "Sample Server",
									hwDef: HardwareDefTest.sampleServerHardwareDef,
									memoryGB: 64,
									zone: ZoneTest.sampleIntranetZone,
									type: .host)
	
	private static func vm(named name: String) -> ComputeNode {
		if let existing = host.vm(named: name) { return existing }
		let created = host.addVirtualMachine(name: name, vCores: 4, memoryGB: 16)
		return created
	}

	public static var sampleWebSP: ServiceProvider {
		let myVM = vm(named: "Web 001")
		return ServiceProvider(name: "IIS", desc: "Web Server",
							   service: ServiceDefTest.sampleService(type: "web"), nodes: [myVM])
	}
	
	public static var samplePortalSP: ServiceProvider {
		let myVM = vm(named: "Portal 001")
		return ServiceProvider(name: "Portal", desc: "Portal Server",
							   service: ServiceDefTest.sampleService(type: "portal"), nodes: [myVM])
	}
	
	public static var sampleMapSP: ServiceProvider {
		let myVM = vm(named: "GIS 001")
		return ServiceProvider(name: "GIS Site", desc: "Map Server Site",
							   service: ServiceDefTest.sampleService(type: "map"), nodes: [myVM])
	}
	
	public static var sampleHaMapSP: ServiceProvider {
		let myVM1 = vm(named: "GIS 002")
		let myVM2 = vm(named: "GIS 003")
		return ServiceProvider(name: "GIS HA Site", desc: "High Availability Map Server Site",
							   service: ServiceDefTest.sampleService(type: "map"), nodes: [myVM1, myVM2])
	}
	
	public static var sampleDbmsSP: ServiceProvider {
		let myVM = vm(named: "DB 001")
		return ServiceProvider(name: "SQL Server", desc: "Geodatabase",
							   service: ServiceDefTest.sampleService(type: "dbms"), nodes: [myVM])
	}
	
	public static var sampleHaDatastoreSP: ServiceProvider {
		let myVM1 = vm(named: "DS 003")
		let myVM2 = vm(named: "DS 004")
		return ServiceProvider(name: "Relational DS", desc: "High Availability Datastore",
							   service: ServiceDefTest.sampleService(type: "datastore"), nodes: [myVM1, myVM2])
	}
	
	public static var sampleFileSP: ServiceProvider {
		let myVM = vm(named: "FS 001")
		return ServiceProvider(name: "File Server", desc: "File Storage",
							   service: ServiceDefTest.sampleService(type: "file"), nodes: [myVM])
	}
	
	public static var sampleVdiSP: ServiceProvider {
		let myVM = vm(named: "VDI 001")
		return ServiceProvider(name: "VDI", desc: "Citrix Server",
							   service: ServiceDefTest.sampleService(type: "vdi"), nodes: [myVM])
	}
	
	public static var sampleBrowserSP: ServiceProvider {
		let client = ComputeNodeTest.sampleClient
		return ServiceProvider(name: "Chrome", desc: "PC Workstation",
							   service: ServiceDefTest.sampleService(type: "browser"), nodes: [client])
	}
	
	public static var sampleProSP: ServiceProvider {
		let client = ComputeNodeTest.sampleClient
		return ServiceProvider(name: "Pro", desc: "Pro Workstation",
							   service: ServiceDefTest.sampleService(type: "pro"), nodes: [client])
	}
	
	public static var sampleWebGisSPSet: Set<ServiceProvider> {
		return Set([sampleBrowserSP, sampleProSP, sampleVdiSP, sampleMapSP,
				   sampleFileSP, sampleHaDatastoreSP, sampleDbmsSP, samplePortalSP,
				   sampleWebSP])
	}
}
