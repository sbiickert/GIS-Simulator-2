//
//  ConnectionEditorTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class ConnectionEditorTVC: UITableViewController {
	var design: Design!
	var editingConnection: Connection?

	private var sourceIndex = 0
	private var destIndex = 0
	private var bandwidth = 1000
	private var latency = 0
	private var reciprocal = true

	convenience init(design: Design, editing conn: Connection? = nil) {
		self.init(style: .grouped)
		self.design = design
		self.editingConnection = conn

		if let conn {
			sourceIndex = design.zones.firstIndex(of: conn.source) ?? 0
			destIndex = design.zones.firstIndex(of: conn.destination) ?? 0
			bandwidth = conn.bandwidthMbps
			latency = conn.latencyMs
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = editingConnection != nil ? "Edit Connection" : "New Connection"
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
		tableView.register(TextFieldCell.self, forCellReuseIdentifier: TextFieldCell.reuseIdentifier)
		tableView.register(PickerCell.self, forCellReuseIdentifier: PickerCell.reuseIdentifier)
		tableView.register(ToggleCell.self, forCellReuseIdentifier: ToggleCell.reuseIdentifier)
	}

	// MARK: - Table View

	private enum Row: Int, CaseIterable {
		case source, destination, bandwidth, latency, reciprocal
	}

	override func numberOfSections(in tableView: UITableView) -> Int { 1 }

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return editingConnection != nil ? 4 : 5 // hide reciprocal when editing
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		guard let row = Row(rawValue: indexPath.row) else { return UITableViewCell() }
		let zoneNames = design.zones.map(\.name)

		switch row {
		case .source:
			let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseIdentifier, for: indexPath) as! PickerCell
			cell.configure(label: "Source", value: zoneNames.isEmpty ? "—" : zoneNames[sourceIndex], options: zoneNames, selectedIndex: sourceIndex)
			cell.onSelected = { [weak self] i in
				self?.sourceIndex = i
				tableView.reloadRows(at: [indexPath], with: .none)
			}
			return cell
		case .destination:
			let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseIdentifier, for: indexPath) as! PickerCell
			cell.configure(label: "Destination", value: zoneNames.isEmpty ? "—" : zoneNames[destIndex], options: zoneNames, selectedIndex: destIndex)
			cell.onSelected = { [weak self] i in
				self?.destIndex = i
				tableView.reloadRows(at: [indexPath], with: .none)
			}
			return cell
		case .bandwidth:
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Bandwidth (Mbps)", value: "\(bandwidth)", placeholder: "1000", keyboardType: .numberPad)
			cell.onTextChanged = { [weak self] t in self?.bandwidth = Int(t) ?? 1000 }
			return cell
		case .latency:
			let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
			cell.configure(label: "Latency (ms)", value: "\(latency)", placeholder: "0", keyboardType: .numberPad)
			cell.onTextChanged = { [weak self] t in self?.latency = Int(t) ?? 0 }
			return cell
		case .reciprocal:
			let cell = tableView.dequeueReusableCell(withIdentifier: ToggleCell.reuseIdentifier, for: indexPath) as! ToggleCell
			cell.configure(label: "Add Reciprocal", isOn: reciprocal)
			cell.onToggled = { [weak self] v in self?.reciprocal = v }
			return cell
		}
	}

	// MARK: - Actions

	@objc func saveTapped() {
		guard !design.zones.isEmpty else {
			showAlert("Add zones before creating connections.")
			return
		}
		guard sourceIndex != destIndex else {
			showAlert("Source and destination must be different zones.")
			return
		}

		let source = design.zones[sourceIndex]
		let dest = design.zones[destIndex]

		if let conn = editingConnection {
			conn.bandwidthMbps = bandwidth
			conn.latencyMs = latency
		} else {
			let conn = Connection(source: source, destination: dest, bandwidthMbps: bandwidth, latencyMs: latency)
			design.addConnection(conn, addReciprocal: reciprocal)
		}

		navigationController?.popViewController(animated: true)
	}

	private func showAlert(_ message: String) {
		let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}
