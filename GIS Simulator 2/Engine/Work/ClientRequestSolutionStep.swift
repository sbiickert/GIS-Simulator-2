//
//  ClientRequestSolutionStep.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation

public class ClientRequestSolutionStep {
	var serviceTimeCalculator: ServiceTimeCalculator
	var isResponse: Bool
	var dataSize: Int
	var chatter: Int
	var serviceTime: Int
	
	public init(
		serviceTimeCalculator: ServiceTimeCalculator,
		isResponse: Bool,
		dataSize: Int,
		chatter: Int,
		serviceTime: Int
	) {
		self.serviceTimeCalculator = serviceTimeCalculator
		self.isResponse = isResponse
		self.dataSize = dataSize
		self.chatter = chatter
		self.serviceTime = serviceTime
	}
}
