//
//  Library.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-03-31.
//

import Foundation
import TabularData

public enum LibraryError: Error {
	case missingResource(resource: String, ext: String)
	case csvReadError(_ error: String)
}

public enum NetworkName: CaseIterable {
	case localOnly
	case localAndAGOL
	case branchOffices
	case cloudy
	case backhaulCloudy
}

public class Library {
	static func url(for resource: String, withExtension ext: String) throws -> URL {
		if let url = Bundle.main.url(forResource: resource, withExtension: ext) {
			return url
		}
		throw LibraryError.missingResource(resource: resource, ext: ext)
	}
	
	static func readCSV(filename: String) throws -> DataFrame? {
		guard let url = try? Library.url(for: filename, withExtension: "csv") else {
			return nil
		}

		do {
			// Automatically reads and parses the CSV into a DataFrame structure
			let dataFrame = try DataFrame(contentsOfCSVFile: url, options: CSVReadingOptions(hasHeaderRow: true))
			return dataFrame
		} catch {
			throw LibraryError.csvReadError("Error reading CSV file in Library: \(error)")
		}
	}
	
	public init() {
		
	}
	
	private var _hardwareDefinitions: Dictionary<String, HardwareDef> = [:]
	public var hardwareDefinitions: [String: HardwareDef] {
		if _hardwareDefinitions.isEmpty {
			do { try loadLocalData() } catch { print("Error loading local data: \(error)")}
		}
		return _hardwareDefinitions
	}
	
	private var _serviceDefinitions: Dictionary<String, ServiceDef> = [:]
	public var serviceDefinitions: [String: ServiceDef] {
		if _serviceDefinitions.isEmpty {
			do { try loadLocalData() } catch { print("Error loading local data: \(error)")}
		}
		return _serviceDefinitions
	}
	
	private var _workflowSteps: Dictionary<String, WorkflowDefStep> = [:]
	public var workflowSteps: [String: WorkflowDefStep] {
		if _workflowSteps.isEmpty {
			do { try loadLocalData() } catch { print("Error loading local data: \(error)")}
		}
		return _workflowSteps
	}
	
	private var _workflowChains: Dictionary<String, WorkflowChain> = [:]
	public var workflowChains: [String: WorkflowChain] {
		if _workflowChains.isEmpty {
			do { try loadLocalData() } catch { print("Error loading local data: \(error)")}
		}
		return _workflowChains
	}
	
	private var _workflowDefinitions: Dictionary<String, WorkflowDef> = [:]
	public var workflowDefinitions: [String: WorkflowDef] {
		if _workflowDefinitions.isEmpty {
			do { try loadLocalData() } catch { print("Error loading local data: \(error)")}
		}
		return _workflowDefinitions
	}

	private func loadLocalData() throws {
		try loadHardwareDefsLocal()
		try loadServiceDefsLocal()
		try loadWorkflowStepsLocal()
		try loadWorkflowChainsLocal()
		try loadWorkflowDefsLocal()
	}
	
	private func loadHardwareDefsLocal() throws {
		_hardwareDefinitions.removeAll()
		do {
			if let data = try Library.readCSV(filename: "hardware") {
				for row in data.rows {
					let hw = HardwareDef(processor: row["processor"] as! String,
										 cores: row["cores"] as! Int,
										 specIntRate2017: row["spec"] as! Double)
					_hardwareDefinitions[hw.processor] = hw
				}
			}
		} catch { throw error }
	}
	
	private func loadServiceDefsLocal() throws {
		_serviceDefinitions.removeAll()
		do {
			if let data = try Library.readCSV(filename: "services") {
				for row in data.rows {
					let s = ServiceDef(name: row["name"] as! String,
									   desc: row["description"] as! String,
									   serviceType: row["service_type"] as! String,
									   balancingModel: BalancingModel(rawValue: row["balancing_model"] as! String)!)
					_serviceDefinitions[s.serviceType] = s
				}
			}
		} catch { throw error }
	}
	
	private func loadWorkflowStepsLocal() throws {
		_workflowSteps.removeAll()
		do {
			if let data = try Library.readCSV(filename: "workflow_steps") {
				for row in data.rows {
					let step = WorkflowDefStep(name: row["name"] as! String,
											   desc: row["description"] as! String,
											   serviceType: row["type"] as! String,
											   serviceTime: row["st"] as! Int,
											   chatter: row["chatter"] as! Int,
											   requestSizeKB: row["req_kbytes"] as! Int,
											   responseSizeKB: row["resp_kbytes"] as! Int,
											   dataSourceType: DataSourceType(rawValue: row["data_store"] as! String)!,
											   cachePercent: row["cache_pct"] as! Int)
					_workflowSteps[step.name] = step
				}
			}
		}
	}
	
	private func loadWorkflowChainsLocal() throws {
		_workflowChains.removeAll()
		do {
			if let data = try Library.readCSV(filename: "workflow_chains") {
				for row in data.rows {
					// The steps cell is ";"-delimited (no space, unlike the workflows
					// CSV's chains cell). Trim each name so either form parses.
					let names = (row["steps"] as! String)
						.split(separator: ";")
						.map { $0.trimmingCharacters(in: .whitespaces) }
					let steps: [WorkflowDefStep] = names.compactMap { _workflowSteps[$0] }
					let chain = WorkflowChain(name: row["name"] as! String,
											  description: row["description"] as! String,
											  steps: steps,
											  serviceProviders: [:])
					_workflowChains[chain.name] = chain
				}
			}
		}
	}
	
	private func loadWorkflowDefsLocal() throws {
		_workflowDefinitions.removeAll()
		do {
			if let data = try Library.readCSV(filename: "workflows") {
				for row in data.rows {
					let names = (row["chains"] as! String).split(separator: "; ").map(String.init)
					let chains = names.compactMap { _workflowChains[$0] }
					let wDef = WorkflowDef(name: row["name"] as! String,
										   desc: row["description"] as! String,
										   thinkTimeSeconds: row["think"] as! Int,
										   chains: chains)
					_workflowDefinitions[wDef.name] = wDef
				}
			}
		}
	}
	
	public func getNetwork(named name:NetworkName) -> ([Zone], [Connection]) {
		var zones = [Zone]()
		var connections = [Connection]()
		
		let lan = Zone(name: "Local", description: "Local Network")
		let lanLocal = lan.selfConnect(bandwidth: 1000, latency: 0)
		
		let dmz = Zone(name: "DMZ", description: "Edge Network")
		let dmzLocal = dmz.selfConnect(bandwidth: 1000, latency: 0)
		
		let internet = Zone(name: "Internet", description: "Internet")
		let internetLocal = internet.selfConnect(bandwidth: 10000, latency: 10)
		
		let agol = Zone(name: "ArcGIS Online", description: "AWS US West")
		let agolLocal = agol.selfConnect(bandwidth: 10000, latency: 0)
		
		let cloud = Zone(name: "Cloud", description: "Public Cloud")
		let cloudLocal = cloud.selfConnect(bandwidth: 1000, latency: 0)
		
		let cloudEdge = Zone(name: "Gateway", description: "Cloud Gateway")
		let cloudEdgeLocal = cloudEdge.selfConnect(bandwidth: 1000, latency: 0)
		
		let wan1 = Zone(name: "WAN 1", description: "Branch Office #1")
		let wan1Local = wan1.selfConnect(bandwidth: 100, latency: 0)
		
		let wan2 = Zone(name: "WAN 2", description: "Branch Office #2")
		let wan2Local = wan2.selfConnect(bandwidth: 100, latency: 0)
		
		switch name {
		case .localOnly:
			zones.append(lan)
			connections.append(lanLocal)
		case .localAndAGOL:
			zones.append(contentsOf: [lan, dmz, internet, agol])
			connections.append(contentsOf: [lanLocal, dmzLocal, internetLocal, agolLocal])
			connections.append(contentsOf: lan.connectBothWays(to: dmz, bandwidth: 500, latency: 1))
			connections.append(dmz.connect(to: internet, bandwidth: 250, latency: 10))
			connections.append(internet.connect(to: dmz, bandwidth: 500, latency: 10))
			connections.append(contentsOf: internet.connectBothWays(to: agol, bandwidth: 10000, latency: 1))
		case .branchOffices:
			zones.append(contentsOf: [lan, wan1, wan2])
			connections.append(contentsOf: [lanLocal, wan1Local, wan2Local])
			connections.append(contentsOf: lan.connectBothWays(to: wan1, bandwidth: 300, latency: 1))
			connections.append(contentsOf: lan.connectBothWays(to: wan2, bandwidth: 100, latency: 10))
		case .cloudy:
			zones.append(contentsOf: [cloud, cloudEdge, internet, agol])
			connections.append(contentsOf: [cloudLocal, cloudEdgeLocal, internetLocal, agolLocal])
			connections.append(contentsOf: cloud.connectBothWays(to: cloudEdge, bandwidth: 1000, latency: 0))
			connections.append(contentsOf: cloudEdge.connectBothWays(to: internet, bandwidth: 1000, latency: 10))
			connections.append(contentsOf: internet.connectBothWays(to: agol, bandwidth: 10000, latency: 1))
		case .backhaulCloudy:
			zones.append(contentsOf: [lan, dmz, internet, agol, cloud, cloudEdge])
			connections.append(contentsOf: [lanLocal, dmzLocal, internetLocal, agolLocal, cloudLocal, cloudEdgeLocal])
			connections.append(contentsOf: lan.connectBothWays(to: dmz, bandwidth: 500, latency: 1))
			connections.append(contentsOf: dmz.connectBothWays(to: internet, bandwidth: 250, latency: 10))
			connections.append(contentsOf: internet.connectBothWays(to: agol, bandwidth: 1000, latency: 1))
			connections.append(contentsOf: cloud.connectBothWays(to: cloudEdge, bandwidth: 1000, latency: 0))
			connections.append(contentsOf: cloudEdge.connectBothWays(to: internet, bandwidth: 1000, latency: 10))
			connections.append(contentsOf: lan.connectBothWays(to: cloud, bandwidth: 1000, latency: 5))
		}
		
		return (zones, connections)
	}
}
