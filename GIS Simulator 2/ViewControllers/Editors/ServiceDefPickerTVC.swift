//
//  ServiceDefPickerTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class ServiceDefPickerTVC: UITableViewController {
	var design: Design!
	var onSave: (() -> Void)?

	private let library = Library()
	private var availableServices: [(String, ServiceDef)] = []

	convenience init(design: Design, onSave: (() -> Void)? = nil) {
		self.init(style: .grouped)
		self.design = design
		self.onSave = onSave
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = "Add Services"
		navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
		tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ServiceCell")
		tableView.allowsMultipleSelection = true

		let existingTypes = Set(design.services.keys)
		availableServices = library.serviceDefinitions
			.sorted(by: { $0.key < $1.key })
			.filter { !existingTypes.contains($0.key) }
	}

	override func numberOfSections(in tableView: UITableView) -> Int { 1 }
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { availableServices.count }

	override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
		availableServices.isEmpty ? "All service types have been added" : "Select service types to add"
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: "ServiceCell", for: indexPath)
		let (_, serviceDef) = availableServices[indexPath.row]
		var content = UIListContentConfiguration.subtitleCell()
		content.text = serviceDef.name
		content.secondaryText = "\(serviceDef.serviceType) - \(serviceDef.balancingModel)"
		cell.contentConfiguration = content
		return cell
	}

	@objc func cancelTapped() { dismiss(animated: true) }

	@objc func doneTapped() {
		if let selectedRows = tableView.indexPathsForSelectedRows {
			for indexPath in selectedRows {
				let (_, serviceDef) = availableServices[indexPath.row]
				design.addServiceDef(serviceDef)
			}
		}
		onSave?()
		dismiss(animated: true)
	}
}
