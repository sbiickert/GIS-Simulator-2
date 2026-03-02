//
//  DesignTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-31.
//

import Testing
@testable import GIS_Simulator_2

struct DesignTest {

    @Test func create() async throws {
        let d = DesignTest.sampleDesign
		#expect("Design 1" == d.name)
		#expect(4 == d.zones.count)
		
		let dmz = await d.findZone(named: "DMZ")
		#expect(dmz != nil)
		#expect(dmz!.isFullyConnected(in: d.network))
		#expect(d.allComputeNodes.count == 7) // Physical and virtual
		
		let localHost = await d.findCompute(named: "SRV 01")
		#expect(localHost != nil)
		#expect(localHost!.totalVirtualCpuAllocation == 16)
		#expect(localHost!.totalCpuAllocation == 8)
		
		let gisHost = await d.findCompute(named: "VGIS01")
		#expect(gisHost != nil)
		#expect(gisHost!.vCores == 8)
		#expect(gisHost!.type == .vm)
		
		#expect(d.workflowDefinitions.count == 2)
		#expect(d.workflows.count == 2)
		
		await d.printValidationMessages()
		#expect(d.isValid)
    }
	
	@Test func updateNodes() async throws {
		let d = DesignTest.sampleDesign
		#expect(d.isValid)
		
		for node in await d.allComputeNodes {
			node.desc = "Updated"
		}
		
		let gisHost = await d.findCompute(named: "VGIS01")
		#expect(gisHost!.desc == "Updated")
		await #expect(d.serviceProviders[0].nodes[0].desc == "Updated")
		let sp = await d.workflows[0].definition.chains[0].serviceProviderForStep(at: 0)
		await #expect(sp!.nodes[0].desc == "Updated")
	}
	
	@Test func removeZone() async throws {
		let d = DesignTest.sampleDesign
		#expect(d.isValid)
		#expect(d.physicalComputeNodes.count == 4) // 2 physical hosts and 2 clients
		#expect(d.network.count == 10)
		let mobileWDef = await d.findWorkflowDefinition(named: "Mobile Map Definition")
		#expect(mobileWDef != nil)
		await #expect(mobileWDef!.chains[0].serviceProviders.count == 7)
		await #expect(mobileWDef!.chains[0].serviceProviders["feature"]!.nodes.count > 0)
		
		if let az = await d.findZone(named: "AGOL") {
			await d.removeZone(az)
		}
		
		#expect(d.isValid == false)
		#expect(d.physicalComputeNodes.count == 3) // 1 physical hosts and 2 clients
		#expect(d.network.count == 7)
		await #expect(mobileWDef!.chains[0].serviceProviders.count == 7)
		for st in await mobileWDef!.chains[0].configuredServiceTypes {
			if (st != "mobile") {
				await #expect(mobileWDef!.chains[0].serviceProviders[st]!.nodes.count == 0)
			}
		}
		
		// Re-point mobile workflow at local service providers
		var remaining = [ServiceProvider]()
		for sp in await d.serviceProviders {
			if await (sp.name.contains("AGOL") == false) {
				remaining.append(sp)
			}
		}
		d.serviceProviders = remaining
		await d.updateWorkflowDefinitions()
		
		for sp in await d.serviceProviders {
			await mobileWDef!.assign(serviceProvider: sp)
		}
		
		#expect(d.isValid)
	}

	public static var sampleDesign: Design {
		let d = Design(name: Design.nextName, desc: "Sample Design")
		
		// Zones and Connections
		d.addZone(ZoneTest.sampleIntranetZone, localBandwidthMbps: 1000, localLatencyMS: 0)
		d.addZone(ZoneTest.sampleEdgeZone, localBandwidthMbps: 1000, localLatencyMS: 0)
		d.addZone(ZoneTest.sampleInternetZone, localBandwidthMbps: 10000, localLatencyMS: 10)
		d.addZone(ZoneTest.sampleAgolZone, localBandwidthMbps: 10000, localLatencyMS: 0)
		
		d.addConnection(ConnectionTest.sampleConnectionToDmz, addReciprocal: true)
		d.addConnection(ConnectionTest.sampleConnectionToInternet, addReciprocal: true)
		d.addConnection(ConnectionTest.sampleConnectionToAgol, addReciprocal: true)
		
		// Physical Servers
		guard let lz = d.findZone(named: "Local"), let az = d.findZone(named: "AGOL") else {
			print("Could not find Local and AGOL zones")
			return d
		}
		
		let localHost = ComputeNode(name: "SRV 01",
									desc: "Local Server",
									hwDef: HardwareDefTest.sampleServerHardwareDef,
									memoryGB: 48,
									zone: lz,
									type: .host)
		let agolHost = ComputeNode(name: "AGOL 01",
								   desc: "AWS Server",
								   hwDef: HardwareDefTest.sampleServerHardwareDef,
								   memoryGB: 64,
								   zone: az,
								   type: .host)
		d.addCompute(localHost)
		d.addCompute(agolHost)
		
		// Virtual Servers
		let vmWeb = localHost.addVirtualMachine(name: "VWEB01", vCores: 4, memoryGB: 16)
		let vmGIS = localHost.addVirtualMachine(name: "VGIS01", vCores: 8, memoryGB: 32)
		let vmDB  = localHost.addVirtualMachine(name: "VDB01", vCores: 4, memoryGB: 16)
		
		// Clients
		let localClient = ComputeNodeTest.sampleClient
		d.addCompute(localClient)
		let mobileClient = ComputeNodeTest.sampleMobile
		d.addCompute(mobileClient)
		
		// Services
		for sType in ServiceDefTest.sampleServiceTypes {
			d.addServiceDef(ServiceDefTest.sampleService(type: sType))
		}
		
		// Service Providers (Local)
		var spLocal = [ServiceProvider]()
		spLocal.append(ServiceProvider(name: "Web Browser", desc: "", service: d.services["browser"]!, nodes: [localClient]))
		spLocal.append(ServiceProvider(name: "Pro Workstation", desc: "", service: d.services["pro"]!, nodes: [localClient]))
		spLocal.append(ServiceProvider(name: "IIS", desc: "", service: d.services["web"]!, nodes: [vmWeb]))
		spLocal.append(ServiceProvider(name: "Portal", desc: "", service: d.services["portal"]!, nodes: [vmGIS]))
		spLocal.append(ServiceProvider(name: "Map Server", desc: "", service: d.services["map"]!, nodes: [vmGIS]))
		spLocal.append(ServiceProvider(name: "Hosting Server", desc: "", service: d.services["feature"]!, nodes: [vmGIS]))
		spLocal.append(ServiceProvider(name: "Data Store", desc: "", service: d.services["relational"]!, nodes: [vmGIS]))
		spLocal.append(ServiceProvider(name: "Local File", desc: "", service: d.services["file"]!, nodes: [vmGIS]))
		spLocal.append(ServiceProvider(name: "SQL", desc: "", service: d.services["dbms"]!, nodes: [vmDB]))
		
		for sp in spLocal {
			d.addServiceProvider(sp)
		}
		
		// Service Providers (AGOL)
		var spAGOL = [ServiceProvider]()
		spAGOL.append(ServiceProvider(name: "Field Maps", desc: "", service: d.services["mobile"]!, nodes: [mobileClient]))
		spAGOL.append(ServiceProvider(name: "AGOL Edge", desc: "", service: d.services["web"]!, nodes: [agolHost]))
		spAGOL.append(ServiceProvider(name: "AGOL Portal", desc: "", service: d.services["portal"]!, nodes: [agolHost]))
		spAGOL.append(ServiceProvider(name: "AGOL GIS", desc: "", service: d.services["feature"]!, nodes: [agolHost]))
		spAGOL.append(ServiceProvider(name: "AGOL Basemap", desc: "", service: d.services["map"]!, nodes: [agolHost]))
		spAGOL.append(ServiceProvider(name: "AGOL DB", desc: "", service: d.services["relational"]!, nodes: [agolHost]))
		spAGOL.append(ServiceProvider(name: "AGOL File", desc: "", service: d.services["file"]!, nodes: [agolHost]))

		for sp in spAGOL {
			d.addServiceProvider(sp)
		}
		
		// Workflow Definitions
		d.addWorkflowDefinition(WorkflowDefTest.sampleWebWFDef)
		for sp in spLocal {
			d.workflowDefinitions[0].assign(serviceProvider: sp)
		}
		d.addWorkflowDefinition(WorkflowDefTest.sampleMobileWFDef)
		for sp in spAGOL {
			d.workflowDefinitions[1].assign(serviceProvider: sp)
		}
		
		// Workflows
		let _ = d.addTransactionalWorkflow(name: "Web", description: "", wdefName: "Web Map Definition", tph: 1000)
		let _ = d.addUserWorkflow(name: "Mobile", description: "", wdefName: "Mobile Map Definition", users: 15, productivity: 6)
		
		return d
	}
}
