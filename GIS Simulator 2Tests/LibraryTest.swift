//
//  LibraryTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-31.
//

import Testing
@testable import GIS_Simulator_2

struct LibraryTest {

    @Test func load() async throws {
		let lib = await Library()
		#expect(lib.hardwareDefinitions.count > 0)
		#expect(lib.serviceDefinitions.count > 0)
		#expect(lib.workflowSteps.count > 0)
		#expect(lib.workflowChains.count > 0)
		#expect(lib.workflowDefinitions.count > 0)
	}

}
