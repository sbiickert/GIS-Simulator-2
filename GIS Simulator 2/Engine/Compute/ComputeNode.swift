//
//  ComputeNode.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-20.
//

import Foundation
import SwiftData

public nonisolated enum ComputeNodeType: String, CaseIterable, Codable {
	case client = "client"
	case host = "host"
	case vm = "vm"
}

@Model
public nonisolated class ComputeNode: Described, ServiceTimeCalculator {
	public var name: String
	public var desc: String
	public var hwDef: HardwareDef
	public var memoryGB: Int
	public var zone: Zone
	public var type: ComputeNodeType
	public var threading: ThreadingModel
	
	private var _vCores: Int = 0			// if type == .vm
	@Relationship(deleteRule: .cascade) private var _vmList: [ComputeNode] = []	// if type == .host

	// Inverse of ServiceProvider.nodes (many-to-many). Maintained by SwiftData;
	// declared so a node can be assigned to several providers at once.
	var serviceProviders: [ServiceProvider] = []

	public func attachVirtualMachine(_ vm: ComputeNode) {
		guard self.type == .host else { fatalError("Attempt to add a VM to something other than a physical host.") }
		guard vm.type == .vm else { fatalError("attachVirtualMachine requires a VM node.") }
		_vmList.append(vm)
	}
	
	public init(name: String, desc: String, hwDef: HardwareDef, memoryGB: Int, zone: Zone, type: ComputeNodeType) {
		self.name = name
		self.desc = desc
		self.hwDef = hwDef
		self.memoryGB = memoryGB
		self.zone = zone
		self.type = type
		self.threading = type == .client ? .physical : .hyperThreaded
	}

	public var vCores: Int {
		get {
			return _vCores
		}
		set {
			_vCores = self.type == .vm ? newValue : 0
		}
	}
	
	public var specIntRate2017PerCore: Double {
		return self.hwDef.specIntRate2017PerCore * self.threading.factor
	}
	
	public func adjustedServiceTime(_ st:Int) -> Int {
		let relative = HardwareDef.BaselinePerCore / self.specIntRate2017PerCore
		return Int(Double(st) * relative)
	}

	public func calculateServiceTime(for request: ClientRequest) -> Int {
		let step = request.solution.currentStep
		if let step {
			return adjustedServiceTime(step.serviceTime)
		}
		return 0
	}
	
	public func calculateLatency(for request: ClientRequest) -> Int {
		return 0
	}
	
	public func provideQueue() -> MultiQueue {
		let channelCount: Int
		switch self.type {
		case .client:
			channelCount = 1000
		case .host:
			channelCount = self.hwDef.cores
		case .vm:
			channelCount = self.vCores
		}
		return MultiQueue(serviceTimeCalculator: self, waitMode: .processing, channels: channelCount)
	}
	
	public func addVirtualMachine(name: String?, vCores: Int, memoryGB: Int) -> ComputeNode {
		if self.type != .host {
			fatalError("Attempt to add a VM to something other than a physical host.")
		}
		
		let vmName = (name == nil || name!.isEmpty) ? "\(self.name) VM \(self._vmList.count)" : name!
			
		let vm = ComputeNode(name: vmName, desc: "", hwDef: self.hwDef, memoryGB: memoryGB, zone: self.zone, type: .vm,)
		vm.vCores = vCores
		_vmList.append(vm)
		
		return vm
	}
	
	public func removeVirtualMachine(vm: ComputeNode) {
		_vmList.removeAll { $0 === vm }
	}
	
	public var vmCount: Int { return _vmList.count }
	
	public func vm(at index: Int) -> ComputeNode? {
		if index >= 0 && index < _vmList.count {
			return _vmList[index]
		}
		return nil
	}
	
	public func vm(named name: String) -> ComputeNode? {
		return _vmList.filter({$0.name == name}).first
	}
	
	public var vmList: [ComputeNode] {
		return _vmList // Should be copy on write.
	}
	
	public func isHostFor(vm: ComputeNode) -> Bool {
		return vm.type == .vm && _vmList.contains(vm)
	}
	
	public var totalVirtualCpuAllocation: Int {
		var total = 0
		for vm in _vmList {
			total += vm.vCores
		}
		return total
	}
	
	public var totalCpuAllocation: Int {
		return Int(Double(totalVirtualCpuAllocation) * threading.factor)
	}
	
	public var totalMemoryAllocation: Int {
		var total = 0
		for vm in _vmList {
			total += vm.memoryGB
		}
		return total
	}
}

