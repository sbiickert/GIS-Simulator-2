//
//  QueueTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-04.
//

import Testing
@testable import GIS_Simulator_2

@Suite(.serialized)
struct QueueTest {
	
	@Test func create() async throws {
		let connQ = QueueTest.sampleConnectionQueue
		#expect(connQ.serviceTimeCalculator is Connection)
	}
	
	@Test func networkEnqueue() async throws {
		// A single channel, all requests will queue up in order of arrival
		// The connection has non-zero latency, so requests end up in latencyHolding until time is up
		let connQ = QueueTest.sampleConnectionQueue
		await connQ.enqueue(QueueTest.sampleConnectionCR, at: 13)
		#expect(connQ.latencyHolding.count == 1)
		#expect(connQ.requestCount == 1)
		#expect(connQ.availableChannelCount == 1)
		// Wait for latency
		// 13 ms + 100 ms latency
		#expect(connQ.nextEventTime != nil)
		#expect(connQ.nextEventTime == 13 + 100)
		
		await connQ.enqueue(QueueTest.sampleConnectionCR, at: 15)
		await connQ.enqueue(QueueTest.sampleConnectionCR, at: 16)
		#expect(connQ.requestCount == 3)
		#expect(connQ.nextEventTime == 13 + 100)
		
		// Give enough time for the first request's latency to expire
		var finished = await connQ.removeFinishedRequests(clock: 13+100)
		#expect(finished.isEmpty)
		#expect(connQ.requestCount == 3)
		#expect(connQ.latencyHolding.count == 2)
		#expect(connQ.availableChannelCount == 0)
		
		// Give enough time for the second and third requests' latency to be processed
		finished = await connQ.removeFinishedRequests(clock: 15+100)
		#expect(finished.isEmpty)
		finished = await connQ.removeFinishedRequests(clock: 16+100)
		#expect(finished.isEmpty)
		#expect(connQ.requestCount == 3)
		#expect(connQ.latencyHolding.count == 0)
		#expect(connQ.availableChannelCount == 0)
		#expect(connQ.mainQueue.count == 2)
		
		// The next time should be when the first request has been processed
		// 13 ms + 100 ms latency + 160 ms ST
		#expect(connQ.nextEventTime == 13 + 100 + 160)
		finished = await connQ.removeFinishedRequests(clock: 13+100+160)
		#expect(finished.count == 1)
		#expect(finished[0].1.queueTime == 0)
		#expect(finished[0].1.serviceTime == 0)
		#expect(finished[0].1.networkTime == 160)
		#expect(finished[0].1.latencyTime == 100)
		#expect(connQ.requestCount == 2)
		#expect(connQ.latencyHolding.count == 0)
		#expect(connQ.availableChannelCount == 0)
		#expect(connQ.mainQueue.count == 1)
		
		// Give enough time for the second request to be processed
		let nextClock = await connQ.nextEventTime
		#expect(nextClock != nil)
		finished = await connQ.removeFinishedRequests(clock: nextClock!)
		#expect(finished.count == 1)
		#expect(connQ.requestCount == 1)
		#expect(connQ.availableChannelCount == 0)
		#expect(finished[0].1.queueTime == 160 - (15-13)) // arrived 2 ms after the first request
		#expect(finished[0].1.networkTime == 160)
		#expect(finished[0].1.latencyTime == 100)
	}
	
	@Test func computeEnqueue() async throws {
		let compQ = QueueTest.sampleComputeQueue
		await compQ.enqueue(QueueTest.sampleComputeCR, at: 13)
		#expect(compQ.requestCount == 1)
		#expect(compQ.availableChannelCount == 3) // 4 channels, one busy
		let st = 505 // 141 ms corrected for slow hardware
		#expect(compQ.nextEventTime == 13 + st)
		
		await compQ.enqueue(QueueTest.sampleComputeCR, at: 23)
		await compQ.enqueue(QueueTest.sampleComputeCR, at: 33)
		#expect(compQ.requestCount == 3)
		#expect(compQ.availableChannelCount == 1) // 4 channels, 3 busy
		
		await compQ.enqueue(QueueTest.sampleComputeCR, at: 43)
		await compQ.enqueue(QueueTest.sampleComputeCR, at: 53)
		#expect(compQ.requestCount == 5)
		#expect(compQ.availableChannelCount == 0) // 4 channels, 4 busy, 1 queued
		#expect(compQ.mainQueue.count == 1)
		
		var finished = await compQ.removeFinishedRequests(clock: 13 + st)
		#expect(finished.count == 1)
		#expect(compQ.requestCount == 4)
		#expect(compQ.availableChannelCount == 0) // 4 channels, 4 busy, 0 queued
		#expect(compQ.mainQueue.count == 0)
		#expect(finished[0].1.queueTime == 0)
		#expect(finished[0].1.serviceTime == st)
		#expect(finished[0].1.latencyTime == 0)
		
		finished = await compQ.removeFinishedRequests(clock: 23 + st)
		#expect(finished.count == 1)
		#expect(compQ.requestCount == 3)
		#expect(compQ.availableChannelCount == 1) // 4 channels, 3 busy, 0 queued
		#expect(finished[0].1.queueTime == 0)
		#expect(finished[0].1.serviceTime == st)

		finished = await compQ.removeFinishedRequests(clock: 43 + st)
		#expect(finished.count == 2)
		#expect(compQ.requestCount == 1)
		#expect(compQ.availableChannelCount == 3) // 4 channels, 1 busy, 0 queued
		
		// The last request had to queue until the first request finished
		#expect(compQ.nextEventTime == 13 + st + st)
		finished = await compQ.removeFinishedRequests(clock: 13 + st + st)
		#expect(finished.count == 1)
		#expect(compQ.requestCount == 0)
		#expect(compQ.availableChannelCount == 4) // 4 channels, 0 busy, 0 queued
		#expect(finished[0].1.queueTime == st - (53-13))
		#expect(finished[0].1.serviceTime == st)

		
	}
	
	public static var sampleConnectionQueue: MultiQueue {
		let conn = ConnectionTest.sampleConnectionToInternet
		return MultiQueue(serviceTimeCalculator: conn, waitMode: .transmitting, channels: 1)
	}
	
	public static var sampleComputeQueue: MultiQueue {
		let comp = ComputeNodeTest.sampleVM
		return MultiQueue(serviceTimeCalculator: comp, waitMode: .processing, channels: comp.vCores)
	}
	
	public static var sampleConnectionCR: ClientRequest {
		let step = ClientRequestSolutionStep(serviceTimeCalculator: sampleConnectionQueue.serviceTimeCalculator,
											 isResponse: true,
											 dataSize: 2000,
											 chatter: 10,
											 serviceTime: 0)
		let soln = ClientRequestSolution(steps: [step])
		return ClientRequest(name: ClientRequest.nextName, desc: "", workflowName: "",
							 requestClock: 10, solution: soln, txID: Transaction.nextId)
	}
	
	public static var sampleComputeCR: ClientRequest {
		let step = ClientRequestSolutionStep(serviceTimeCalculator: sampleComputeQueue.serviceTimeCalculator,
											 isResponse: true,
											 dataSize: 2000,
											 chatter: 0,
											 serviceTime: 141)
		let soln = ClientRequestSolution(steps: [step])
		return ClientRequest(name: ClientRequest.nextName, desc: "", workflowName: "",
							 requestClock: 10, solution: soln, txID: Transaction.nextId)
	}
}
