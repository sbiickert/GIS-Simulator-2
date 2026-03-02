//
//  Service.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation

public nonisolated struct ServiceDef: Described, Hashable, Codable {
	public var name: String
	public var desc: String
	public var serviceType: String
	public var balancingModel: BalancingModel
}
