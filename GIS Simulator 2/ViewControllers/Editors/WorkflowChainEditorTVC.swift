//
//  WorkflowChainEditorTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class WorkflowChainEditorTVC: UITableViewController {
	var design: Design!
	var workflowDef: WorkflowDef!

	convenience init(design: Design, workflowDef: WorkflowDef) {
		self.init(style: .grouped)
		self.design = design
		self.workflowDef = workflowDef
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = workflowDef.name
		tableView.register(PickerCell.self, forCellReuseIdentifier: PickerCell.reuseIdentifier)
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "StepCell")
	}

	// MARK: - Table View
	// One section per chain. Each section shows steps and has a service provider picker per required service type.

	override func numberOfSections(in tableView: UITableView) -> Int {
		workflowDef.chains.count
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		let chain = workflowDef.chains[section]
		return "Chain: \(chain.name)"
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		let chain = workflowDef.chains[section]
		// One row per unique required service type
		return chain.allRequiredServiceTypes.count
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let chain = workflowDef.chains[indexPath.section]
		let serviceType = chain.allRequiredServiceTypes.sorted()[indexPath.row]

		let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseIdentifier, for: indexPath) as! PickerCell

		// Find matching service providers from the design
		let matchingProviders = design.serviceProviders.filter { $0.service.serviceType == serviceType }
		let providerNames = ["(none)"] + matchingProviders.map(\.name)

		// Find current selection
		let currentSP = chain.serviceProviders[serviceType]
		let selectedIndex: Int
		if let currentSP, let idx = matchingProviders.firstIndex(where: { $0 == currentSP }) {
			selectedIndex = idx + 1
		} else {
			selectedIndex = 0
		}

		cell.configure(
			label: serviceType,
			value: currentSP?.name ?? "(none)",
			options: providerNames,
			selectedIndex: selectedIndex
		)
		cell.onSelected = { i in
			if i == 0 {
				chain.serviceProviders.removeValue(forKey: serviceType)
			} else {
				chain.serviceProviders[serviceType] = matchingProviders[i - 1]
			}
			tableView.reloadRows(at: [indexPath], with: .none)
		}

		return cell
	}
}
