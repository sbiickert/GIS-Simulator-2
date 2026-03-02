//
//  ServiceDefTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-03.
//

import Testing
@testable import GIS_Simulator_2

struct ServiceDefTest {

    @Test func createServiceDefinition() async throws {
        
    }

	public static var sampleServiceTypes: [String] {
		return ["pro", "browser", "map", "feature", "image",
				"geocode", "geoevent", "geometry", "gp",
				"network", "scene", "sync", "stream",
				"ranalytics", "un", "custom", "vdi",
				"web", "portal", "dbms", "relational",
				"object", "stbds", "file", "mobile"]
	}
	
	public static func sampleService(type: String) -> ServiceDef {
		switch type {
		case "pro":
			return ServiceDef(name: "Pro", desc: "Sample Pro", serviceType: type, balancingModel: .single)
		case "browser":
			return ServiceDef(name: "Browser", desc: "Sample Browser", serviceType: type, balancingModel: .single)
		case "mobile":
			return ServiceDef(name: "Mobile", desc: "Sample App", serviceType: type, balancingModel: .single)
		case "map":
			return ServiceDef(name: "Map", desc: "Sample Map", serviceType: type, balancingModel: .roundRobin)
		case "feature":
			return ServiceDef(name: "Feature", desc: "Sample Feature", serviceType: type, balancingModel: .roundRobin)
		case "image":
			return ServiceDef(name: "Image", desc: "Sample Image", serviceType: type, balancingModel: .roundRobin)
		case "geocode":
			return ServiceDef(name: "Geocode", desc: "Sample Geocode", serviceType: type, balancingModel: .roundRobin)
		case "geoevent":
			return ServiceDef(name: "Geoevent", desc: "Sample Geoevent", serviceType: type, balancingModel: .single)
		case "geometry":
			return ServiceDef(name: "Geometry", desc: "Sample Geometry", serviceType: type, balancingModel: .roundRobin)
		case "gp":
			return ServiceDef(name: "GP", desc: "Sample GP", serviceType: type, balancingModel: .roundRobin)
		case "network":
			return ServiceDef(name: "Network", desc: "Sample Network", serviceType: type, balancingModel: .roundRobin)
		case "scene":
			return ServiceDef(name: "Scene", desc: "Sample Scene", serviceType: type, balancingModel: .roundRobin)
		case "sync":
			return ServiceDef(name: "Sync", desc: "Sample Sync", serviceType: type, balancingModel: .roundRobin)
		case "stream":
			return ServiceDef(name: "Stream", desc: "Sample Stream", serviceType: type, balancingModel: .roundRobin)
		case "ranalytics":
			return ServiceDef(name: "Ranalytics", desc: "Sample Ranalytics", serviceType: type, balancingModel: .roundRobin)
		case "un":
			return ServiceDef(name: "UN", desc: "Sample UN", serviceType: type, balancingModel: .roundRobin)
		case "custom":
			return ServiceDef(name: "Custom", desc: "Sample Custom", serviceType: type, balancingModel: .single)
		case "vdi":
			return ServiceDef(name: "Vdi", desc: "Sample VDI", serviceType: type, balancingModel: .failover)
		case "web":
			return ServiceDef(name: "Web", desc: "Sample Web", serviceType: type, balancingModel: .roundRobin)
		case "portal":
			return ServiceDef(name: "Portal", desc: "Sample Portal", serviceType: type, balancingModel: .failover)
		case "dbms":
			return ServiceDef(name: "DBMS", desc: "Sample DBMS", serviceType: type, balancingModel: .failover)
		case "relational":
			return ServiceDef(name: "Relational", desc: "Sample Relational", serviceType: type, balancingModel: .failover)
		case "object":
			return ServiceDef(name: "Object", desc: "Sample Object", serviceType: type, balancingModel: .failover)
		case "stbds":
			return ServiceDef(name: "STBDS", desc: "Sample Spatio-Temporal Data Store", serviceType: type, balancingModel: .roundRobin)
		case "file":
			return ServiceDef(name: "File", desc: "Sample File", serviceType: type, balancingModel: .failover)
		default:
			return ServiceDef(name: "None", desc: "Invalid", serviceType: type, balancingModel: .single)		}
	}
}
