//
//  Simulator.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-03-02.
//

import Foundation

public enum SimulatorError: Error {
	case invalidDesign
	case zeroOrNegativeClockIncrement
	case timeTravelNotSupported
}

public enum MeteringMode {
	case summary
	case detailed
}

public class Simulator: Described {
	public var name: String
	public var desc: String
	public var design: Design
	
	var requestMeteringMode: MeteringMode = .summary
	var clock: Int = 0
	var isGeneratingNewRequests: Bool = false
	var finishedRequests: [ClientRequest] = []
	var queues: [MultiQueue] = []
	var nextEventTimeForWorkflows: Dictionary<String, Int> = [:]
	var queueMetrics: [QueueMetric] = []
	var requestMetrics: [RequestMetric] = []
	
	public init(name: String, desc: String, design: Design? = nil) {
		self.name = name
		self.desc = desc
		self.design = design ?? Design(name: Design.nextName, desc: "")
	}
	
	public func start() throws {
		/*
		 Puts the Simulator into a mode where time can be moved forward and requests will be generated.

		 Normal process for running the Simulator:

		 1. start
		 2. advanceTimeBy or advanceTimeTo
		 3. stop

		 The simulator time does not advance by itself, code to run the simulator might look like:

			 try sim.start()
			 for i in 1..<500
				 sim.advanceTimeBy(500)
				 sim.gatherQueueMetrics()
			 sim.stop()
		 */
		guard design.isValid else {
			design.printValidationMessages()
			throw SimulatorError.invalidDesign
		}
		reset()
		isGeneratingNewRequests = true
		for w in design.workflows {
			nextEventTimeForWorkflows[w.name] = w.calculateNextEventTime(clock: clock)
		}
	}
	
	public func stop() {
		isGeneratingNewRequests = false
	}
	
	public func reset() {
		clock = 0
		finishedRequests.removeAll()
		nextEventTimeForWorkflows.removeAll()
		queueMetrics.removeAll()
		requestMetrics.removeAll()
		queues = design.provideQueues()
	}
	
	public var nextEventTime: Int? {
		/*
		 If the simulator is started or there are existing requests in the system, then
		 there will be a clock value in the future when the next event happens, such as a new
		 Transaction starting or a request being finished processing or passing through a Connection.
		 
		 :returns: The clock time when the next thing happens. Returns nil if there are no forecast events.*/
		var times: [Int] = []
		if let nextW = self.nextWorkflow() {
			times.append(nextW.1)
		}
		if let nextQ = self.nextQueue() {
			times.append(nextQ.1)
		}
		return times.isEmpty ? nil : times.min()
	}
	
	func nextWorkflow() -> (Workflow, Int)? {
		var result: (Workflow, Int)? = nil
		
		if isGeneratingNewRequests {
			for (name, time) in nextEventTimeForWorkflows {
				if let w = design.findWorkflow(named: name) {
					if result == nil || time < result!.1 {
						result = (w, time)
					}
				}
			}
		}
		
		return result
	}
	
	func nextQueue() -> (MultiQueue, Int)? {
		var result: (MultiQueue, Int)? = nil
		
		for queue in queues {
			if let time = queue.nextEventTime {
				if result == nil || time < result!.1 {
					result = (queue, time)
				}
			}
		}
		
		return result
	}
	
	public func advanceTime(by amount: Int) throws {
		guard amount > 0 else { throw SimulatorError.zeroOrNegativeClockIncrement }
		try advanceTime(to: clock + amount)
	}
	
	public func advanceTime(to newClock: Int) throws {
		guard newClock > clock else { throw SimulatorError.timeTravelNotSupported }
		
		while let time = nextEventTime, time <= newClock {
			doTheNextTask()
		}
		
		clock = newClock
	}
	
	func doTheNextTask() {
		let nextW = nextWorkflow()
		let nextQ = nextQueue()
		
		var requests: [ClientRequest] = []
		var nextTime = 0
		
		if let nextW, (nextQ == nil || nextW.1 <= nextQ!.1) {
			nextTime = nextW.1
			let transaction = nextW.0.createClientRequests(network: design.network, clock: nextTime)
			requests = transaction.1
			nextEventTimeForWorkflows[nextW.0.name] = nextW.0.calculateNextEventTime(clock: nextTime)
		}
		else if let nextQ, (nextW == nil || nextQ.1 < nextW!.1) {
			nextTime = nextQ.1
			let reqsAndMetrics = nextQ.0.removeFinishedRequests(clock: nextTime)
			for rm in reqsAndMetrics {
				rm.0.solution.gotoNextStep()
				requests.append(rm.0)
			}
		}
		
		for request in requests {
			if request.isFinished {
				finishedRequests.append(request)
				if requestMeteringMode == .detailed {
					requestMetrics.append(contentsOf: request.accumulatingMetrics)
				}
				else {
					requestMetrics.append(request.summaryMetric)
				}
			}
			else {
				if let step = request.solution.currentStep {
					let stc = step.serviceTimeCalculator
					if let queue = findQueue(stc) {
						queue.enqueue(request, at: nextTime)
					}
				}
			}
		}
	}
	
	func findQueue(_ stc: ServiceTimeCalculator) -> MultiQueue? {
		for q in queues {
			if q.serviceTimeCalculator.name == stc.name {
				return q
			}
		}
		return nil
	}
	
	public var activeRequests: [WaitingRequest] {
		var result: [WaitingRequest] = []
		for q in queues {
			result.append(contentsOf: q.allProcessingRequests)
		}
		return result
	}
	
	func gatherQueueMetrics() {
		let sortedQueues = queues.sorted {
			let t0 = $0.type
			let t1 = $1.type
			if t0 == "host" || t1 == "host" { return true } // physical hosts should alway be ordered second
			return false
		}
		for queue in sortedQueues {
			let qm = queue.getPerformanceMetric(clock: self.clock)
			queueMetrics.append(qm)
			
			// Apply work to the physical host
			if queue.type == "vm" {
				let vm = queue.serviceTimeCalculator as! ComputeNode
				for cn in design.physicalComputeNodes {
					if cn.isHostFor(vm: vm) {
						if let hostQ = findQueue(cn) {
							hostQ.workDone = hostQ.workDone + qm.work
						}
					}
				}
			}
		}
	}
}
