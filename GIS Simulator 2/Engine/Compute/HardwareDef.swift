//
//  HardwareDef.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation
import SwiftData

public nonisolated enum ThreadingModel: String, CaseIterable, Codable {
	case physical = "Physical"
	case hyperThreaded = "HyperThreaded"
	
	public var factor: Double {
		switch self {
		case .physical:
			return 1.0
		case .hyperThreaded:
			return 0.5
		}
	}
}

public nonisolated struct HardwareDef: Equatable, Hashable, Codable {
	private static var _baselinePerCore: Double = 10.0
	public static var BaselinePerCore: Double {
		get {
			_baselinePerCore
		}
		set {
			_baselinePerCore = newValue
		}
	}
	
	public var processor: String
	public var cores: Int
	public var specIntRate2017: Double
	
	var specIntRate2017PerCore: Double {
		specIntRate2017 / Double(cores)
	}
}
