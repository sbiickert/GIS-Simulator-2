//
//  WorkflowDefTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-21.
//

import Testing

@testable import GIS_Simulator_2

@Suite(.serialized)
struct WorkflowDefTest {
	
	@Test func create() async throws {
		var wfd = WorkflowDefTest.sampleWebWFDef
		#expect(wfd.name == "Web Map Definition")
		#expect(wfd.chains.count == 2)
		await #expect(wfd.chains[0].steps[3].serviceType == "map")
		await #expect(wfd.chains[0].steps[4].serviceType == "dbms")
		await #expect(wfd.chains[1].steps[3].serviceType == "map")
		#expect(wfd.allRequiredServiceTypes == Set(["portal", "file", "browser", "map", "dbms", "web"]))
		
		wfd = WorkflowDefTest.sampleMobileWFDef
		wfd = WorkflowDefTest.sampleVDIWFDef
		wfd = WorkflowDefTest.sampleWorkstationWFDef
	}

	@Test func addChain() async throws {
		let wfd = WorkflowDefTest.sampleWebWFDef
		let overlay = await WorkflowChain(name: "Hosted Features", description: "",
									steps: [WorkflowDefStepTest.sampleBrowserWDS,
											WorkflowDefStepTest.sampleWebWDS,
											WorkflowDefStepTest.samplePortalWDS,
											WorkflowDefStepTest.sampleHostWDS,
											WorkflowDefStepTest.sampleRelDSWDS],
									serviceProviders: [:])
		await wfd.chains.insert(overlay, at: 0)
		#expect(wfd.chains.count == 3)
		await #expect(wfd.chains[0].steps[3].serviceType == "feature")
		await #expect(wfd.chains[0].steps[4].serviceType == "relational")
		#expect(wfd.allRequiredServiceTypes ==
				Set(["portal", "file", "browser", "map", "dbms", "web", "feature", "relational"]))
	}

	@Test func removeChain() async throws {
		let wfd = WorkflowDefTest.sampleWebWFDef
		wfd.chains.remove(at: 0)
		#expect(wfd.chains.count == 1)
		await #expect(wfd.chains[0].steps[3].serviceType == "map")
		await #expect(wfd.chains[0].steps[4].serviceType == "file")
		#expect(wfd.allRequiredServiceTypes ==
				Set(["portal", "file", "browser", "map", "web"]))
	}

	@Test func swapClients() async throws {
		let dynChain = WorkflowDefTest.sampleDynMapChain(client: WorkflowDefStepTest.sampleBrowserWDS)
		await #expect(dynChain.steps[0].serviceType == "browser")
		#expect(dynChain.steps.count == 5)
		await dynChain.replace(clientStep: WorkflowDefStepTest.sampleMobileWDS)
		await #expect(dynChain.steps[0].serviceType == "mobile")
		#expect(dynChain.steps.count == 5)
	}

	//MARK: Sample Chains
	
	public static func sampleDynMapChain(client: WorkflowDefStep) -> WorkflowChain {
		let steps = [WorkflowDefStepTest.sampleWebWDS,
					 WorkflowDefStepTest.samplePortalWDS,
					 WorkflowDefStepTest.sampleDynMapWDS,
					 WorkflowDefStepTest.sampleDBMSWDS]
		return WorkflowChain(name: "Dynamic Map Image", description: "",
							 steps: steps, serviceProviders: [:], addClient: client)
	}
	
	public static func sampleBaseMapChain(client: WorkflowDefStep) -> WorkflowChain {
		let steps = [WorkflowDefStepTest.sampleWebWDS,
					 WorkflowDefStepTest.samplePortalWDS,
					 WorkflowDefStepTest.sampleCacheMapWDS,
					 WorkflowDefStepTest.sampleFileWDS]
		return WorkflowChain(name: "Cached Map Image", description: "",
							 steps: steps, serviceProviders: [:], addClient: client)
	}
	
	public static func sampleHostedChain(client: WorkflowDefStep) -> WorkflowChain {
		let steps = [WorkflowDefStepTest.sampleWebWDS,
					 WorkflowDefStepTest.samplePortalWDS,
					 WorkflowDefStepTest.sampleHostWDS,
					 WorkflowDefStepTest.sampleRelDSWDS]
		return WorkflowChain(name: "Hosted Features", description: "",
							 steps: steps, serviceProviders: [:], addClient: client)
	}
	
	public static var sampleProChain: WorkflowChain {
		let steps = [WorkflowDefStepTest.sampleProWDS,
					 WorkflowDefStepTest.sampleDBMSWDS]
		return WorkflowChain(name: "Pro DC", description: "",
							 steps: steps, serviceProviders: [:])
	}
	
	public static var sampleProVDIChain: WorkflowChain {
		let steps = [WorkflowDefStepTest.sampleVDIWDS,
					 WorkflowDefStepTest.sampleProWDS,
					 WorkflowDefStepTest.sampleDBMSWDS]
		return WorkflowChain(name: "Pro VDI DC", description: "",
							 steps: steps, serviceProviders: [:])
	}
	
	//MARK: Sample Workflow Definitions
	
	public static var sampleWebWFDef: WorkflowDef {
		let chains = [sampleDynMapChain(client: WorkflowDefStepTest.sampleBrowserWDS),
					  sampleBaseMapChain(client: WorkflowDefStepTest.sampleBrowserWDS)]
		return WorkflowDef(name: "Web Map Definition", desc: "Sample Web Map",
						   thinkTimeSeconds: 6, chains: chains)
	}
	
	public static var sampleMobileWFDef: WorkflowDef {
		let chains = [sampleHostedChain(client: WorkflowDefStepTest.sampleMobileWDS),
					  sampleBaseMapChain(client: WorkflowDefStepTest.sampleMobileWDS)]
		return WorkflowDef(name: "Mobile Map Definition", desc: "Sample Mobile Map",
						   thinkTimeSeconds: 10, chains: chains)
	}
	
	public static var sampleWorkstationWFDef: WorkflowDef {
		let chains = [sampleProChain,
					  sampleBaseMapChain(client: WorkflowDefStepTest.sampleProWDS)]
		return WorkflowDef(name: "Workstation Map Definition", desc: "Sample Workstation Map",
						   thinkTimeSeconds: 3, chains: chains)
	}
	
	public static var sampleVDIWFDef: WorkflowDef {
		let chains = [sampleProVDIChain,
					  sampleBaseMapChain(client: WorkflowDefStepTest.sampleVDIWDS)]
		return WorkflowDef(name: "VDI Map Definition", desc: "Sample VDI Map",
						   thinkTimeSeconds: 3, chains: chains)
	}
}
