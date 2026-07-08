//
//  ServiceProvider.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-23.
//

import Foundation
import SwiftData

@Model
public class ServiceProvider: Described, Validatable {
	public var name: String
	public var desc: String
	public var service: ServiceDef
	public var tags: Set<String>
	@Relationship var nodes: [ComputeNode] = []
	var _primary = 0
	
	public init(name: String, desc: String, service: ServiceDef, nodes: [ComputeNode] = [], tags: Set<String> = [], _primary: Int = 0) {
		self.name = name
		self.desc = desc
		self.service = service
		self.nodes = nodes
		self.tags = tags
		self._primary = _primary
	}

	public var primary: Int {
		get {
			switch service.balancingModel {
			case .single:
				return 0
			case .failover:
				return _primary
			case .roundRobin:
				return _primary
			case .containerized:
				return _primary
			case .other:
				return _primary
			}
		}
		set {
			if newValue >= 0 && newValue < nodes.count {
				_primary = newValue
			}
		}
	}
	
	public func rotatePrimary() -> Int {
		_primary = (_primary + 1) % nodes.count
		return _primary
	}
	
	/// The node that currently handles requests. This is a pure read with no
	/// side effects, so it is safe to call from validation and SwiftUI view
	/// code. To advance the round-robin cursor, call `nextHandlerNode()`.
	public var handlerNode: ComputeNode? {
		if self.nodes.isEmpty {
			return nil
		}
		// Clamp against bad/out-of-range data so a read can never crash.
		let index = min(max(primary, 0), nodes.count - 1)
		return nodes[index]
	}

	/// Returns the node that should handle the next request, advancing the
	/// round-robin cursor as a side effect. Call this only from the simulator,
	/// never from validation or view code (mutating an `@Model` during a view
	/// body evaluation causes an infinite re-render loop).
	@discardableResult
	public func nextHandlerNode() -> ComputeNode? {
		let result = handlerNode
		if self.service.balancingModel == .roundRobin {
			let _ = rotatePrimary()
		}
		return result
	}
	
	public func addNode(_ node: ComputeNode) {
		if self.service.balancingModel == .single && self.nodes.count > 0 { return }
		if self.service.balancingModel == .failover && self.nodes.count > 1 { return }
		self.nodes.append(node)
	}
	
	public func removeNode(_ node: ComputeNode) {
		self.nodes.removeAll(where: {$0 == node})
		_primary = 0
	}
	
	public var isValid: Bool {
		return validate().isEmpty
	}
	
	public func validate() -> [ValidationMessage] {
		var messages = Array<ValidationMessage>()
		if self.nodes.isEmpty {
			messages.append(.init(message: "Service provider \(self.name) has no compute nodes.", source: "ServiceProvider \(name)", category: .serviceProviders, itemName: name))
		}
		if self.handlerNode == nil {
			messages.append(.init(message: "Service provider \(self.name) handlerNode is nil.", source: "ServiceProvider \(name)", category: .serviceProviders, itemName: name))
		}
		return messages
	}
}
