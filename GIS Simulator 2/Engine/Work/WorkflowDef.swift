//
//  WorkflowDef.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation
import SwiftData

@Model
public class WorkflowDef: Described {
	public var name: String
	public var desc: String
	public var thinkTimeSeconds: Int
	@Relationship(deleteRule: .cascade) public var chains: [WorkflowChain] = []
	
	public init(name: String, desc: String, thinkTimeSeconds: Int, chains: [WorkflowChain]) {
		self.name = name
		self.desc = desc
		self.thinkTimeSeconds = thinkTimeSeconds
		self.chains = chains
	}

	public func add(chain: WorkflowChain) {
		chains = [chain] + chains
	}
	
	public func removeChain(at index: Int) {
		guard index >= 0 && index < chains.count else {
			fatalError("Invalid index \(index)")
		}
		chains.remove(at: index)
	}
	
	public var allRequiredServiceTypes: Set<String> {
		return Set(chains.flatMap(\.allRequiredServiceTypes))
	}
	
	public func assign(serviceProvider: ServiceProvider) {
		for chain in chains {
			chain.serviceProviders[serviceProvider.service.serviceType] = serviceProvider
		}
	}
	
	public var missingServiceProviders: [String] {
		var result = Set<String>()
		for chain in chains {
			result = result.union(chain.missingServiceProviders)
		}
		return Array(result)
	}
	
	public func clearServiceProviders() {
		for chain in chains {
			chain.serviceProviders.removeAll()
		}
	}
	
	public func getChain(named name: String) -> WorkflowChain? {
		let nameUC = name.uppercased()
		return chains.first(where: { $0.name.uppercased() == nameUC })
	}
}
