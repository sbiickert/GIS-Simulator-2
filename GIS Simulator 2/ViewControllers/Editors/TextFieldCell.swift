//
//  TextFieldCell.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class TextFieldCell: UITableViewCell {
	static let reuseIdentifier = "TextFieldCell"

	let label = UILabel()
	let textField = UITextField()
	var onTextChanged: ((String) -> Void)?

	override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)
		selectionStyle = .none

		label.translatesAutoresizingMaskIntoConstraints = false
		label.setContentHuggingPriority(.defaultHigh, for: .horizontal)
		label.setContentCompressionResistancePriority(.required, for: .horizontal)
		label.font = .preferredFont(forTextStyle: .body)
		label.textColor = .label

		textField.translatesAutoresizingMaskIntoConstraints = false
		textField.textAlignment = .right
		textField.font = .preferredFont(forTextStyle: .body)
		textField.textColor = .secondaryLabel
		textField.returnKeyType = .done
		textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
		textField.delegate = self

		let stack = UIStackView(arrangedSubviews: [label, textField])
		stack.translatesAutoresizingMaskIntoConstraints = false
		stack.axis = .horizontal
		stack.spacing = 12
		stack.alignment = .center

		contentView.addSubview(stack)
		NSLayoutConstraint.activate([
			stack.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
			stack.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
			stack.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
			stack.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor)
		])
	}

	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(label text: String, value: String, placeholder: String = "", keyboardType: UIKeyboardType = .default) {
		label.text = text
		textField.text = value
		textField.placeholder = placeholder
		textField.keyboardType = keyboardType
	}

	@objc private func textChanged() {
		onTextChanged?(textField.text ?? "")
	}
}

extension TextFieldCell: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder()
		return true
	}
}
