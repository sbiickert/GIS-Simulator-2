//
//  ComputeNodeTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-03.
//

import Testing
@testable import GIS_Simulator_2

struct ComputeNodeTest {

    @Test func createCompute() async throws {
        let client = ComputeNodeTest.sampleClient
		#expect(client.name == "Client 001")
		let phone = ComputeNodeTest.sampleMobile
		#expect(phone.memoryGB == 8)
		let host = ComputeNodeTest.sampleHost
		#expect(host.name == "Host 001")
		let vm = ComputeNodeTest.sampleVM
		#expect(vm.vCores == 4)
		
		#expect(host.vmCount == 1)
		#expect(host.totalCpuAllocation == 2)
		#expect(host.totalVirtualCpuAllocation == 4)
		#expect(host.totalMemoryAllocation == 16)
		
		let temp = await host.vm(at: 0)
		#expect(temp != nil)
		if let temp = temp {
			#expect(temp.name == "Host 001 VM 0")
		}
    }
	
	private static var _sampleClient: ComputeNode? = nil
	public static var sampleClient: ComputeNode {
		if _sampleClient == nil {
			_sampleClient = ComputeNode(name: "Client 001", desc: "Sample PC",
										hwDef: HardwareDefTest.sampleClientHardwareDef,
										memoryGB: 16,
										zone: ZoneTest.sampleIntranetZone,
										type: .client)
		}
		return _sampleClient!
	}
	
	private static var _sampleMobile: ComputeNode? = nil
	public static var sampleMobile: ComputeNode {
		if _sampleMobile == nil {
			_sampleMobile = ComputeNode(name: "Mobile 001", desc: "Sample Phone",
										hwDef: HardwareDefTest.sampleMobileHardwareDef,
										memoryGB: 8,
										zone: ZoneTest.sampleInternetZone,
										type: .client)
		}
		return _sampleMobile!
	}
	
	private static var _sampleHost: ComputeNode? = nil
	public static var sampleHost: ComputeNode {
		if _sampleHost == nil {
			_sampleHost = ComputeNode(name: "Host 001", desc: "Sample Server",
										hwDef: HardwareDefTest.sampleServerHardwareDef,
										memoryGB: 64,
										zone: ZoneTest.sampleIntranetZone,
										type: .host)
		}
		return _sampleHost!
	}
	
	private static var _sampleVM: ComputeNode? = nil
	public static var sampleVM: ComputeNode {
		if _sampleVM == nil {
			_sampleVM = sampleHost.addVirtualMachine(name: nil, vCores: 4, memoryGB: 16)
		}
		return _sampleVM!
	}

}
