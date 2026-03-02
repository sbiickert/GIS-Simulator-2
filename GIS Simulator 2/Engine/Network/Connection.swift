//
//  Connection.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-20.
//

import Foundation
import SwiftData

@Model
public class Connection: Described, ServiceTimeCalculator, Equatable, Codable {
	enum CodingKeys: CodingKey {
		case source
		case destination
		case bandwidth
		case latency
	}
	
	public var name: String {
		get {
			"\(source.name) to \(destination.name)"
		}
		set {}
	}
	public var desc: String {
	get {
		   "\(source.desc) to \(destination.desc)"
	   }
	   set {}
	}
	
	public var source: Zone
	public var destination: Zone
	public var bandwidthMbps: Int
	public var latencyMs: Int
	
	public static func == (lhs: Connection, rhs: Connection) -> Bool {
		lhs.name == rhs.name
	}
	
	init(source: Zone, destination: Zone, bandwidthMbps: Int = 1000, latencyMs: Int = 0) {
		self.source = source
		self.destination = destination
		self.bandwidthMbps = bandwidthMbps
		self.latencyMs = latencyMs
	}
	
	public required init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		source = try container.decode(Zone.self, forKey: .source)
		destination = try container.decode(Zone.self, forKey: .destination)
		bandwidthMbps = try container.decode(Int.self, forKey: .bandwidth)
		latencyMs = try container.decode(Int.self, forKey: .latency)
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(source, forKey: .source)
		try container.encode(destination, forKey: .destination)
		try container.encode(bandwidthMbps, forKey: .bandwidth)
		try container.encode(latencyMs, forKey: .latency)
	}

	func inverted() -> Connection {
		return Connection(source: destination, destination: source, bandwidthMbps: bandwidthMbps, latencyMs: latencyMs)
	}
	public func calculateServiceTime(for request: ClientRequest) -> Int {
		if let step = request.solution.currentStep {
			let dataKb = step.dataSize * 8
			// Mbps -> kbps -> kb per millisecond (which is the time scale of the simulation)
			let bwKbpms = self.bandwidthMbps * 1000 / 1000
			return dataKb / bwKbpms
		}
		return 0
	}
	
	public func calculateLatency(for request: ClientRequest) -> Int {
		if let step = request.solution.currentStep {
			return self.latencyMs * step.chatter
		}
		return 0
	}
	
	public func provideQueue() -> MultiQueue {
		return MultiQueue(serviceTimeCalculator: self, waitMode: .transmitting, channels: 2)
	}

}
