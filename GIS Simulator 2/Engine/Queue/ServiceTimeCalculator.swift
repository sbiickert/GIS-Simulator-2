//
//  ServiceTimeCalculator.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation

public protocol ServiceTimeCalculator: Described {
	func calculateServiceTime(for request: ClientRequest) -> Int
	func calculateLatency(for request: ClientRequest) -> Int
	func provideQueue() -> MultiQueue
}
