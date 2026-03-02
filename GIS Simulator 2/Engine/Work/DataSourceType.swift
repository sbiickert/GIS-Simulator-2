//
//  DataSourceType.swift
//  GISSimulator
//
//  Created by Simon Biickert on 2025-04-16.
//

import Foundation

public enum DataSourceType: String, CaseIterable, Codable {
	case relational = "RELATIONAL"
	case object = "OBJECT"
	case file = "FILE"
	case dbms = "DBMS"
	case big = "BIG"
	case other = "OTHER"
	case none = "NONE"
}
