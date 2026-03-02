//
//  Transaction.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-23.
//

import Foundation

public class Transaction {
	static var _nextId: Int = 0
	public static var nextId: Int {
		defer { _nextId += 1 }
		return _nextId
	}
	
	public let id: Int
	public var requestClock: Int
	public var workflow: Workflow
	
	public init(requestClock: Int, workflow: Workflow) {
		self.id = Transaction.nextId
		self.requestClock = requestClock
		self.workflow = workflow
	}
}
