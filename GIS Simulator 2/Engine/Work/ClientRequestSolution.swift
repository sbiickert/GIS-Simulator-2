//
//  ClientRequestSolution.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-21.
//

import Foundation

public class ClientRequestSolution {
	public var steps: [ClientRequestSolutionStep] = []
	
	public init(steps: [ClientRequestSolutionStep]) {
		self.steps = steps
	}
	
	public var isFinished: Bool {
		return steps.isEmpty
	}
	
	public var currentStep: ClientRequestSolutionStep? {
		return steps.first
	}
	
	public func gotoNextStep() {
		if steps.isEmpty { return }
		steps.removeFirst()
	}
}
