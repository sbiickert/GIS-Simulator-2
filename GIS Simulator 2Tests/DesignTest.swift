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
		#expect("Test Design" == d.name)
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

	// MARK: - Library customization

	@Test func catalogMergesAndSortsFavoritesFirst() async throws {
		let d = Design(name: "Cat", desc: "")
		let alpha = HardwareDef(processor: "Alpha", cores: 4, specIntRate2017: 10)   // predefined
		let beta  = HardwareDef(processor: "Beta", cores: 4, specIntRate2017: 10)    // predefined, favorite
		let gamma = HardwareDef(processor: "Gamma", cores: 8, specIntRate2017: 20)   // custom

		let entries = await d.catalog(predefined: [alpha, beta], custom: [gamma], favorites: ["Beta"])

		// Favorites first, then alphabetical by key.
		#expect(entries.map(\.key) == ["Beta", "Alpha", "Gamma"])
		#expect(entries[0].isFavorite)
		#expect(entries[0].isCustom == false)
		#expect(entries.first(where: { $0.key == "Gamma" })!.isCustom)
	}

	@Test func customItemShadowsPredefinedAndLeavesItUntouched() async throws {
		let d = Design(name: "Shadow", desc: "")
		let predefined = HardwareDef(processor: "Xeon", cores: 12, specIntRate2017: 67)
		let custom = HardwareDef(processor: "Xeon", cores: 24, specIntRate2017: 99) // same key, edited
		d.customHardware = [custom]

		let entries = await d.catalog(predefined: [predefined], custom: [custom], favorites: [])

		#expect(entries.count == 1)                       // custom shadows predefined
		#expect(entries[0].isCustom)
		#expect(entries[0].item.cores == 24)
		#expect(predefined.cores == 12)                   // predefined value is never mutated
	}

	@Test func toggleFavoriteAddsAndRemoves() async throws {
		let d = Design(name: "Fav", desc: "")

		var isFav = await d.isFavorite("map", in: \.favoriteServices)
		#expect(isFav == false)

		await d.toggleFavorite("map", in: \.favoriteServices)
		isFav = await d.isFavorite("map", in: \.favoriteServices)
		#expect(isFav)
		#expect(d.favoriteServices == ["map"])

		await d.toggleFavorite("map", in: \.favoriteServices)
		isFav = await d.isFavorite("map", in: \.favoriteServices)
		#expect(isFav == false)
		#expect(d.favoriteServices.isEmpty)
	}

	@Test func addFavoriteIsIdempotent() async throws {
		let d = Design(name: "Fav", desc: "")

		await d.addFavorite("Custom CPU", in: \.favoriteHardware)
		await d.addFavorite("Custom CPU", in: \.favoriteHardware)
		#expect(d.favoriteHardware == ["Custom CPU"])
	}

	@Test func uniqueCopyNameAvoidsCollisions() async throws {
		let d = Design(name: "Copy", desc: "")

		let first = await d.uniqueCopyName(base: "Map", existingKeys: [])
		#expect(first == "Map copy")

		let second = await d.uniqueCopyName(base: "Map", existingKeys: ["Map copy"])
		#expect(second == "Map copy 2")

		let third = await d.uniqueCopyName(base: "Map", existingKeys: ["Map copy", "Map copy 2"])
		#expect(third == "Map copy 3")
	}

	@Test func upsertAndRemoveCustomValueItems() async throws {
		let d = Design(name: "CRUD", desc: "")

		let hw = HardwareDef(processor: "Custom CPU", cores: 16, specIntRate2017: 80)
		await d.upsertCustomHardware(hw)
		#expect(d.customHardware.count == 1)

		// Upsert with same key replaces rather than duplicates.
		let hwEdited = HardwareDef(processor: "Custom CPU", cores: 32, specIntRate2017: 160)
		await d.upsertCustomHardware(hwEdited)
		#expect(d.customHardware.count == 1)
		#expect(d.customHardware[0].cores == 32)

		// Removing also clears any favorite for that key.
		d.favoriteHardware = ["Custom CPU"]
		await d.removeCustomHardware(key: "Custom CPU")
		#expect(d.customHardware.isEmpty)
		#expect(d.favoriteHardware.isEmpty)
	}

	@Test func removingCustomServiceDefInUseRevalidatesDesign() async throws {
		let d = DesignTest.sampleDesign
		#expect(d.isValid)
		#expect(d.services["map"] != nil)

		// Pretend "map" is a custom service def that is also in use.
		await d.upsertCustomServiceDef(ServiceDefTest.sampleService(type: "map"))
		await d.removeCustomServiceDef(key: "map")

		// Catalog entry gone and the in-use service was dropped + dependents updated.
		#expect(d.customServiceDefs.isEmpty)
		#expect(d.services["map"] == nil)
		let mapProviders = await d.serviceProviders.filter { $0.service.serviceType == "map" }
		#expect(mapProviders.isEmpty)
	}

	public static var sampleDesign: Design {
		let d = Design(name: "Test Design", desc: "Sample Design")
		
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
