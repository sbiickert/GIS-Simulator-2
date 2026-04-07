//
//  ZoneEditorTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class ZoneEditorTVC: UITableViewController {
	var design: Design!
	var editingZone: Zone?

	private var zoneName = ""
	private var zoneDesc = ""
	private var bandwidth = 1000
	private var latency = 0

	convenience init(design: Design, editing zone: Zone? = nil) {
		self.init(style: .grouped)
		self.design = design
		self.editingZone = zone

		if let zone {
			zoneName = zone.name
			zoneDesc = zone.desc
			if let localConn = zone.localConnection(in: design.network) {
				bandwidth = localConn.bandwidthMbps
				latency = localConn.latencyMs
			}
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = editingZone != nil ? "Edit Zone" : "New Zone"
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
		tableView.register(TextFieldCell.self, forCellReuseIdentifier: TextFieldCell.reuseIdentifier)
	}

	// MARK: - Table View

	override func numberOfSections(in tableView: UITableView) -> Int { 1 }
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { editingZone != nil ? 2 : 4 }

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
		switch indexPath.row {
		case 0:
			cell.configure(label: "Name", value: zoneName, placeholder: "Zone name")
			cell.onTextChanged = { [weak self] t in self?.zoneName = t }
		case 1:
			cell.configure(label: "Description", value: zoneDesc, placeholder: "Description")
			cell.onTextChanged = { [weak self] t in self?.zoneDesc = t }
		case 2:
			cell.configure(label: "Local Bandwidth (Mbps)", value: "\(bandwidth)", placeholder: "1000", keyboardType: .numberPad)
			cell.onTextChanged = { [weak self] t in self?.bandwidth = Int(t) ?? 1000 }
		case 3:
			cell.configure(label: "Local Latency (ms)", value: "\(latency)", placeholder: "0", keyboardType: .numberPad)
			cell.onTextChanged = { [weak self] t in self?.latency = Int(t) ?? 0 }
		default: break
		}
		return cell
	}

	// MARK: - Actions

	@objc func saveTapped() {
		guard !zoneName.isEmpty else {
			showAlert("Zone name is required.")
			return
		}

		if let zone = editingZone {
			zone.name = zoneName
			zone.desc = zoneDesc
		} else {
			let zone = Zone(name: zoneName, description: zoneDesc)
			design.addZone(zone, localBandwidthMbps: bandwidth, localLatencyMS: latency)
		}

		navigationController?.popViewController(animated: true)
	}

	private func showAlert(_ message: String) {
		let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
		alert.addAction(UIAlertAction(title: "OK", style: .default))
		present(alert, animated: true)
	}
}
