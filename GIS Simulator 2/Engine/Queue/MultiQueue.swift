//
//  MultiQueue.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-20.
//

import Foundation

public class MultiQueue: Described {
	public var serviceTimeCalculator: ServiceTimeCalculator
	public var waitMode: WaitMode
	public var channels: [WaitingRequest?]
	public var mainQueue: [WaitingRequest] = []
	public var latencyHolding: Set<WaitingRequest> = []
	public var lastMetricClock: Int = 0
	public var workDone: Int = 0
	
	public init(serviceTimeCalculator: ServiceTimeCalculator, waitMode: WaitMode, channels: Int) {
		self.serviceTimeCalculator = serviceTimeCalculator
		self.waitMode = waitMode
		self.channels = Array(repeating: nil, count: channels)
	}
	
	public var name: String {
		get { return serviceTimeCalculator.name }
		set { }
	}
	
	public var desc: String {
		get { return serviceTimeCalculator.desc }
		set { }
	}
	
	public var type: String {
		if let node = serviceTimeCalculator as? ComputeNode {
			return node.type.rawValue
		}
		if let _ = serviceTimeCalculator as? Connection {
			return "connection"
		}
		return "unknown"
	}
	
	public var availableChannelCount: Int {
		channels.count(where: {$0 == nil})
	}
	
	public var firstAvailableChannel: Int? {
		for i in 0..<channels.count {
			if channels[i] == nil { return i }
		}
		return nil
	}
	
	public func channelsWithRequests() -> [Int] {
		var result = [Int]()
		for i in 0..<channels.count {
			if channels[i] != nil { result.append(i) }
		}
		return result
	}
	
	public func channelsWithFinishedRequests(clock: Int) -> [Int] {
		var result = [Int]()
		for i in channelsWithRequests() {
			if let wr = channels[i], let wEnd = wr.waitEnd() {
				if wEnd <= clock { result.append(i) }
			}
		}
		return result
	}
	
	public var requestCount: Int {
		return latencyHolding.count + mainQueue.count + channelsWithRequests().count
	}
	
	public var nextEventTime: Int? {
		var result : Int? = nil
		for i in channelsWithRequests() {
			if let wr = channels[i], let wEnd = wr.waitEnd() {
				if result == nil || wEnd < result! { result = wEnd }
			}
		}
		for wr in latencyHolding {
			if let wEnd = wr.waitEnd() {
				if result == nil || wEnd < result! { result = wEnd }
			}
		}
		return result
	}
	
	public func removeFinishedRequests(clock: Int) -> Array<(ClientRequest, RequestMetric)> {
		var latencyEnded = [WaitingRequest]()
		
		// Out of latency jail
		for wr in latencyHolding {
			if let wEnd = wr.waitEnd(), wEnd <= clock {
				latencyEnded.append(wr)
			}
		}
		for wr in latencyEnded {
			latencyHolding.remove(wr)
			wr.latencyEnded(at: clock)
			mainQueue.append(wr)
		}
		
		let finishedChannels = channelsWithFinishedRequests(clock: clock)
		var result = [(ClientRequest, RequestMetric)]()
		
		for i in finishedChannels {
			if let wr = channels[i] {
				var st = wr.serviceTime
				var nt = 0
                if serviceTimeCalculator is Connection {
					nt = st
					st = 0
				}
				let metric = RequestMetric(sourceName: name,
										   clock: clock,
										   requestName: wr.request.name,
										   workflowName: wr.request.workflowName,
										   serviceTime: st,
										   queueTime: wr.queueTime,
										   networkTime: nt,
										   latencyTime: wr.latency)
				result.append( (wr.request, metric) )
				wr.request.accumulatingMetrics.append(metric)
				self.logWorkDone(for: wr, at: clock)
				channels[i] = nil
			}
		}
        
        // Move queued requests into channels
        while let firstAvail = firstAvailableChannel, mainQueue.count > 0 {
            let queuedReq = mainQueue.remove(at: 0)
            queuedReq.queueEnded(at: clock, waitMode: self.waitMode)
            channels[firstAvail] = queuedReq
        }
		
		return result
	}
	
	public func enqueue(_ request: ClientRequest, at clock: Int) {
		if let _ = request.solution.currentStep {
			let st = serviceTimeCalculator.calculateServiceTime(for: request)
			let lt = serviceTimeCalculator.calculateLatency(for: request)
			
			if lt > 0 {
				latencyHolding.insert(WaitingRequest(request: request, waitStart: clock, serviceTime: st, latency: lt, waitMode: .latency))
			}
			else {
				if let index = firstAvailableChannel {
					channels[index] = WaitingRequest(request: request, waitStart: clock, serviceTime: st, latency: lt, waitMode: self.waitMode)
				}
				else {
					mainQueue.append(WaitingRequest(request: request, waitStart: clock, serviceTime: st, latency: lt, waitMode: .queueing))
				}
			}
		}
	}
	
	public var allProcessingRequests: [WaitingRequest] {
		return channels.compactMap {$0}
	}
	
	public var allRequests: [WaitingRequest] {
		return allProcessingRequests + mainQueue + latencyHolding
	}
	
	public func getPerformanceMetric(clock: Int) -> QueueMetric {
		let wrList = allProcessingRequests
		for wr in wrList {
			logWorkDone(for: wr, at: clock)
		}
		
		let qm = QueueMetric(sourceName: name, clock: clock,
							 serviceTimeCalculatorType: type,
							 channelCount: channels.count,
							 requestCount: requestCount,
							 utilization: calcUtilization(at: clock),
							 work: workDone)
		
		workDone = 0
		lastMetricClock = clock
		return qm
	}
	
	private func logWorkDone(for request: WaitingRequest, at clock: Int) {
		if let waitEnd = request.waitEnd(), request.serviceTime > 0 {
			// Total work for request is the service time, but if the work started before the last
			// time it was logged, ignore that part. Also, if the work isn't done yet, then ignore that too.
			var totalWork = request.serviceTime
			let workStartedAt = waitEnd - request.serviceTime
			if workStartedAt < lastMetricClock {
				totalWork -= self.lastMetricClock - workStartedAt
			}
			if clock < waitEnd {
				totalWork -= waitEnd - clock
			}
			if totalWork < 0 {
				fatalError("Neg value \(totalWork) logging work in \(name). \(lastMetricClock),\(clock),\(request.waitStart),\(request.serviceTime),\(waitEnd)")
			}
			self.workDone += totalWork
		}
	}
	
	private func calcUtilization(at clock: Int) -> Double {
		// 1.0 is 100% utilization
		let timeWindow = clock - lastMetricClock
		let maxWork = timeWindow * channels.count
		return Double(workDone) / Double(maxWork)
	}
}
