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
	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground

		let imageView = UIImageView(image: UIImage(systemName: "square.stack.3d.up"))
		imageView.tintColor = .tertiaryLabel
		imageView.contentMode = .scaleAspectFit
		imageView.translatesAutoresizingMaskIntoConstraints = false

		let label = UILabel()
		label.text = "Select a Design"
		label.font = .preferredFont(forTextStyle: .title2)
		label.textColor = .secondaryLabel
		label.translatesAutoresizingMaskIntoConstraints = false

		let stack = UIStackView(arrangedSubviews: [imageView, label])
		stack.axis = .vertical
		stack.alignment = .center
		stack.spacing = 12
		stack.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(stack)

		NSLayoutConstraint.activate([
			imageView.widthAnchor.constraint(equalToConstant: 64),
			imageView.heightAnchor.constraint(equalToConstant: 64),
			stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
			stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
		])
	}
}
