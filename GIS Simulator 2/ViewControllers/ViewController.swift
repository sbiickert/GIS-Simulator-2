//
//  ViewController.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-02-20.
//

import UIKit
import SwiftData

nonisolated enum Section {
	case designs
}

class ViewController: UIViewController {
	var container: ModelContainer?
	
	var collectionView: UICollectionView!
	var dataSource: UICollectionViewDiffableDataSource<Section, PersistentIdentifier>?
	
	override func loadView() {
		super.loadView()
		createCollectionView()
		createDataSource()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		container = try? ModelContainer(for: Design.self)
		loadDesigns()
		
		title = "Add Designs"
		navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Add Samples", style: .plain, target: self, action: #selector(addSamples))
	}

	func createCollectionView() {
		let configuration = UICollectionLayoutListConfiguration(appearance: .plain)
		let layout = UICollectionViewCompositionalLayout.list(using: configuration)
		
		collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
		collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		view.addSubview(collectionView)
		
		collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Design")
	}

	func createDataSource() {
		dataSource = UICollectionViewDiffableDataSource<Section, PersistentIdentifier>(collectionView: collectionView) { collectionView, indexPath, identifier in
			let design = self.container?.mainContext.model(for: identifier) as? Design
			
			var content = UIListContentConfiguration.cell()
			content.text = design?.name ?? "Hello, World!"
			let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Design", for: indexPath)
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
	
	@objc func addSamples() {
		let d1 = Design(name: "First Design", desc: "Design numero uno")
		let d2 = Design(name: "Second Design", desc: "Design the second")
		let d3 = Design(name: "Third Design", desc: "Design trois")
		
		container?.mainContext.insert(d1)
		container?.mainContext.insert(d2)
		container?.mainContext.insert(d3)
		
		loadDesigns()
	}
}

