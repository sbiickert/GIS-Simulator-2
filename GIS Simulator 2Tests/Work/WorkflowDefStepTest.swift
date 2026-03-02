//
//  WorkTest.swift
//  GIS Simulator 2Tests
//
//  Created by Simon Biickert on 2026-03-21.
//

import Testing

@testable import GIS_Simulator_2

struct WorkflowDefStepTest {

    @Test func create() async throws {
		var wds = WorkflowDefStepTest.sampleBrowserWDS
		#expect(wds.responseSizeKB == 2134)
		wds = WorkflowDefStepTest.sampleCacheMapWDS
		wds = WorkflowDefStepTest.sampleDBMSWDS
		wds = WorkflowDefStepTest.sampleDynMapWDS
		wds = WorkflowDefStepTest.sampleFileWDS
		wds = WorkflowDefStepTest.sampleHostWDS
		wds = WorkflowDefStepTest.sampleMobileWDS
		wds = WorkflowDefStepTest.samplePortalWDS
		wds = WorkflowDefStepTest.sampleProWDS
		wds = WorkflowDefStepTest.sampleRelDSWDS
		wds = WorkflowDefStepTest.sampleVDIWDS
		wds = WorkflowDefStepTest.sampleWebWDS
    }
	
	public static var sampleProWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "Pro Client Step", desc: "Sample Pro Step", serviceType: "pro",
							   serviceTime: 831, chatter: 500, requestSizeKB: 1000, responseSizeKB: 13340,
							   dataSourceType: .dbms, cachePercent: 0)
	}

	public static var sampleBrowserWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "Browser Client Step", desc: "Sample Browser Step", serviceType: "browser",
							   serviceTime: 20, chatter: 10, requestSizeKB: 100, responseSizeKB: 2134,
							   dataSourceType: .none, cachePercent: 20)
	}
	
	public static var sampleMobileWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "Mobile Client Step", desc: "Sample Mobile Step", serviceType: "mobile",
							   serviceTime: 20, chatter: 10, requestSizeKB: 100, responseSizeKB: 2134,
							   dataSourceType: .none, cachePercent: 20)
	}
	
	public static var sampleVDIWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "VDI Client Step", desc: "Sample VDI Step", serviceType: "vdi",
							   serviceTime: 831, chatter: 10, requestSizeKB: 100, responseSizeKB: 3691,
							   dataSourceType: .dbms, cachePercent: 0)
	}
	
	public static var sampleWebWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "Web Service Step", desc: "Sample Web Step", serviceType: "web",
							   serviceTime: 18, chatter: 10, requestSizeKB: 100, responseSizeKB: 2134,
							   dataSourceType: .none, cachePercent: 0)
	}
	
	public static var samplePortalWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "Portal Service Step", desc: "Sample Portal Step", serviceType: "portal",
							   serviceTime: 19, chatter: 10, requestSizeKB: 100, responseSizeKB: 2134,
							   dataSourceType: .file, cachePercent: 0)
	}
	
	public static var sampleDynMapWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "Dynamic Map Service Step", desc: "Sample Dynamic Map Step", serviceType: "map",
							   serviceTime: 141, chatter: 10, requestSizeKB: 100, responseSizeKB: 2134,
							   dataSourceType: .dbms, cachePercent: 0)
	}
	
	public static var sampleCacheMapWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "Cached Map Service Step", desc: "Sample Cached Map Step", serviceType: "map",
							   serviceTime: 1, chatter: 10, requestSizeKB: 100, responseSizeKB: 2134,
							   dataSourceType: .file, cachePercent: 100)
	}
	
	public static var sampleHostWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "Hosted Service Step", desc: "Sample Hosted Step", serviceType: "feature",
							   serviceTime: 70, chatter: 10, requestSizeKB: 100, responseSizeKB: 4000,
							   dataSourceType: .relational, cachePercent: 0)
	}
	
	public static var sampleDBMSWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "DBMS Service Step", desc: "Sample DBMS Step", serviceType: "dbms",
							   serviceTime: 24, chatter: 500, requestSizeKB: 500, responseSizeKB: 13340,
							   dataSourceType: .file, cachePercent: 75)
	}
	
	public static var sampleFileWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "File Service Step", desc: "Sample File Step", serviceType: "file",
							   serviceTime: 24, chatter: 500, requestSizeKB: 1000, responseSizeKB: 13340,
							   dataSourceType: .file, cachePercent: 0)
	}
	
	public static var sampleRelDSWDS: WorkflowDefStep {
		return WorkflowDefStep(name: "Relational DS Service Step", desc: "Sample Relational Step", serviceType: "relational",
							   serviceTime: 24, chatter: 10, requestSizeKB: 1000, responseSizeKB: 13340,
							   dataSourceType: .file, cachePercent: 0)
	}
}
