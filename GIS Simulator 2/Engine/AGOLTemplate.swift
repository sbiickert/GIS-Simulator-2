//
//  AGOLTemplate.swift
//  GIS Simulator 2
//

import Foundation

/// The recipe for provisioning ArcGIS Online in a zone, decoded from the
/// bundled agol.json: a set of identical hosts plus the service providers
/// that run on them.
public nonisolated struct AGOLTemplate: Codable {
	public struct Hardware: Codable {
		/// Library key (HardwareDef.processor) of the host hardware.
		public let definition: String
		/// Base name for the hosts; instances are suffixed " 1"…" count".
		public let name: String
		public let count: Int
		public let memoryGB: Int
	}

	public struct Provider: Codable {
		public let name: String
		public let desc: String
		/// ServiceDef.serviceType key of the service this provider offers.
		public let service: String
	}

	public let hardware: Hardware
	/// Tags applied to every created service provider (e.g. "agol").
	public let tags: [String]
	public let serviceProviders: [Provider]

	enum CodingKeys: String, CodingKey {
		case hardware
		case tags
		case serviceProviders = "service_providers"
	}

	public static func load() throws -> AGOLTemplate {
		let url = try Library.url(for: "agol", withExtension: "json")
		let data = try Data(contentsOf: url)
		return try JSONDecoder().decode(AGOLTemplate.self, from: data)
	}
}
