//
//  InjectionTestVC.swift
//  roster
//
//  Created by Christopher G Prince on 8/9/17.
//  Copyright © 2017 roster. All rights reserved.
//

import Foundation
import UIKit

class InjectionTestVC : UIViewController {
    @IBOutlet weak var tableView: UITableView!
    fileprivate let testCaseNames = RosterDevInjectTest.sortedTestCaseNames
    let cellReuseId = "TestCaseCell"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseId)
    }
}

extension InjectionTestVC : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return testCaseNames.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId, for: indexPath)
        
        let testCaseName = testCaseNames[indexPath.row]
        let testCaseIsOn = RosterDevInjectTest.testIsOn(testCaseName)

        cell.textLabel?.text = testCaseName
        cell.accessoryType = testCaseIsOn ? .checkmark : .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let testCaseName = testCaseNames[indexPath.row]
        let testCaseIsOn = RosterDevInjectTest.testIsOn(testCaseName)
        RosterDevInjectTest.set(testCaseName: testCaseName, value: !testCaseIsOn)
        
        tableView.reloadRows(at: [indexPath], with: .automatic)
    }
}
