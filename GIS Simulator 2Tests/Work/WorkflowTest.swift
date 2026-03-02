//
//  WorkflowTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-21.
//

import Testing

@testable import GIS_Simulator_2

struct WorkflowTest {
	
	@Test func create() async throws {
		let wfPro = WorkflowTest.sampleWorkstationWF
		await #expect(wfPro.definition.missingServiceProviders.isEmpty)
		let wfVDI = WorkflowTest.sampleVDIWF
		await #expect(wfVDI.definition.missingServiceProviders.isEmpty)
		let wfWeb = WorkflowTest.sampleWebWF
		await #expect(wfWeb.definition.missingServiceProviders.isEmpty)
	}
	
	@Test func missingSPs() async throws {
		let wf = WorkflowTest.sampleWebWF
		for chain in await wf.definition.chains {
			chain.serviceProviders.removeAll()
		}
		await #expect(wf.definition.chains[0].serviceProviders.isEmpty)
		let sps = [ServiceProviderTest.sampleBrowserSP,
				   ServiceProviderTest.sampleFileSP,
				   ServiceProviderTest.sampleWebSP]
		for sp in sps {
			await wf.definition.assign(serviceProvider: sp)
		}
		let missing = await wf.definition.missingServiceProviders
		#expect(missing.count == 3)
		#expect(Set(missing) == Set(["map", "dbms", "portal"]))
	}
	
	public static var sampleWorkstationWF: Workflow {
		let w = Workflow(name: "Pro", desc: "Local Workstation",
						 definition: WorkflowDefTest.sampleWorkstationWFDef,
						 type: .user, userCount: 5, productivity: 10)
		for sp in ServiceProviderTest.sampleWebGisSPSet {
			w.definition.assign(serviceProvider: sp)
		}
		return w
	}
	
	public static var sampleVDIWF: Workflow {
		let w = Workflow(name: "VDI", desc: "VDI Workstation",
					 definition: WorkflowDefTest.sampleVDIWFDef,
					 type: .user, userCount: 5, productivity: 10)
		for sp in ServiceProviderTest.sampleWebGisSPSet {
			w.definition.assign(serviceProvider: sp)
		}
		return w
	}
	
	public static var sampleWebWF: Workflow {
		let w = Workflow(name: "Web", desc: "Web Application",
						 definition: WorkflowDefTest.sampleWebWFDef,
						 type: .transactional, tph: 10000)
		for sp in ServiceProviderTest.sampleWebGisSPSet {
			w.definition.assign(serviceProvider: sp)
		}
		return w
	}
}
