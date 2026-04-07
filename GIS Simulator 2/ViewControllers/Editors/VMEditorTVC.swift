//
//  VMEditorTVC.swift
//  GIS Simulator 2
//
//  Created by Simon Biickert on 2026-04-03.
//

import UIKit

class VMEditorTVC: UITableViewController {
	var host: ComputeNode!
	var editingVM: ComputeNode?

	private var vmName = ""
	private var vCores = 4
	private var memoryGB = 16

	convenience init(host: ComputeNode, editing vm: ComputeNode? = nil) {
		self.init(style: .grouped)
		self.host = host
		self.editingVM = vm

		if let vm {
			vmName = vm.name
			vCores = vm.vCores
			memoryGB = vm.memoryGB
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		title = editingVM != nil ? "Edit VM" : "New VM"
		navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(saveTapped))
		tableView.register(TextFieldCell.self, forCellReuseIdentifier: TextFieldCell.reuseIdentifier)
	}

	override func numberOfSections(in tableView: UITableView) -> Int { 1 }
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 3 }

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCell(withIdentifier: TextFieldCell.reuseIdentifier, for: indexPath) as! TextFieldCell
		switch indexPath.row {
		case 0:
			cell.configure(label: "Name", value: vmName, placeholder: "VM name (optional)")
			cell.onTextChanged = { [weak self] t in self?.vmName = t }
		case 1:
			cell.configure(label: "vCores", value: "\(vCores)", placeholder: "4", keyboardType: .numberPad)
			cell.onTextChanged = { [weak self] t in self?.vCores = Int(t) ?? 4 }
		case 2:
			cell.configure(label: "Memory (GB)", value: "\(memoryGB)", placeholder: "16", keyboardType: .numberPad)
			cell.onTextChanged = { [weak self] t in self?.memoryGB = Int(t) ?? 16 }
		default: break
		}
		return cell
	}

	@objc func saveTapped() {
		if let vm = editingVM {
			vm.name = vmName
			vm.memoryGB = memoryGB
		} else {
			_ = host.addVirtualMachine(name: vmName.isEmpty ? nil : vmName, vCores: vCores, memoryGB: memoryGB)
		}
		navigationController?.popViewController(animated: true)
	}
}
