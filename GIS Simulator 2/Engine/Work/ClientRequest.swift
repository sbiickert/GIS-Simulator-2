//
//  ClientRequest.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-20.
//

import Foundation

public class ClientRequest: Hashable, Described {
	public static func == (lhs: ClientRequest, rhs: ClientRequest) -> Bool {
		return lhs.name == rhs.name
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(name)
	}
	
	private static var _nextID: Int = 0
	public static func nextID() -> Int {
		_nextID += 1
		return _nextID
	}
	
	public static var nextName: String {
		return "CR-\(nextID())"
	}
	
	public var name: String
	public var desc: String
	public var workflowName: String
	public var requestClock: Int
	public var solution: ClientRequestSolution
	public var txID: Int
	public var accumulatingMetrics: [RequestMetric] = []

	public init(name: String, desc: String, workflowName: String, requestClock: Int, solution: ClientRequestSolution, txID: Int) {
		self.name = name
		self.desc = desc
		self.workflowName = workflowName
		self.requestClock = requestClock
		self.solution = solution
		self.txID = txID
	}
	
	public var isFinished:Bool {
		return solution.isFinished
	}
	
	public var summaryMetric: RequestMetric {
		var clock = 0
		var st = 0
		var qt = 0
		var nt = 0
		var lt = 0
		
		if accumulatingMetrics.isEmpty == false {
			clock = accumulatingMetrics.first!.clock
			for m in accumulatingMetrics {
				st += m.serviceTime
				qt += m.queueTime
				nt += m.networkTime
				lt += m.latencyTime
			}
		}
		
		return RequestMetric(sourceName: "Summary", clock: clock, requestName: name,workflowName: workflowName,
							 serviceTime: st, queueTime: qt, networkTime: nt, latencyTime: lt)
	}
}
