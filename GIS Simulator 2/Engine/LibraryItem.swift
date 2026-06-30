//
//  LibraryItem.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-06-30.
//

import Foundation

/// A predefined or custom building block that can be favorited and copied within
/// a `Design`. Each type already has a natural unique key; `libraryKey` exposes
/// it uniformly so favorite/merge logic can treat all types the same way.
public protocol LibraryItem {
	var libraryKey: String { get }
}

extension HardwareDef: LibraryItem {
	public var libraryKey: String { processor }
}

extension ServiceDef: LibraryItem {
	public var libraryKey: String { serviceType }
}

extension WorkflowDefStep: LibraryItem {
	public var libraryKey: String { name }
}

extension WorkflowChain: LibraryItem {
	public var libraryKey: String { name }
}

extension WorkflowDef: LibraryItem {
	public var libraryKey: String { name }
}
