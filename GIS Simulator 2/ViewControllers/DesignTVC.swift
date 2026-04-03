//
//  DesignTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-02.
//

import UIKit
import SwiftData

class DesignTVC: UITableViewController {
	var container: ModelContainer?
	var identifier: PersistentIdentifier?

	private var design: Design? {
		guard let identifier else { return nil }
		return container?.mainContext.model(for: identifier) as? Design
	}

	private enum DesignSection: Int, CaseIterable {
		case info
		case zones
		case network
		case compute
		case services
		case serviceProviders
		case workflowDefs
		case workflows
		case validation

		var title: String {
			switch self {
			case .info: return "Info"
			case .zones: return "Zones"
			case .network: return "Network"
			case .compute: return "Compute"
			case .services: return "Services"
			case .serviceProviders: return "Service Providers"
			case .workflowDefs: return "Workflow Definitions"
			case .workflows: return "Workflows"
			case .validation: return "Validation"
			}
		}

		var canAdd: Bool {
			switch self {
			case .info, .validation: return false
			default: return true
			}
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		container = container ?? (try? ModelContainer(for: Design.self))

		tableView.register(TextFieldCell.self, forCellReuseIdentifier: TextFieldCell.reuseIdentifier)
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SubtitleCell")
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SimpleTextCell")
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		title = design?.name ?? "Design"
		tableView.reloadData()
	}

	// MARK: - Table View Data Source

	override func numberOfSections(in tableView: UITableView) -> Int {
		guard design != nil else { return 0 }
		return DesignSection.allCases.count
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		guard let design, let ds = DesignSection(rawValue: section) else { return 0 }
		switch ds {
		case .info: return 2
		case .zones: return design.zones.count
		case .network: return design.network.count
		case .compute: return design.physicalComputeNodes.count
		case .services: return design.services.count
		case .serviceProviders: return design.serviceProviders.count
		case .workflowDefs: return design.workflowDefinitions.count
		case .workflows: return design.allWorkflows.count
		case .validation:
			let msgs = design.validate()
			return msgs.isEmpty ? 1 : msgs.count
		}
	}

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		return DesignSection(rawValue: section)?.title
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let design, let ds = DesignSection(rawValue: indexPath.section) else {
			return UITableViewCell()
		}

		switch ds {
		case .info:
			return infoCell(for: indexPath, design: design)
		case .zones:
			return zoneCell(for: indexPath, design: design)
		case .network:
			return connectionCell(for: indexPath, design: design)
		case .compute:
			return computeCell(for: indexPath, design: design)
		case .services:
			return serviceCell(for: indexPath, design: design)
		case .serviceProviders:
			return serviceProviderCell(for: indexPath, design: design)
		case .workflowDefs:
			return workflowDefCell(for: indexPath, design: design)
		case .workflows:
			return workflowCell(for: indexPath, design: design)
		case .validation:
			return validationCell(for: indexPath, design: design)
		}
	}

	// MARK: - Cell Builders

	private func infoCell(for indexPath: IndexPath, design: Design) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
		if indexPath.row == 0 {
			cell.configure(label: "Name", value: design.name, placeholder: "Design name")
			cell.onTextChanged = { [weak self] text in
				design.name = text
				self?.title = text
			}
		} else {
			cell.configure(label: "Description", value: design.desc, placeholder: "Description")
			cell.onTextChanged = { text in
				design.desc = text
			}
		}
		return cell
	}

	private func zoneCell(for indexPath: IndexPath, design: Design) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SubtitleCell", for: indexPath)
		let zone = design.zones[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = zone.name
		content.secondaryText = zone.desc
		cell.contentConfiguration = content
		cell.accessoryType = .disclosureIndicator
		return cell
	}

	private func connectionCell(for indexPath: IndexPath, design: Design) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SubtitleCell", for: indexPath)
		let conn = design.network[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = conn.name
		content.secondaryText = "\(conn.bandwidthMbps) Mbps, \(conn.latencyMs) ms latency"
		cell.contentConfiguration = content
		cell.accessoryType = .disclosureIndicator
		return cell
	}

	private func computeCell(for indexPath: IndexPath, design: Design) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SubtitleCell", for: indexPath)
		let node = design.physicalComputeNodes[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = node.name
		var details = "\(node.type) - \(node.hwDef.processor) - \(node.zone.name)"
		if node.type == .host {
			details += " (\(node.vmCount) VMs)"
		}
		content.secondaryText = details
		cell.contentConfiguration = content
		cell.accessoryType = .disclosureIndicator
		return cell
	}

	private func serviceCell(for indexPath: IndexPath, design: Design) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SubtitleCell", for: indexPath)
		let serviceDef = Array(design.services.values).sorted(by: { $0.serviceType < $1.serviceType })[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = serviceDef.name
		content.secondaryText = "\(serviceDef.serviceType) - \(serviceDef.balancingModel)"
		cell.contentConfiguration = content
		cell.accessoryType = .none
		return cell
	}

	private func serviceProviderCell(for indexPath: IndexPath, design: Design) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SubtitleCell", for: indexPath)
		let sp = design.serviceProviders[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = sp.name
		let nodeNames = sp.nodes.map(\.name).joined(separator: ", ")
		content.secondaryText = "\(sp.service.serviceType) on \(nodeNames.isEmpty ? "no nodes" : nodeNames)"
		cell.contentConfiguration = content
		cell.accessoryType = .disclosureIndicator
		return cell
	}

	private func workflowDefCell(for indexPath: IndexPath, design: Design) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SubtitleCell", for: indexPath)
		let wfDef = design.workflowDefinitions[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = wfDef.name
		let missing = wfDef.missingServiceProviders
		if missing.isEmpty {
			content.secondaryText = "\(wfDef.chains.count) chains, think time: \(wfDef.thinkTimeSeconds)s"
		} else {
			content.secondaryText = "Missing providers: \(missing.joined(separator: ", "))"
			content.secondaryTextProperties.color = .systemOrange
		}
		cell.contentConfiguration = content
		cell.accessoryType = .disclosureIndicator
		return cell
	}

	private func workflowCell(for indexPath: IndexPath, design: Design) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SubtitleCell", for: indexPath)
		let workflow = design.allWorkflows[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = workflow.name
		switch workflow.type {
		case .user:
			content.secondaryText = "User: \(workflow.userCount) users, productivity \(workflow.productivity)"
		case .transactional:
			content.secondaryText = "Transactional: \(workflow.tph) tph"
		}
		cell.contentConfiguration = content
		cell.accessoryType = .disclosureIndicator
		return cell
	}

	private func validationCell(for indexPath: IndexPath, design: Design) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "SimpleTextCell", for: indexPath)
		let messages = design.validate()
		var content = UIListContentConfiguration.cell()
		if messages.isEmpty {
			content.text = "Design is valid"
			content.image = UIImage(systemName: "checkmark.seal.fill")
			content.imageProperties.tintColor = .systemGreen
		} else {
			let msg = messages[indexPath.row]
			content.text = msg.message
			content.secondaryText = msg.source
			content.image = UIImage(systemName: "exclamationmark.triangle")
			content.imageProperties.tintColor = .systemOrange
		}
		cell.contentConfiguration = content
		cell.selectionStyle = .none
		return cell
	}

	// MARK: - Section Headers with Add Buttons

	override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		guard let ds = DesignSection(rawValue: section), ds.canAdd else { return nil }

		let header = UITableViewHeaderFooterView()
		var content = UIListContentConfiguration.groupedHeader()
		content.text = ds.title
		header.contentConfiguration = content

		let addButton = UIButton(type: .contactAdd)
		addButton.tag = section
		addButton.addTarget(self, action: #selector(addButtonTapped(_:)), for: .touchUpInside)
		addButton.translatesAutoresizingMaskIntoConstraints = false
		header.contentView.addSubview(addButton)
		NSLayoutConstraint.activate([
			addButton.trailingAnchor.constraint(equalTo: header.contentView.trailingAnchor, constant: -16),
			addButton.centerYAnchor.constraint(equalTo: header.contentView.centerYAnchor)
		])

		return header
	}

	// MARK: - Add Actions

	@objc func addButtonTapped(_ sender: UIButton) {
		guard let ds = DesignSection(rawValue: sender.tag), let design else { return }

		switch ds {
		case .zones:
			presentEditor(ZoneEditorTVC(design: design, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .network:
			presentEditor(ConnectionEditorTVC(design: design, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .compute:
			presentEditor(ComputeNodeEditorTVC(design: design, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .services:
			presentEditor(ServiceDefPickerTVC(design: design, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .serviceProviders:
			presentEditor(ServiceProviderEditorTVC(design: design, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .workflowDefs:
			presentEditor(WorkflowDefPickerTVC(design: design, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .workflows:
			presentEditor(WorkflowEditorTVC(design: design, onSave: { [weak self] in self?.tableView.reloadData() }))
		default:
			break
		}
	}

	private func presentEditor(_ editor: UITableViewController) {
		let nav = UINavigationController(rootViewController: editor)
		nav.modalPresentationStyle = .formSheet
		present(nav, animated: true)
	}

	// MARK: - Row Selection (Edit)

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		tableView.deselectRow(at: indexPath, animated: true)
		guard let ds = DesignSection(rawValue: indexPath.section), let design else { return }

		switch ds {
		case .zones:
			let zone = design.zones[indexPath.row]
			presentEditor(ZoneEditorTVC(design: design, editing: zone, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .network:
			let conn = design.network[indexPath.row]
			presentEditor(ConnectionEditorTVC(design: design, editing: conn, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .compute:
			let node = design.physicalComputeNodes[indexPath.row]
			presentEditor(ComputeNodeEditorTVC(design: design, editing: node, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .serviceProviders:
			let sp = design.serviceProviders[indexPath.row]
			presentEditor(ServiceProviderEditorTVC(design: design, editing: sp, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .workflowDefs:
			let wfDef = design.workflowDefinitions[indexPath.row]
			presentEditor(WorkflowChainEditorTVC(design: design, workflowDef: wfDef, onSave: { [weak self] in self?.tableView.reloadData() }))
		case .workflows:
			let wf = design.allWorkflows[indexPath.row]
			presentEditor(WorkflowEditorTVC(design: design, editing: wf, onSave: { [weak self] in self?.tableView.reloadData() }))
		default:
			break
		}
	}

	// MARK: - Swipe to Delete

	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		guard let ds = DesignSection(rawValue: indexPath.section) else { return false }
		return ds.canAdd
	}

	override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
		guard editingStyle == .delete, let design, let ds = DesignSection(rawValue: indexPath.section) else { return }

		switch ds {
		case .zones:
			design.removeZone(design.zones[indexPath.row])
		case .network:
			design.removeConnection(design.network[indexPath.row])
		case .compute:
			design.removeCompute(design.physicalComputeNodes[indexPath.row])
		case .services:
			let key = Array(design.services.keys).sorted()[indexPath.row]
			if let def = design.services[key] {
				design.removeServiceDef(def)
			}
		case .serviceProviders:
			design.removeServiceProvider(design.serviceProviders[indexPath.row])
		case .workflowDefs:
			design.removeWorkflowDefinition(design.workflowDefinitions[indexPath.row])
			design.updateConfiguredWorkflows()
		case .workflows:
			design.removeWorkflow(design.allWorkflows[indexPath.row])
		default:
			break
		}

		tableView.reloadData()
	}
}
