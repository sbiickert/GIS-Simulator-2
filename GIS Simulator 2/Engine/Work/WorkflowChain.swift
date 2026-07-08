//
//  WorkflowChain.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation
import SwiftData

@Model
public class WorkflowChain: Described, Validatable {
	public var name: String
	public var desc: String
	public var steps: [WorkflowDefStep]
	// Persisted as a real relationship so the chain references the design's own
	// ServiceProvider objects. Storing them in a dictionary attribute would make
	// SwiftData persist encoded copies, severing object identity on reload.
	@Relationship private var _serviceProviders: [ServiceProvider] = []

	/// Dictionary-style access to the chain's providers, keyed by service type.
	public var serviceProviders: Dictionary<String, ServiceProvider> {
		get {
			Dictionary(_serviceProviders.map { ($0.service.serviceType, $0) },
					   uniquingKeysWith: { first, _ in first })
		}
		set {
			_serviceProviders = Array(newValue.values)
		}
	}

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
		self._serviceProviders = Array(serviceProviders.values)
	}


	public var isValid: Bool {
		validate().isEmpty
	}
	
	public func validate() -> [ValidationMessage] {
		var messages: [ValidationMessage] = []
		
		if hasDuplicateServiceProviders {
			messages.append(ValidationMessage(message: "Duplicate service providers found", source: name, category: .workflows))
		}
		if missingServiceProviders.isEmpty == false {
			messages.append(contentsOf: missingServiceProviders.map({
				ValidationMessage(message: "Missing service provider for \($0)", source: name, category: .workflows)
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
		let configuredServiceTypes = Set(_serviceProviders.map { $0.service.serviceType })
		return configuredServiceTypes.count != _serviceProviders.count
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
