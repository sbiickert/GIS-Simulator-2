//
//  WaitingRequest.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-20.
//

import Foundation

public enum WaitMode: CaseIterable {
	case transmitting
	case processing
	case queueing
	case latency
}

public class WaitingRequest: Hashable {
	public static func == (lhs: WaitingRequest, rhs: WaitingRequest) -> Bool {
		return lhs.request == rhs.request && lhs.waitStart == rhs.waitStart
	}
	
	public func hash(into hasher: inout Hasher) {
		hasher.combine(request)
		hasher.combine(waitStart)
	}
	
	public var request: ClientRequest
	public var waitStart: Int
	public var serviceTime: Int
	public var latency: Int
	public var waitMode: WaitMode
	public var queueTime: Int
	
	
	public init(request: ClientRequest,
				waitStart: Int,
				serviceTime: Int,
				latency: Int,
				waitMode: WaitMode,
				queueTime: Int = 0) {
		self.request = request
		self.waitStart = waitStart
		self.serviceTime = serviceTime
		self.latency = latency
		self.waitMode = waitMode
		self.queueTime = queueTime
	}
	
	public func latencyEnded(at clock:Int) {
		self.waitMode = .queueing
		self.latency = clock - self.waitStart
	}
	
	public func queueEnded(at clock:Int, waitMode: WaitMode) {
		self.waitMode = waitMode
		self.queueTime = clock - self.waitStart - self.latency
	}
	
	public func waitEnd() -> Int? {
		if self.waitMode == .queueing {
			return nil
		}
		if self.waitMode == .latency {
			return self.waitStart + self.latency
		}
		return self.waitStart + self.serviceTime + self.latency + self.queueTime
	}
}
