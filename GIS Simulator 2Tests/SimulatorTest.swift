//
//  GIS_Simulator_2Tests.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-02-20.
//

import Testing
@testable import GIS_Simulator_2

struct SimulatorTest {

    @Test func create() async throws {
		let sim = SimulatorTest.sampleSimulator
		#expect(sim.name == "Test Simulator")
		#expect(sim.isGeneratingNewRequests == false)
	}
	
	@Test func advancingTime() async throws {
		let sim = SimulatorTest.sampleSimulator
		sim.design = DesignTest.sampleDesign
		#expect(sim.design.isValid)
		#expect(sim.nextEventTime == nil)
		
		try await sim.start()
		#expect(sim.isGeneratingNewRequests == true)
		var nextTime = await sim.nextEventTime
		#expect(nextTime != nil)
		print("Clock is \(await sim.clock), next event scheduled for: \(nextTime!)")
		try await sim.advanceTime(to: nextTime!)
		var nonEmptyQueues = await sim.queues.filter {$0.requestCount > 0}
		#expect(nonEmptyQueues.count > 0)
		
		await sim.stop()
		nextTime = await sim.nextEventTime
		#expect(nextTime != nil)
		let c = await sim.clock
		#expect(nextTime! > c)
		
		while (nextTime != nil) {
			try await sim.advanceTime(to: nextTime!)
			nextTime = await sim.nextEventTime
		}
		
		#expect(sim.finishedRequests.isEmpty == false)
		nonEmptyQueues = await sim.queues.filter {$0.requestCount > 0}
		#expect(nonEmptyQueues.isEmpty)
	}
	
	@Test func queueMetrics() async throws {
		let sim = SimulatorTest.sampleSimulator
		sim.design = DesignTest.sampleDesign
		
		try await sim.start()
		for _ in 1...10 {
			try await sim.advanceTime(by: 500)
			await sim.gatherQueueMetrics()
		}
		
		await sim.stop()
		
		let nonEmptyQueues = await sim.queues.filter {$0.requestCount > 0}
		#expect(nonEmptyQueues.count > 0)
		#expect(10 * sim.queues.count == sim.queueMetrics.count)
	}

	public static var sampleSimulator: Simulator {
		return Simulator(name: "Test Simulator", desc: "Sim for unit testing")
	}
}
