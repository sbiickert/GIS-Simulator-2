//
//  RootTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-02.
//

import UIKit
import SwiftData

class RootTVC: UITableViewController {
	var container: ModelContainer?
	var dataSource: UITableViewDiffableDataSource<Section, PersistentIdentifier>?

	override func loadView() {
		super.loadView()
		createDataSource()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		container = try? ModelContainer(for: Design.self)

		navigationItem.rightBarButtonItem = UIBarButtonItem(
			image: UIImage(systemName: "plus"),
			style: .plain,
			target: self,
			action: #selector(addDesign)
		)

		loadDesigns()
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		loadDesigns()
	}

	// MARK: - Data Source

	func createDataSource() {
		dataSource = UITableViewDiffableDataSource<Section, PersistentIdentifier>(tableView: tableView) { tableView, indexPath, identifier in
			let cell = tableView.dequeueReusableCell(withIdentifier: "DesignCell", for: indexPath)

			var content = UIListContentConfiguration.subtitleCell()
			if let design = self.container?.mainContext.model(for: identifier) as? Design {
				content.text = design.name
				content.secondaryText = design.desc
				if design.isValid {
					content.image = UIImage(systemName: "checkmark.seal.fill")
					content.imageProperties.tintColor = .systemGreen
				} else {
					content.image = UIImage(systemName: "exclamationmark.triangle")
					content.imageProperties.tintColor = .systemOrange
					let tooltip = UIToolTipInteraction(defaultToolTip: design.validate().map { $0.message }.joined(separator: "\n"))
					cell.addInteraction(tooltip)
				}
			} else {
				content.text = "Design was nil"
			}

			cell.contentConfiguration = content
			return cell
		}
	}

	func loadDesigns() {
		let descriptor = FetchDescriptor<Design>(sortBy: [SortDescriptor(\.name)])
		let designs = (try? container?.mainContext.fetch(descriptor)) ?? []

		var snapshot = NSDiffableDataSourceSnapshot<Section, PersistentIdentifier>()
		snapshot.appendSections([.designs])
		snapshot.appendItems(designs.map(\.persistentModelID))

		dataSource?.apply(snapshot, animatingDifferences: true)
	}

	// MARK: - Actions

	@objc func addDesign() {
		let alert = UIAlertController(title: "New Design", message: "Enter a name for the new design.", preferredStyle: .alert)
		alert.addTextField { $0.placeholder = "Design Name" }
		alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
		alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self] _ in
			guard let self, let name = alert.textFields?.first?.text, !name.isEmpty else { return }
			let design = Design(name: name, desc: "")
			self.container?.mainContext.insert(design)
			self.loadDesigns()
		})
		present(alert, animated: true)
	}

	// MARK: - Table View Delegate

	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		guard let identifier = dataSource?.itemIdentifier(for: indexPath) else { return nil }

		let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
			guard let self, let design = self.container?.mainContext.model(for: identifier) as? Design else {
				completion(false)
				return
			}
			self.container?.mainContext.delete(design)
			self.loadDesigns()
			completion(true)
		}
		return UISwipeActionsConfiguration(actions: [delete])
	}

	// MARK: - Navigation

	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		if let designTVC = segue.destination as? DesignTVC,
		   let indexPath = tableView.indexPathForSelectedRow,
		   let identifier = dataSource?.itemIdentifier(for: indexPath) {
			designTVC.container = container
			designTVC.identifier = identifier
		}
	}
}
