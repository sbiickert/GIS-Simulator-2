//
//  HardwareDefTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-03.
//

import Testing
@testable import GIS_Simulator_2

struct HardwareDefTest {

    @Test func createHardwareDef() async throws {
		let phone = HardwareDefTest.sampleMobileHardwareDef
		#expect(phone.processor == "Apple Silicon M1")
		#expect(phone.cores == 8)
		#expect(phone.specIntRate2017 == 500)
    }
	
	public static var sampleMobileHardwareDef: HardwareDef {
		return HardwareDef(processor: "Apple Silicon M1", cores: 8, specIntRate2017: 500)
	}

	public static var sampleClientHardwareDef: HardwareDef {
		return HardwareDef(processor: "Intel Core i7-4770K", cores: 4, specIntRate2017: 20)
	}
	
	public static var sampleServerHardwareDef: HardwareDef {
        return HardwareDef(processor: "Intel Xeon E5-2643v3", cores: 12, specIntRate2017: 67)
	}
}
