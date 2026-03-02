//
//  WorkflowChain.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation
import SwiftData

@Model
public class WorkflowChain: Described, Validatable, Codable {
	enum CodingKeys: CodingKey {
		case name
		case desc
		case steps
		case sps
	}
	
	public var name: String
	public var desc: String
	public var steps: [WorkflowDefStep]
	public var serviceProviders: Dictionary<String, ServiceProvider>
	
	public init(name: String, description: String, steps: [WorkflowDefStep], serviceProviders: Dictionary<String, ServiceProvider>,
				addClient cWDS: WorkflowDefStep? = nil) {
		self.name = name
		self.desc = description
		if let cWDS = cWDS {
			self.steps = [cWDS] + steps
		}
		else {
			self.steps = steps
		}
		self.serviceProviders = serviceProviders
	}

	required public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		name = try container.decode(String.self, forKey: .name)
		desc = try container.decode(String.self, forKey: .desc)
		steps = try container.decode(Array.self, forKey: .steps)
		serviceProviders = try container.decode(Dictionary.self, forKey: .sps)
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(name, forKey: .name)
		try container.encode(desc, forKey: .desc)
		try container.encode(steps, forKey: .steps)
		try container.encode(serviceProviders, forKey: .sps)
	}


	public var isValid: Bool {
		validate().isEmpty
	}
	
	public func validate() -> [ValidationMessage] {
		var messages: [ValidationMessage] = []
		
		if hasDuplicateServiceProviders {
			messages.append(ValidationMessage(message: "Duplicate service providers found", source: name))
		}
		if missingServiceProviders.isEmpty == false {
			messages.append(contentsOf: missingServiceProviders.map({
				ValidationMessage(message: "Missing service provider for \($0)", source: name)
			}))
		}
		
		return messages
	}
	
	public func set(clientStep cWDS: WorkflowDefStep) {
		steps.insert(cWDS, at: 0)
	}
	
	public func replace(clientStep cWDS: WorkflowDefStep) {
		steps.removeFirst()
		set(clientStep: cWDS)
	}
	
	public var allRequiredServiceTypes: Set<String> {
		return Set(steps.map({ $0.serviceType }))
	}
	
	public var configuredServiceTypes: Set<String> {
		return Set(serviceProviders.keys)
	}
	
	public var missingServiceProviders: [String] {
		let allRequired = allRequiredServiceTypes
		let configured = Set(serviceProviders.keys)
		return Array(allRequired.subtracting(configured))
	}
	
	private var hasDuplicateServiceProviders: Bool {
		let configuredServiceTypes = Set(serviceProviders.keys)
		return configuredServiceTypes.count != serviceProviders.count
	}
	
	public func serviceProviderForStep(at index:Int) -> ServiceProvider? {
		guard index >= 0 && index < steps.count else {
			fatalError()
		}
		return serviceProviders[steps[index].serviceType]
	}
	
	public func serviceProvider(for step: WorkflowDefStep) -> ServiceProvider? {
		return serviceProviders[step.serviceType]
	}
}
