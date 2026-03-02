//
//  Validatable.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation

public protocol Validatable {
	var isValid: Bool { get }
	func validate() -> [ValidationMessage]
}
