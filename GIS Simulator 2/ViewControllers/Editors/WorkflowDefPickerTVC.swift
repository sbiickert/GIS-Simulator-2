//
//  WorkflowDefPickerTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class WorkflowDefPickerTVC: UITableViewController {
	var design: Design!

	private let library = Library()
	private var availableDefs: [(String, WorkflowDef)] = []

	convenience init(design: Design) {
		self.init(style: .grouped)
		self.design = design
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Add Workflow Definition"
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "WFDefCell")
		tableView.allowsMultipleSelection = true

		let existingNames = Set(design.workflowDefinitions.map(\.name))
		availableDefs = library.workflowDefinitions
			.sorted(by: { $0.key < $1.key })
			.filter { !existingNames.contains($0.key) }
	}

	override func numberOfSections(in tableView: UITableView) -> Int { 1 }
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { availableDefs.count }

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		availableDefs.isEmpty ? "All workflow definitions have been added" : "Select workflow definitions to add"
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "WFDefCell", for: indexPath)
		let (_, wfDef) = availableDefs[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = wfDef.name
		let chainNames = wfDef.chains.map(\.name).joined(separator: ", ")
		content.secondaryText = "\(wfDef.chains.count) chains: \(chainNames) — think time: \(wfDef.thinkTimeSeconds)s"
		cell.contentConfiguration = content
		return cell
	}

	@objc func doneTapped() {
		if let selectedRows = tableView.indexPathsForSelectedRows {
			for indexPath in selectedRows {
				let (_, wfDef) = availableDefs[indexPath.row]
				design.addWorkflowDefinition(wfDef)
			}
		}
		navigationController?.popViewController(animated: true)
	}
}
