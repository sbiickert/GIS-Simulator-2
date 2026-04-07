//
//  ServiceProviderEditorTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class ServiceProviderEditorTVC: UITableViewController {
	var design: Design!
	var editingSP: ServiceProvider?

	private var spName = ""
	private var spDesc = ""
	private var serviceIndex = 0
	private var balancingIndex = 0
	private var selectedNodeIndices: Set<Int> = []
	private var tagsText = ""

	private var sortedServices: [ServiceDef] = []
	private let balancingModels: [BalancingModel] = [.single, .roundRobin, .failover, .containerized, .other]

	private enum Section: Int, CaseIterable {
		case properties
		case nodes
	}

	convenience init(design: Design, editing sp: ServiceProvider? = nil) {
		self.init(style: .grouped)
		self.design = design
		self.editingSP = sp

		sortedServices = design.services.values.sorted(by: { $0.serviceType < $1.serviceType })

		if let sp {
			spName = sp.name
			spDesc = sp.desc
			serviceIndex = sortedServices.firstIndex(where: { $0.serviceType == sp.service.serviceType }) ?? 0
			balancingIndex = balancingModels.firstIndex(of: sp.service.balancingModel) ?? 0
			tagsText = sp.tags.sorted().joined(separator: ", ")
			let allNodes = design.allComputeNodes
			for (i, node) in allNodes.enumerated() {
				if sp.nodes.contains(node) {
					selectedNodeIndices.insert(i)
				}
			}
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = editingSP != nil ? "Edit Service Provider" : "New Service Provider"
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
		tableView.register(TextFieldCell.self, forCellReuseIdentifier: TextFieldCell.reuseIdentifier)
		tableView.register(PickerCell.self, forCellReuseIdentifier: PickerCell.reuseIdentifier)
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "NodeCell")
	}

	// MARK: - Table View

	override func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if section == Section.properties.rawValue { return 4 }
		return design.allComputeNodes.count
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		section == Section.nodes.rawValue ? "Nodes (select one or more)" : nil
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.section == Section.nodes.rawValue {
			let cell = tableView.dequeueReusableCell(withIdentifier: "NodeCell", for: indexPath)
			let node = design.allComputeNodes[indexPath.row]
			var content = UIListContentConfiguration.cell()
			content.text = "\(node.name) (\(node.type) in \(node.zone.name))"
			cell.contentConfiguration = content
			cell.accessoryType = selectedNodeIndices.contains(indexPath.row) ? .checkmark : .none
			return cell
		}

		switch indexPath.row {
		case 0:
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Name", value: spName, placeholder: "Provider name")
			cell.onTextChanged = { [weak self] t in self?.spName = t }
			return cell
		case 1:
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Description", value: spDesc, placeholder: "Description")
			cell.onTextChanged = { [weak self] t in self?.spDesc = t }
			return cell
		case 2:
			let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseIdentifier, for: indexPath) as! PickerCell
			let names = sortedServices.map(\.serviceType)
			cell.configure(label: "Service", value: names.isEmpty ? "—" : names[serviceIndex], options: names, selectedIndex: serviceIndex)
			cell.onSelected = { [weak self] i in
				self?.serviceIndex = i
				tableView.reloadRows(at: [indexPath], with: .none)
			}
			return cell
		case 3:
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Tags", value: tagsText, placeholder: "tag1, tag2")
			cell.onTextChanged = { [weak self] t in self?.tagsText = t }
			return cell
		default:
			return UITableViewCell()
		}
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard indexPath.section == Section.nodes.rawValue else { return }

		if selectedNodeIndices.contains(indexPath.row) {
			selectedNodeIndices.remove(indexPath.row)
		} else {
			selectedNodeIndices.insert(indexPath.row)
		}
		tableView.reloadRows(at: [indexPath], with: .automatic)
	}

	// MARK: - Actions

	@objc func saveTapped() {
		guard !spName.isEmpty else {
			showAlert("Provider name is required.")
			return
		}
		guard !sortedServices.isEmpty else {
			showAlert("Add service definitions before creating providers.")
			return
		}

		let service = sortedServices[serviceIndex]
		let allNodes = design.allComputeNodes
		let nodes = selectedNodeIndices.sorted().compactMap { i -> ComputeNode? in
			i < allNodes.count ? allNodes[i] : nil
		}
		let tags = Set(tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })

		if let sp = editingSP {
			sp.name = spName
			sp.desc = spDesc
			sp.nodes = nodes
			sp.tags = tags
		} else {
			let sp = ServiceProvider(name: spName, desc: spDesc, service: service, nodes: nodes, tags: tags)
			design.addServiceProvider(sp)
		}

		navigationController?.popViewController(animated: true)
	}

	private func showAlert(_ message: String) {
		let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}
