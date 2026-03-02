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
		loadDesigns()
	}

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

	func createDataSource() {
		dataSource = UITableViewDiffableDataSource<Section, PersistentIdentifier>(tableView: tableView) { tableView, indexPath, identifier in
			let cell = tableView.dequeueReusableCell(withIdentifier: "DesignCell", for: indexPath)

			var content = UIListContentConfiguration.cell()
			if let design = self.container?.mainContext.model(for: identifier) as? Design {
				content.text = design.name
				content.image = UIImage(systemName: "checkmark.seal.fill")
				content.secondaryText = design.desc
				if design.isValid == false {
					content.image = UIImage(systemName: "exclamationmark.triangle")
					let tooltip = UIToolTipInteraction(defaultToolTip: design.validate().map {$0.message}.joined(separator: "\n"))
					cell.addInteraction(tooltip)
				}
			}
			else {
				content.text = "Design was nil"
			}
			
			cell.contentConfiguration = content
			
			return cell
		}
	}
	
	func loadDesigns() {
		let descriptor = FetchDescriptor<Design>()
		let designs = (try? container?.mainContext.fetch(descriptor)) ?? []
		
		var snapshot = NSDiffableDataSourceSnapshot<Section, PersistentIdentifier>()
		snapshot.appendSections([.designs])
		snapshot.appendItems(designs.map(\.persistentModelID))
		
		dataSource?.apply(snapshot, animatingDifferences: true)
	}

}
