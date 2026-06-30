//
//  Workflow.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-24.
//

import Foundation
import GameKit
import SwiftData

public nonisolated enum WorkflowType: String, CaseIterable, Codable {
	case user = "user"
	case transactional = "transactional"
}

@Model
public class Workflow: Described, Validatable, Hashable, Codable {
	enum CodingKeys: CodingKey {
		case name
		case desc
		case def
		case type
		case userCount
		case productivity
		case tph
	}
	
	public var name: String
	public var desc: String
	public var definition: WorkflowDef
	public var type: WorkflowType
	public var userCount: Int
	public var productivity: Int
	public var tph: Int
	
	public init(name: String, desc: String, definition: WorkflowDef, type: WorkflowType,
				userCount: Int = 0, productivity: Int = 0, tph: Int = 0) {
		self.name = name
		self.desc = desc
		self.definition = definition
		self.type = type
		self.userCount = userCount
		self.productivity = productivity
		self.tph = tph
	}
	
	required public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		name = try container.decode(String.self, forKey: .name)
		desc = try container.decode(String.self, forKey: .desc)
		definition = try container.decode(WorkflowDef.self, forKey: .def)
		type = try container.decode(WorkflowType.self, forKey: .type)
		userCount = try container.decode(Int.self, forKey: .userCount)
		productivity = try container.decode(Int.self, forKey: .productivity)
		tph = try container.decode(Int.self, forKey: .tph)
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(name, forKey: .name)
		try container.encode(desc, forKey: .desc)
		try container.encode(definition, forKey: .def)
		try container.encode(type, forKey: .type)
		try container.encode(userCount, forKey: .userCount)
		try container.encode(productivity, forKey: .productivity)
		try container.encode(tph, forKey: .tph)
	}

	public static func == (lhs: Workflow, rhs: Workflow) -> Bool {
		return lhs.name == rhs.name && lhs.definition == rhs.definition
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(name)
		hasher.combine(definition)
	}
	
	public var transactionRate: Int {
		switch type {
		case .user:
			return userCount * productivity * 60
		case .transactional:
			return tph
		}
	}
	
	public func createClientRequests(network: [Connection], clock: Int) -> (Transaction, [ClientRequest]) {
		let tx = Transaction(requestClock: clock, workflow: self)
		var reqs: [ClientRequest] = []
		
		for chain in definition.chains {
			let solution = Workflow.createSolution(chain: chain, network: network)
			let request = ClientRequest(name: ClientRequest.nextName,
										desc: "",
										workflowName: name,
										requestClock: clock,
										solution: solution,
										txID: tx.id)
			reqs.append(request)
		}
		return (tx, reqs)
	}
	
	var _random: GKRandomSource {
		GKRandomSource()
	}

	public func calculateNextEventTime(clock: Int) -> Int {
		let msPerEvent = 3600000.0 / Float(transactionRate)
		let distribution = GKGaussianDistribution(randomSource: _random, mean: msPerEvent, deviation: msPerEvent * 0.25)
		return distribution.nextInt() + clock
	}
	
	public var isValid: Bool {
		return validate().isEmpty
	}
	
	public func validate() -> [ValidationMessage] {
		var result = [ValidationMessage]()
		
		if definition.chains.isEmpty {
			result.append(ValidationMessage(message: "Workflow must have at least one chain.", source: self.name))
		}
		
		let invalidChains = definition.chains.filter({$0.isValid == false})
		for chain in invalidChains {
			result.append(ValidationMessage(message: "Workflow chain \(chain.name) is invalid.", source: self.name))
		}
		
		if transactionRate <= 0 {
			result.append(ValidationMessage(message: "Transaction rate must be greater than 0.", source: self.name))
		}
		
		return result
	}
	
	static func createSolution(chain: WorkflowChain, network: [Connection]) -> ClientRequestSolution {
		if chain.isValid == false { fatalError("Chain \(chain.name) passed to createSolution must be valid.") }
		
		// Starting at the head of the chain (client), stop at each
		// service provider, traversing the network between each
		var step = chain.steps.first!
		var sourceSP = chain.serviceProvider(for: step)
		if sourceSP == nil { fatalError("Chain \(chain.name) has a step (\(step.name)) that doesn't have a corresponding service provider.") }
		var sourceNode = sourceSP!.nextHandlerNode()
		if sourceNode == nil { fatalError("Service provider \(sourceSP!.name) has no handler node.") }
		
		// Keep track of compute nodes to retrace steps
		var handlerNodes = [ComputeNode]()
		
		var crSteps = [ClientRequestSolutionStep]()
		crSteps.append(ClientRequestSolutionStep(serviceTimeCalculator: sourceNode!,
												 isResponse: false,
												 dataSize: step.requestSizeKB,
												 chatter: 0,
												 serviceTime: step.serviceTime))
		handlerNodes.append(sourceNode!)
		
		for i in 1..<chain.steps.count {
			step = chain.steps[i]
			
			let destSP = chain.serviceProvider(for: step)
			if destSP == nil { fatalError("Chain \(chain.name) has a step (\(step.name)) that doesn't have a corresponding service provider.") }
			let destNode = destSP!.nextHandlerNode()
			if destNode == nil { fatalError("Service provider \(destSP!.name) has no handler node.") }
			
			if sourceNode != destNode {
				let route = Route.findRoute(from: sourceNode!.zone, to: destNode!.zone, in: network)
				if route == nil { fatalError("Could not find route from \(sourceNode!.zone) to \(destNode!.zone)") }
				
				// Add the network steps
				for conn in route!.connections {
					crSteps.append(ClientRequestSolutionStep(serviceTimeCalculator: conn,
															 isResponse: false,
															 dataSize: step.requestSizeKB,
															 chatter: step.chatter,
															 serviceTime: 0))
				}
			}
			
			// Add the next compute step
			crSteps.append(ClientRequestSolutionStep(serviceTimeCalculator: destNode!,
													 isResponse: false,
													 dataSize: step.requestSizeKB,
													 chatter: step.chatter,
													 serviceTime: step.serviceTime))
			
			handlerNodes.append(destNode!)
			sourceSP = destSP
			sourceNode = destNode
		}
		
		// Now retrace back to the client
		_ = handlerNodes.removeLast()
		
		for i in stride(from: chain.steps.count - 2, to: -1, by: -1) {
			step = chain.steps[i]
			let destNode = handlerNodes.removeLast()
			
			if sourceNode != destNode {
				let route = Route.findRoute(from: sourceNode!.zone, to: destNode.zone, in: network)
				if route == nil { fatalError("Could not find route from \(sourceNode!.zone) to \(destNode.zone)") }

				// Add the network steps
				for conn in route!.connections {
					crSteps.append(ClientRequestSolutionStep(serviceTimeCalculator: conn,
															 isResponse: true,
															 dataSize: step.responseSizeKB,
															 chatter: step.chatter,
															 serviceTime: 0)) // Service time is based on data size
				}
			}
			
			// Add the next compute step
			crSteps.append(ClientRequestSolutionStep(serviceTimeCalculator: destNode,
													 isResponse: true,
													 dataSize: step.responseSizeKB,
													 chatter: step.chatter,
													 serviceTime: step.serviceTime))

			sourceNode = destNode
		}
		return ClientRequestSolution(steps: crSteps)
	}
}
