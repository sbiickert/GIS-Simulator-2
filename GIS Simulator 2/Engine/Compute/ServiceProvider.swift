//
//  ServiceProvider.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-23.
//

import Foundation
import SwiftData

@Model
public class ServiceProvider: Described, Validatable, Hashable, Codable {
	enum CodingKeys: CodingKey {
		case name
		case desc
		case service
		case tags
		case nodes
		case primary
	}
	
	public var name: String
	public var desc: String
	public var service: ServiceDef
	public var tags: Set<String>
	var nodes: [ComputeNode]
	var _primary = 0
	
	public init(name: String, desc: String, service: ServiceDef, nodes: [ComputeNode] = [], tags: Set<String> = [], _primary: Int = 0) {
		self.name = name
		self.desc = desc
		self.service = service
		self.nodes = nodes
		self.tags = tags
		self._primary = _primary
	}
	
	required public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		name = try container.decode(String.self, forKey: .name)
		desc = try container.decode(String.self, forKey: .desc)
		service = try container.decode(ServiceDef.self, forKey: .service)
		tags = try container.decode(Set.self, forKey: .tags)
		nodes = try container.decode(Array.self, forKey: .nodes)
		_primary = try container.decode(Int.self, forKey: .primary)
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(name, forKey: .name)
		try container.encode(desc, forKey: .desc)
		try container.encode(service, forKey: .service)
		try container.encode(tags, forKey: .tags)
		try container.encode(nodes, forKey: .nodes)
		try container.encode(_primary, forKey: .primary)
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
	
	public var handlerNode: ComputeNode? {
		if self.nodes.isEmpty {
			return nil
		}
		let result = nodes[primary]
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
			messages.append(.init(message: "Service provider \(self.name) has no compute nodes.", source: "ServiceProvider \(name)"))
		}
		if self.handlerNode == nil {
			messages.append(.init(message: "Service provider \(self.name) handlerNode is nil.", source: "ServiceProvider \(name)"))
		}
		return messages
	}
	
	public static func == (lhs: ServiceProvider, rhs: ServiceProvider) -> Bool {
		return lhs.name == rhs.name && lhs.service == rhs.service
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(name)
		hasher.combine(service)
	}
	
}
