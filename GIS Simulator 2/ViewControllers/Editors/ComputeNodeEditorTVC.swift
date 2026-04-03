//
//  ComputeNodeEditorTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class ComputeNodeEditorTVC: UITableViewController {
	var design: Design!
	var editingNode: ComputeNode?
	var onSave: (() -> Void)?

	private let library = Library()
	private var nodeName = ""
	private var nodeDesc = ""
	private var nodeType: ComputeNodeType = .host
	private var hwIndex = 0
	private var memoryGB = 64
	private var zoneIndex = 0

	private var sortedHardware: [(String, HardwareDef)] = []

	private enum Section: Int, CaseIterable {
		case properties
		case vms
	}

	convenience init(design: Design, editing node: ComputeNode? = nil, onSave: (() -> Void)? = nil) {
		self.init(style: .grouped)
		self.design = design
		self.editingNode = node
		self.onSave = onSave

		sortedHardware = library.hardwareDefinitions.sorted(by: { $0.key < $1.key })

		if let node {
			nodeName = node.name
			nodeDesc = node.desc
			nodeType = node.type
			memoryGB = node.memoryGB
			zoneIndex = design.zones.firstIndex(of: node.zone) ?? 0
			hwIndex = sortedHardware.firstIndex(where: { $0.1.processor == node.hwDef.processor }) ?? 0
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = editingNode != nil ? "Edit Compute Node" : "New Compute Node"
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
		tableView.register(TextFieldCell.self, forCellReuseIdentifier: TextFieldCell.reuseIdentifier)
		tableView.register(PickerCell.self, forCellReuseIdentifier: PickerCell.reuseIdentifier)
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "VMCell")
	}

	// MARK: - Table View

	override func numberOfSections(in tableView: UITableView) -> Int {
		return editingNode?.type == .host ? Section.allCases.count : 1
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == Section.properties.rawValue {
			return editingNode != nil ? 5 : 6 // hide type picker when editing
		} else {
			return (editingNode?.vmCount ?? 0)
		}
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		if section == Section.vms.rawValue { return "Virtual Machines" }
		return nil
	}

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		guard section == Section.vms.rawValue else { return nil }

		let header = UITableViewHeaderFooterView()
		var content = UIListContentConfiguration.groupedHeader()
		content.text = "Virtual Machines"
		header.contentConfiguration = content

		let addButton = UIButton(type: .contactAdd)
		addButton.addTarget(self, action: #selector(addVM), for: .touchUpInside)
		addButton.translatesAutoresizingMaskIntoConstraints = false
		header.contentView.addSubview(addButton)
		NSLayoutConstraint.activate([
			addButton.trailingAnchor.constraint(equalTo: header.contentView.trailingAnchor, constant: -16),
			addButton.centerYAnchor.constraint(equalTo: header.contentView.centerYAnchor)
		])
		return header
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.section == Section.vms.rawValue {
			let cell = tableView.dequeueReusableCell(withIdentifier: "VMCell", for: indexPath)
			if let vm = editingNode?.vm(at: indexPath.row) {
				var content = UIListContentConfiguration.subtitleCell()
				content.text = vm.name
				content.secondaryText = "\(vm.vCores) vCores, \(vm.memoryGB) GB"
				cell.contentConfiguration = content
				cell.accessoryType = .disclosureIndicator
			}
			return cell
		}

		// Properties section
		let rowOffset = editingNode != nil ? 1 : 0 // shift row indices when type picker is hidden
		let effectiveRow = editingNode != nil ? indexPath.row + rowOffset : indexPath.row

		switch effectiveRow {
		case 0: // Type picker (only for new nodes)
			let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseIdentifier, for: indexPath) as! PickerCell
			let types = ["client", "host"]
			let selectedIdx = nodeType == .client ? 0 : 1
			cell.configure(label: "Type", value: types[selectedIdx], options: types, selectedIndex: selectedIdx)
			cell.onSelected = { [weak self] i in
				self?.nodeType = i == 0 ? .client : .host
				tableView.reloadData()
			}
			return cell
		case 1:
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Name", value: nodeName, placeholder: "Node name")
			cell.onTextChanged = { [weak self] t in self?.nodeName = t }
			return cell
		case 2:
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Description", value: nodeDesc, placeholder: "Description")
			cell.onTextChanged = { [weak self] t in self?.nodeDesc = t }
			return cell
		case 3:
			let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseIdentifier, for: indexPath) as! PickerCell
			let hwNames = sortedHardware.map { $0.0 }
			cell.configure(label: "Hardware", value: hwNames.isEmpty ? "—" : hwNames[hwIndex], options: hwNames, selectedIndex: hwIndex)
			cell.onSelected = { [weak self] i in
				self?.hwIndex = i
				tableView.reloadRows(at: [indexPath], with: .none)
			}
			return cell
		case 4:
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Memory (GB)", value: "\(memoryGB)", placeholder: "64", keyboardType: .numberPad)
			cell.onTextChanged = { [weak self] t in self?.memoryGB = Int(t) ?? 64 }
			return cell
		case 5:
			let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseIdentifier, for: indexPath) as! PickerCell
			let zoneNames = design.zones.map(\.name)
			cell.configure(label: "Zone", value: zoneNames.isEmpty ? "—" : zoneNames[zoneIndex], options: zoneNames, selectedIndex: zoneIndex)
			cell.onSelected = { [weak self] i in
				self?.zoneIndex = i
				tableView.reloadRows(at: [indexPath], with: .none)
			}
			return cell
		default:
			return UITableViewCell()
		}
	}

	// MARK: - VM Management

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard indexPath.section == Section.vms.rawValue, let node = editingNode, let vm = node.vm(at: indexPath.row) else { return }

		let editor = VMEditorTVC(host: node, editing: vm) { [weak self] in
			self?.tableView.reloadData()
		}
		let nav = UINavigationController(rootViewController: editor)
		nav.modalPresentationStyle = .formSheet
		present(nav, animated: true)
	}

	@objc func addVM() {
		guard let node = editingNode else { return }
		let editor = VMEditorTVC(host: node) { [weak self] in
			self?.tableView.reloadData()
		}
		let nav = UINavigationController(rootViewController: editor)
		nav.modalPresentationStyle = .formSheet
		present(nav, animated: true)
	}

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		indexPath.section == Section.vms.rawValue
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete, let node = editingNode, let vm = node.vm(at: indexPath.row) else { return }
		node.removeVirtualMachine(vm: vm)
		design.updateServiceProviders()
		design.updateWorkflowDefinitions()
		tableView.reloadData()
	}

	// MARK: - Actions

	@objc func cancelTapped() { dismiss(animated: true) }

	@objc func saveTapped() {
		guard !nodeName.isEmpty else {
			showAlert("Node name is required.")
			return
		}
		guard !design.zones.isEmpty else {
			showAlert("Add zones before creating compute nodes.")
			return
		}
		guard !sortedHardware.isEmpty else {
			showAlert("No hardware definitions available.")
			return
		}

		let hw = sortedHardware[hwIndex].1
		let zone = design.zones[zoneIndex]

		if let node = editingNode {
			node.name = nodeName
			node.desc = nodeDesc
			node.hwDef = hw
			node.memoryGB = memoryGB
			node.zone = zone
		} else {
			let node = ComputeNode(name: nodeName, desc: nodeDesc, hwDef: hw, memoryGB: memoryGB, zone: zone, type: nodeType)
			design.addCompute(node)
		}

		onSave?()
		dismiss(animated: true)
	}

	private func showAlert(_ message: String) {
		let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}
