//
//  Design.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-27.
//

import Foundation
import SwiftData

@Model
public class Design: Described, Validatable {
	public var name: String
	public var desc: String
	public var zones: [Zone]
	public var network: [Connection]
	public var services: Dictionary<String, ServiceDef> // Just defining "map", "dbms", etc.
	public var serviceProviders: [ServiceProvider]
	public var workflowDefinitions: [WorkflowDef]
	var workflows: [Workflow] = []
	var physicalComputeNodes: [ComputeNode] = []

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
