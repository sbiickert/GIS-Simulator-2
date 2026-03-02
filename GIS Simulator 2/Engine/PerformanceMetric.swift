//
//  PerformanceMetric.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation

public protocol PerformanceMetric {
	var sourceName: String {get}
	var clock: Int {get}
}

public struct QueueMetric: PerformanceMetric {
	public let sourceName: String
	public let clock: Int
	
	public let serviceTimeCalculatorType: String
	public let channelCount: Int
	public let requestCount: Int
	public let utilization: Double
	public let work: Int
}

public struct RequestMetric: PerformanceMetric {
	public var sourceName: String
	public var clock: Int
	
	public let requestName: String
	public let workflowName: String
	public let serviceTime: Int
	public let queueTime: Int
	public let networkTime: Int
	public let latencyTime: Int
}
