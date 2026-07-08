//
//  ValidationMessage.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation

/// The area of a Design a validation message belongs to. Used by the UI to
/// attribute messages to the matching section of the design detail view.
public enum ValidationCategory: String, CaseIterable {
	case general
	case zones
	case network
	case compute
	case services
	case serviceProviders
	case workflows
}

public struct ValidationMessage {
	public let message: String
	public let source: String
	public let category: ValidationCategory
	/// The name of the specific item (zone, service provider, workflow, …)
	/// the message applies to, when it applies to one item rather than a
	/// whole category. Used by the UI to badge individual rows.
	public let itemName: String?

	public init(message: String, source: String,
				category: ValidationCategory = .general, itemName: String? = nil) {
		self.message = message
		self.source = source
		self.category = category
		self.itemName = itemName
	}
}
