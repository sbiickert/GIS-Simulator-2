//
//  WorkflowEditorTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class WorkflowEditorTVC: UITableViewController {
	var design: Design!
	var editingWorkflow: Workflow?

	private var wfName = ""
	private var wfDesc = ""
	private var wfType: WorkflowType = .user
	private var defIndex = 0
	private var userCount = 10
	private var productivity = 100
	private var tph = 100

	convenience init(design: Design, editing workflow: Workflow? = nil) {
		self.init(style: .grouped)
		self.design = design
		self.editingWorkflow = workflow

		if let workflow {
			wfName = workflow.name
			wfDesc = workflow.desc
			wfType = workflow.type
			defIndex = design.workflowDefinitions.firstIndex(where: { $0 == workflow.definition }) ?? 0
			userCount = workflow.userCount
			productivity = workflow.productivity
			tph = workflow.tph
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = editingWorkflow != nil ? "Edit Workflow" : "New Workflow"
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
		tableView.register(TextFieldCell.self, forCellReuseIdentifier: TextFieldCell.reuseIdentifier)
		tableView.register(PickerCell.self, forCellReuseIdentifier: PickerCell.reuseIdentifier)
	}

	// MARK: - Table View
	// Row layout:
	// 0: Name
	// 1: Description
	// 2: Type picker (user/transactional) — hidden when editing
	// 3: Workflow Def picker
	// 4+: conditional fields based on type

	private var rowCount: Int {
		let baseRows = editingWorkflow != nil ? 3 : 4 // name, desc, [type], def
		let typeRows = wfType == .user ? 2 : 1 // userCount+productivity or tph
		return baseRows + typeRows
	}

	override func numberOfSections(in tableView: UITableView) -> Int { 1 }
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { rowCount }

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let isEditing = editingWorkflow != nil
		let typeRowOffset = isEditing ? 1 : 0 // skip type row when editing
		let effectiveRow = isEditing && indexPath.row >= 2 ? indexPath.row + typeRowOffset : indexPath.row

		switch effectiveRow {
		case 0:
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Name", value: wfName, placeholder: "Workflow name")
			cell.onTextChanged = { [weak self] t in self?.wfName = t }
			return cell
		case 1:
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Description", value: wfDesc, placeholder: "Description")
			cell.onTextChanged = { [weak self] t in self?.wfDesc = t }
			return cell
		case 2: // Type picker
			let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseIdentifier, for: indexPath) as! PickerCell
			let types = ["User", "Transactional"]
			let selectedIdx = wfType == .user ? 0 : 1
			cell.configure(label: "Type", value: types[selectedIdx], options: types, selectedIndex: selectedIdx)
			cell.onSelected = { [weak self] i in
				self?.wfType = i == 0 ? .user : .transactional
				self?.tableView.reloadData()
			}
			return cell
		case 3: // Workflow Def picker
			let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseIdentifier, for: indexPath) as! PickerCell
			let names = design.workflowDefinitions.map(\.name)
			cell.configure(label: "Definition", value: names.isEmpty ? "—" : names[defIndex], options: names, selectedIndex: defIndex)
			cell.onSelected = { [weak self] i in
				self?.defIndex = i
				tableView.reloadRows(at: [indexPath], with: .none)
			}
			return cell
		case 4:
			if wfType == .user {
				let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
				cell.configure(label: "User Count", value: "\(userCount)", placeholder: "10", keyboardType: .numberPad)
				cell.onTextChanged = { [weak self] t in self?.userCount = Int(t) ?? 10 }
				return cell
			} else {
				let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
				cell.configure(label: "Transactions/Hour", value: "\(tph)", placeholder: "100", keyboardType: .numberPad)
				cell.onTextChanged = { [weak self] t in self?.tph = Int(t) ?? 100 }
				return cell
			}
		case 5: // Only for user type
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Productivity", value: "\(productivity)", placeholder: "100", keyboardType: .numberPad)
			cell.onTextChanged = { [weak self] t in self?.productivity = Int(t) ?? 100 }
			return cell
		default:
			return UITableViewCell()
		}
	}

	// MARK: - Actions

	@objc func saveTapped() {
		guard !wfName.isEmpty else {
			showAlert("Workflow name is required.")
			return
		}
		guard !design.workflowDefinitions.isEmpty else {
			showAlert("Add workflow definitions before creating workflows.")
			return
		}

		let defName = design.workflowDefinitions[defIndex].name

		if let wf = editingWorkflow {
			wf.name = wfName
			wf.desc = wfDesc
			wf.userCount = userCount
			wf.productivity = productivity
			wf.tph = tph
		} else {
			switch wfType {
			case .user:
				_ = design.addUserWorkflow(name: wfName, description: wfDesc, wdefName: defName, users: userCount, productivity: productivity)
			case .transactional:
				_ = design.addTransactionalWorkflow(name: wfName, description: wfDesc, wdefName: defName, tph: tph)
			}
		}

		navigationController?.popViewController(animated: true)
	}

	private func showAlert(_ message: String) {
		let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}
