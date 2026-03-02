//
//  ClientRequestSolutionTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-21.
//

import Testing

@testable import GIS_Simulator_2

struct ClientRequestSolutionTest {

    @Test func create() async throws {
		let crs = ClientRequestSolutionTest.sampleIntranetCRS
		for step in crs.steps {
			await print(step.serviceTimeCalculator.name)
		}
		#expect(crs.steps.count == 17)
    }

	public static var sampleIntranetCRS: ClientRequestSolution {
		let chain = WorkflowDefTest.sampleDynMapChain(client: WorkflowDefStepTest.sampleBrowserWDS)
		for sp in ServiceProviderTest.sampleWebGisSPSet {
			chain.serviceProviders[sp.service.serviceType] = sp
		}
		return Workflow.createSolution(chain: chain, network: RouteTest.sampleIntranet)
	}
}
