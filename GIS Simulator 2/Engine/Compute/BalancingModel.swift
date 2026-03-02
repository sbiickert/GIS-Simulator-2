//
//  BalancingModel.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation

public enum BalancingModel: String, CaseIterable, Codable {
	case single = "1"
	case roundRobin = "ROUNDROBIN"
	case failover = "FAILOVER"
	case containerized = "CONTAINERIZED"
	case other = "OTHER"
}
