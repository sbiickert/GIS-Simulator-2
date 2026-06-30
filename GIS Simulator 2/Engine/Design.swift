//
//  Design.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-27.
//

import Foundation
import SwiftData

/// A single row in a merged library pick list: the item plus whether it is
/// favorited and whether it is a custom (editable) item versus a read-only
/// predefined library template.
public struct CatalogEntry<T: LibraryItem> {
	public let item: T
	public let key: String
	public let isFavorite: Bool
	public let isCustom: Bool
}

@Model
public class Design: Described, Validatable {
	public var name: String
	public var desc: String
	@Relationship(deleteRule: .cascade) public var zones: [Zone] = []
	@Relationship(deleteRule: .cascade) public var network: [Connection] = []
	public var services: Dictionary<String, ServiceDef> = [:] // Just defining "map", "dbms", etc.
	@Relationship(deleteRule: .cascade) public var serviceProviders: [ServiceProvider] = []
	@Relationship(deleteRule: .cascade) public var workflowDefinitions: [WorkflowDef] = []
	@Relationship(deleteRule: .cascade) var workflows: [Workflow] = []
	@Relationship(deleteRule: .cascade) var physicalComputeNodes: [ComputeNode] = []

	// MARK: Library customization (per-Design)
	// Copies of, or brand-new, library building blocks authored within this design.
	// Value-type items persist as stored properties; @Model items use relationships.
	// WorkflowDef customizations reuse the existing `workflowDefinitions` collection.
	public var customHardware: [HardwareDef] = []
	public var customServiceDefs: [ServiceDef] = []
	public var customWorkflowSteps: [WorkflowDefStep] = []
	@Relationship(deleteRule: .cascade) public var customWorkflowChains: [WorkflowChain] = []

	// Favorite keys (predefined or custom) per type. Favorites float to the top
	// of pick lists. Keys are the items' `libraryKey` (processor / serviceType / name).
	public var favoriteHardware: [String] = []
	public var favoriteServices: [String] = []
	public var favoriteSteps: [String] = []
	public var favoriteChains: [String] = []
	public var favoriteWorkflowDefs: [String] = []

	private static var _nextId: Int = 0
	public static var nextId: Int {
		_nextId += 1
		return _nextId
	}
	public static var nextName: String {
		return "Design \(nextId)"
	}
	
	public init(name: String, desc: String,
				zones: [Zone] = [],
				network: [Connection] = [],
				services: Dictionary<String, ServiceDef> = [:],
				serviceProviders: [ServiceProvider] = [],
				workflowDefinitions: [WorkflowDef] = []) {
		self.name = name
		self.desc = desc
		self.zones = zones
		self.network = network
		self.services = services
		self.serviceProviders = serviceProviders
		self.workflowDefinitions = workflowDefinitions
	}
	
	var allComputeNodes: [ComputeNode] {
		var result = [ComputeNode]()
		
		for node in physicalComputeNodes {
			switch node.type{
			case .client:
				result.append(node)
			case .host:
				result.append(contentsOf: [node] + node.vmList)
			case .vm:
				fatalError("Virtual servers should not be in the physicalComputeNodes array")
			}
		}
		
		return result
	}
	
	public var isValid: Bool {
		return validate().isEmpty
	}
	
	public func validate() -> [ValidationMessage] {
		var messages = [ValidationMessage]()
		
		let allSPsValid = serviceProviders.allSatisfy(\.isValid)
		let allZonesConnected = zones.allSatisfy {$0.isFullyConnected(in: network)}
		let allWorkflowsValid = workflows.allSatisfy(\.isValid)
		
		for w in allWorkflows {
			for chain in w.definition.chains {
				for sp in chain.serviceProviders.values {
					for node in sp.nodes {
						if Zone.allZones(in: network).contains(node.zone) == false {
							messages.append(ValidationMessage(message: "Node \(node.name) is in zone \(node.zone.name) which is not in the network", source: sp.name))
						}
					}
				}
			}
		}
		
		if !allSPsValid {
			messages.append(ValidationMessage(message: "One or more service providers are not valid", source: self.name))
		}
		if !allZonesConnected {
			messages.append(ValidationMessage(message: "One or more zones are not fully connected", source: self.name))
		}
		if !allWorkflowsValid {
			messages.append(ValidationMessage(message: "One or more workflows are not valid", source: self.name))
		}
		if self.zones.isEmpty {
			messages.append(ValidationMessage(message: "No zones have been added to this design", source: self.name))
		}
		if self.network.isEmpty {
			messages.append(ValidationMessage(message: "No network connections have been added to this design", source: self.name))
		}
		if self.physicalComputeNodes.isEmpty {
			messages.append(ValidationMessage(message: "No physical compute nodes have been added to this design", source: self.name))
		}
		if self.workflowDefinitions.isEmpty {
			messages.append(ValidationMessage(message: "No workflow definitions have been added to this design", source: self.name))
		}
		if self.workflows.isEmpty {
			messages.append(ValidationMessage(message: "No workflows have been configured", source: self.name))
		}
		if self.services.isEmpty {
			messages.append(ValidationMessage(message: "No services types have been configured", source: self.name))
		}
		
		return messages
	}
	
	public func addZone(_ zone: Zone, localBandwidthMbps bw: Int, localLatencyMS lat: Int) {
		if zones.contains(zone) {
			return
		}
		zones.append(zone)
		let internalConn = zone.selfConnect(bandwidth: bw, latency: lat)
		network.append(internalConn)
	}

	public func removeZone(_ zone: Zone) {
		zones.removeAll(where: {$0 == zone})
		network = zone.otherConnections(in: network)
		physicalComputeNodes.removeAll(where: {$0.zone == zone})
		
		updateServiceProviders()
		updateWorkflowDefinitions()
	}
	
	public func findZone(named name: String) -> Zone? {
		zones.first(where: {$0.name == name})
	}
	
	public func addConnection(_ conn: Connection, addReciprocal r: Bool = false) {
		network.append(conn)
		if r {
			network.append(conn.inverted())
		}
	}
	
	public func removeConnection(_ conn: Connection) {
		network.removeAll(where: {$0 == conn})
	}
	
	public func addCompute(_ node: ComputeNode) {
		guard node.type != .vm else {
			fatalError("Cannot add VMs to the physicalComputeNodes array. Add to a host.")
		}
		physicalComputeNodes.append(node)
	}
	
	public func removeCompute(_ node: ComputeNode) {
		if node.type == .vm {
			for n in allComputeNodes {
				if n.type == .host && n.vmList.contains(node) {
					n.removeVirtualMachine(vm: node)
				}
			}
		}
		else {
			physicalComputeNodes.removeAll(where: {$0 == node})
		}
		
		updateServiceProviders()
		updateWorkflowDefinitions()
	}
	
	public func findCompute(named name: String) -> ComputeNode? {
		for node in allComputeNodes {
			if node.name == name {
				return node
			}
		}
		return nil
	}
	
	public func addServiceDef(_ def: ServiceDef) {
		services[def.serviceType] = def
	}
	
	public func removeServiceDef(_ def: ServiceDef) {
		services.removeValue(forKey: def.serviceType)
		
		updateServiceProviders()
		updateWorkflowDefinitions()
	}
	
	public func addServiceProvider(_ sp: ServiceProvider) {
		if serviceProviders.contains(sp) == false {
			serviceProviders.append(sp)
		}
	}
	
	public func removeServiceProvider(_ sp: ServiceProvider) {
		serviceProviders.removeAll(where: {$0 == sp})
		
		updateWorkflowDefinitions()
	}
	
	public func findServiceProviders(tag: String) -> [ServiceProvider] {
		return serviceProviders.filter({ $0.tags.contains(tag) })
	}

	public func addWorkflowDefinition(_ def: WorkflowDef) {
		workflowDefinitions.append(def)
	}
	
	public func removeWorkflowDefinition(_ def: WorkflowDef) {
		workflowDefinitions.removeAll(where: {$0 == def})
	}
	
	public func findWorkflowDefinition(named name:String) -> WorkflowDef? {
		return workflowDefinitions.first {$0.name == name}
	}
	
	public func addUserWorkflow(name: String, description desc: String, wdefName: String, users: Int, productivity: Int) -> Workflow {
		let wfDef = findWorkflowDefinition(named: wdefName)
		guard wfDef != nil else {fatalError("No such workflow: \(wdefName)")}
		let w = Workflow(name: name, desc: desc, definition: wfDef!, type: .user, userCount: users, productivity: productivity)
		workflows.append(w)
		return w
	}
	
	public func addTransactionalWorkflow(name: String, description desc: String, wdefName: String, tph: Int) -> Workflow {
		let wfDef = findWorkflowDefinition(named: wdefName)
		guard wfDef != nil else {fatalError("No such workflow: \(wdefName)")}
		let w = Workflow(name: name, desc: desc, definition: wfDef!, type: .transactional, tph: tph)
		workflows.append(w)
		return w
	}
	
	public func removeWorkflow(_ w: Workflow) {
		workflows.removeAll(where: {$0 == w})
	}
	
	public func findWorkflow(named name: String) -> Workflow? {
		return workflows.first {$0.name == name}
	}
	
	public var allWorkflows: [Workflow] {
		return workflows
	}
	
	public func updateServiceProviders() {
		/* Function to be called if a change has been made that may invalidate one or more ServiceProviders.
		Examples of changes that might do this:
		
		- A ServiceDef has been removed
		- A ComputeNode has been removed
		*/
		var remaining = [ServiceProvider]()
		
		for sp in serviceProviders {
			if services.values.contains(sp.service) { remaining.append(sp) }
		}
		
		let allNodes = allComputeNodes
		
		for sp in remaining {
			var remainingNodes: [ComputeNode] = []
			for node in sp.nodes {
				if allNodes.contains(node) { remainingNodes.append(node) }
			}
			sp.nodes = remainingNodes
		}
		
		serviceProviders = remaining
	}
	
	public func updateWorkflowDefinitions() {
		/* Function to be called if a change has been made that may invalidate one or more WorkflowDefs.
		 Examples of changes that might do this:
   
		   - A ServiceProvider has been removed.*/
		for wdef in workflowDefinitions {
			for chain in wdef.chains {
				var remaining: Dictionary<String, ServiceProvider> = [:]
				for sp in chain.serviceProviders.values {
					if self.serviceProviders.contains(sp) {
						remaining[sp.service.serviceType] = sp
					}
				}
				chain.serviceProviders = remaining
			}
		}
	}
	
	public func updateConfiguredWorkflows() {
		/* Function to be called if a change has been made that may invalidate one or more Workflows.
			Examples of changes that might do this:
   
			- A WorkflowDef has been removed.*/
		var remaining: [Workflow] = []
		for w in workflows {
			if workflowDefinitions.contains(w.definition) {
				remaining.append(w)
			}
		}
		workflows = remaining
	}
	
	public func provideQueues() -> [MultiQueue] {
		let connQueues = network.map { $0.provideQueue() }
		let compQueues = allComputeNodes.map { $0.provideQueue() }
		return connQueues + compQueues
	}

	// MARK: - Library catalog (predefined ∪ custom)

	/// Merges predefined library items with this design's custom items, marks
	/// which are favorited/custom, and sorts favorites first, then by key.
	/// Custom items shadow predefined items that share a key (keys should be
	/// unique across both, but this keeps the result stable if they ever collide).
	public func catalog<T: LibraryItem>(predefined: [T], custom: [T], favorites: [String]) -> [CatalogEntry<T>] {
		let favSet = Set(favorites)
		var entries: [CatalogEntry<T>] = []
		var seen = Set<String>()

		for item in custom {
			let key = item.libraryKey
			seen.insert(key)
			entries.append(CatalogEntry(item: item, key: key, isFavorite: favSet.contains(key), isCustom: true))
		}
		for item in predefined where !seen.contains(item.libraryKey) {
			let key = item.libraryKey
			entries.append(CatalogEntry(item: item, key: key, isFavorite: favSet.contains(key), isCustom: false))
		}

		return entries.sorted { lhs, rhs in
			if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
			return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
		}
	}

	public func hardwareCatalog(_ library: Library) -> [CatalogEntry<HardwareDef>] {
		catalog(predefined: Array(library.hardwareDefinitions.values), custom: customHardware, favorites: favoriteHardware)
	}

	public func serviceCatalog(_ library: Library) -> [CatalogEntry<ServiceDef>] {
		catalog(predefined: Array(library.serviceDefinitions.values), custom: customServiceDefs, favorites: favoriteServices)
	}

	public func stepCatalog(_ library: Library) -> [CatalogEntry<WorkflowDefStep>] {
		catalog(predefined: Array(library.workflowSteps.values), custom: customWorkflowSteps, favorites: favoriteSteps)
	}

	public func chainCatalog(_ library: Library) -> [CatalogEntry<WorkflowChain>] {
		catalog(predefined: Array(library.workflowChains.values), custom: customWorkflowChains, favorites: favoriteChains)
	}

	public func workflowDefCatalog(_ library: Library) -> [CatalogEntry<WorkflowDef>] {
		catalog(predefined: Array(library.workflowDefinitions.values), custom: workflowDefinitions, favorites: favoriteWorkflowDefs)
	}

	// MARK: - Favorites

	public func isFavorite(_ key: String, in keyPath: ReferenceWritableKeyPath<Design, [String]>) -> Bool {
		self[keyPath: keyPath].contains(key)
	}

	public func toggleFavorite(_ key: String, in keyPath: ReferenceWritableKeyPath<Design, [String]>) {
		if let idx = self[keyPath: keyPath].firstIndex(of: key) {
			self[keyPath: keyPath].remove(at: idx)
		} else {
			self[keyPath: keyPath].append(key)
		}
	}

	/// Idempotently marks a key as favorite. Used when creating or duplicating a
	/// custom item so it surfaces at the top of pick lists immediately instead of
	/// getting lost among the predefined items.
	public func addFavorite(_ key: String, in keyPath: ReferenceWritableKeyPath<Design, [String]>) {
		if !self[keyPath: keyPath].contains(key) {
			self[keyPath: keyPath].append(key)
		}
	}

	// MARK: - Custom item names

	/// Returns a unique "<base> copy" name not used by any predefined or custom
	/// item of the same type. Falls back to numbered suffixes on collision.
	public func uniqueCopyName(base: String, existingKeys: Set<String>) -> String {
		var candidate = "\(base) copy"
		var n = 2
		while existingKeys.contains(candidate) {
			candidate = "\(base) copy \(n)"
			n += 1
		}
		return candidate
	}

	// MARK: - Custom item CRUD (value types)

	/// Inserts or replaces a custom hardware definition (matched by `processor`).
	public func upsertCustomHardware(_ def: HardwareDef) {
		customHardware.removeAll { $0.processor == def.processor }
		customHardware.append(def)
	}

	public func removeCustomHardware(key: String) {
		customHardware.removeAll { $0.processor == key }
		favoriteHardware.removeAll { $0 == key }
	}

	/// Inserts or replaces a custom service definition (matched by `serviceType`).
	public func upsertCustomServiceDef(_ def: ServiceDef) {
		customServiceDefs.removeAll { $0.serviceType == def.serviceType }
		customServiceDefs.append(def)
	}

	public func removeCustomServiceDef(key: String) {
		customServiceDefs.removeAll { $0.serviceType == key }
		favoriteServices.removeAll { $0 == key }
		// If this service type was also in use, drop it and revalidate dependents.
		if services[key] != nil {
			services.removeValue(forKey: key)
			updateServiceProviders()
			updateWorkflowDefinitions()
		}
	}

	/// Inserts or replaces a custom workflow step (matched by `name`).
	public func upsertCustomWorkflowStep(_ step: WorkflowDefStep) {
		customWorkflowSteps.removeAll { $0.name == step.name }
		customWorkflowSteps.append(step)
	}

	public func removeCustomWorkflowStep(key: String) {
		customWorkflowSteps.removeAll { $0.name == key }
		favoriteSteps.removeAll { $0 == key }
	}

	// MARK: - Custom item CRUD (@Model: chains)
	// The caller is responsible for inserting/deleting the @Model object in the
	// SwiftData context (insert→save→append→save); these manage the relationship.

	public func addCustomChain(_ chain: WorkflowChain) {
		if customWorkflowChains.contains(chain) == false {
			customWorkflowChains.append(chain)
		}
	}

	public func removeCustomChain(_ chain: WorkflowChain) {
		customWorkflowChains.removeAll { $0 == chain }
		favoriteChains.removeAll { $0 == chain.name }
	}
	
	public func printValidationMessages() {
		guard !isValid else { debugPrint("Design is valid."); return }
		for msg in validate() {
			debugPrint(msg)
		}
		for w in workflows {
			for msg in w.validate() {
				debugPrint(msg)
			}
			for chain in w.definition.chains {
				for msg in chain.validate() {
					debugPrint(msg)
				}
			}
		}
		for sp in serviceProviders {
			for msg in sp.validate() {
				debugPrint(msg)
			}
		}
	}
}
