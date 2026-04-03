//
//  PickerCell.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class PickerCell: UITableViewCell {
	static let reuseIdentifier = "PickerCell"

	var onSelected: ((Int) -> Void)?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: .value1, reuseIdentifier: reuseIdentifier)
		accessoryType = .disclosureIndicator
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(label: String, value: String, options: [String], selectedIndex: Int) {
		var content = defaultContentConfiguration()
		content.text = label
		content.secondaryText = value
		contentConfiguration = content

		let actions = options.enumerated().map { index, option in
			UIAction(title: option, state: index == selectedIndex ? .on : .off) { [weak self] _ in
				self?.onSelected?(index)
			}
		}
		let menu = UIMenu(children: actions)

		// Use a button as accessory to show the menu
		let button = UIButton(type: .system)
		button.menu = menu
		button.showsMenuAsPrimaryAction = true
		button.setImage(UIImage(systemName: "chevron.up.chevron.down"), for: .normal)
		button.sizeToFit()
		accessoryView = button
		accessoryType = .none
	}
}

class ToggleCell: UITableViewCell {
	static let reuseIdentifier = "ToggleCell"

	let toggle = UISwitch()
	var onToggled: ((Bool) -> Void)?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: .default, reuseIdentifier: reuseIdentifier)
		selectionStyle = .none
		accessoryView = toggle
		toggle.addTarget(self, action: #selector(toggled), for: .valueChanged)
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(label: String, isOn: Bool) {
		var content = defaultContentConfiguration()
		content.text = label
		contentConfiguration = content
		toggle.isOn = isOn
	}

	@objc private func toggled() {
		onToggled?(toggle.isOn)
	}
}
