//
//  Zone.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-20.
//

import Foundation
import SwiftData

public nonisolated enum ZoneConnectionStatus: CaseIterable {
	case None
	case ExitOnly
	case EnterOnly
	case Both
	case Indirect
}

@Model
public class Zone: Described, Codable {
	enum CodingKeys: CodingKey {
		case name
		case desc
	}
	
	//private let id: UUID = UUID()
	public var name: String
	public var desc: String
	
	init(name: String, description: String) {
		self.name = name
		self.desc = description
	}
	
	required public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		name = try container.decode(String.self, forKey: .name)
		desc = try container.decode(String.self, forKey: .desc)
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(name, forKey: .name)
		try container.encode(desc, forKey: .desc)
	}
	
	public func connect(to destination:Zone, bandwidth: Int, latency: Int) -> Connection {
		return Connection(source: self, destination: destination, bandwidthMbps: bandwidth, latencyMs: latency)
	}
	
	public func connectBothWays(to destination:Zone, bandwidth: Int, latency: Int) -> [Connection] {
		let c1 = self.connect(to: destination, bandwidth: bandwidth, latency: latency)
		let c2 = c1.inverted()
		return [c1, c2]
	}
	
	public func selfConnect(bandwidth: Int, latency: Int) -> Connection {
		return Connection(source: self, destination: self, bandwidthMbps: bandwidth, latencyMs: latency)
	}
	
	public func localConnection(in network:[Connection]) -> Connection? {
		return network.first(where: { $0.source == self && $0.destination == self })
	}
	
	public func connections(in network:[Connection]) -> [Connection] {
		return network.filter({$0.source == self || $0.destination == self})
	}
	
	public func entryConnections(in network:[Connection]) -> [Connection] {
		return network.filter({$0.source != self && $0.destination == self})
	}
	
	public func exitConnections(in network:[Connection]) -> [Connection] {
		return network.filter({$0.source == self && $0.destination != self})
	}
	
	public func otherConnections(in network:[Connection]) -> [Connection] {
		return network.filter({$0.source != self && $0.destination != self})
	}

	public func isSource(in network:[Connection]) -> Bool {
		return network.contains(where: { $0.source == self })
	}

	public func isDestination(in network:[Connection]) -> Bool {
		return network.contains(where: { $0.destination == self })
	}

	public func isFullyConnected(in network:[Connection]) -> Bool {
		guard localConnection(in: network) != nil else { return false }
		let allZones = Zone.allZones(in: network)
		// A single-zone network is fully connected if it has its self-connection
		if allZones.count <= 1 { return true }
		return entryConnections(in: network).count > 0 &&
			exitConnections(in: network).count > 0
	}
	
	public func connectionStatus(to other:Zone, in network:[Connection]) -> ZoneConnectionStatus {
		let exits = exitConnections(in: network)
		let entries = entryConnections(in: network)
		if exits.contains(where: {$0.destination == other}) {
			if entries.contains(where: {$0.source == other}) {
				return .Both
			}
			return .ExitOnly
		}
		if entries.contains(where: {$0.source === other}) {
			return .EnterOnly
		}
		if let _ = Route.findRoute(from: self, to: other, in: network) {
			return .Indirect
		}
		return .None
	}
	
	public func computeNodes(in computeNodes:[ComputeNode]) -> [ComputeNode] {
		return computeNodes.filter {$0.zone === self}
	}
	
	static func allZones(in network:[Connection]) -> Set<Zone> {
		var zones:Set<Zone> = []
		for connection in network {
			zones.insert(connection.source)
			zones.insert(connection.destination)
		}
		return zones
	}
}
