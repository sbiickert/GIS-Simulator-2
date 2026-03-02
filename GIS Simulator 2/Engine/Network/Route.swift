//
//  Route.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-20.
//

import Foundation

public class Route: CustomStringConvertible {
	init(connections: [Connection]) {
		self.connections = connections
	}
	
	public var description: String {
		return connections.map(\.name).joined(separator: ", ")
	}
	
	public var connections: [Connection]

	public static func zoneIsSource(_ zone: Zone, in network: [Connection]) -> Bool {
		network.contains(where: {$0.source == zone})
	}
	
	public static func zoneIsDistination(_ zone: Zone, in network: [Connection]) -> Bool {
		network.contains(where: {$0.destination == zone})
	}
	
	public static func findRoute(from source: Zone, to destination: Zone, in network: [Connection]) -> Route? {
		if !zoneIsSource(source, in: network) || !zoneIsDistination(destination, in: network) {
			return nil
		}
		else if source.localConnection(in: network) == nil {
			return nil
		}
		// Depth-first search
		let path = findRouteDFS(from: source, to: destination, in: network, visited: Set([source]), path: [source.localConnection(in: network)!])
		if !path.isEmpty && path.last!.destination == destination {
			return Route(connections: path)
		}
		return nil
	}
	
	private static func findRouteDFS(from source: Zone,
									 to destination: Zone,
									 in network: [Connection],
									 visited: Set<Zone>,
									 path: [Connection]) -> [Connection] {
		if source == destination {
			return path
		}
		
		// Originally had this as a long chain, but the compiler was complaining
		// Having intermediate variables helps with the readability anyways
		let exits = source.exitConnections(in: network)
		let exitsToUnvisitedZones = exits.filter({!visited.contains($0.destination)})
		let recursionResults: [[Connection]] = exitsToUnvisitedZones
			.map({ exit in
				let extendedPath = path + [exit]
				let extendedVisited = visited.union([exit.destination])
				return findRouteDFS(from: exit.destination, to: destination, in: network, visited: extendedVisited, path: extendedPath)
			})
		let resultsEndingAtDestination: [[Connection]] = recursionResults
			.filter({ !$0.isEmpty && $0.last!.destination == destination })
		let shortestPath = resultsEndingAtDestination
			.sorted(by: {$0.count < $1.count})
		
		return shortestPath.first ?? [] // i.e. the shortest or an empty result
	}
}
