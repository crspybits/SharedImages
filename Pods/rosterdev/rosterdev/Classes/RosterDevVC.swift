//
//  RosterDevVC.swift
//  roster
//
//  Created by Christopher G Prince on 7/26/17.
//  Copyright © 2017 roster. All rights reserved.
//

import UIKit

public struct RosterDevOptions : OptionSet {
    public var rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let versionBuild = RosterDevOptions(rawValue: 1 << 0)
    public static let injectionTests = RosterDevOptions(rawValue: 1 << 1)
    public static let runTestsMultipleTimes = RosterDevOptions(rawValue: 1 << 2)
    
    public static let all:RosterDevOptions = [.versionBuild, .injectionTests, .runTestsMultipleTimes]
}

public struct RosterDevRowContents {
    // Text to show on this row.
    public let name:String
    
    // Is there checkmark (nil or non-nil), and when should it be turned on/off?
    public var checkMark:(()->Bool)? = nil
    
    // Action to occur when tapping this row, if any.
    public let action:((_ parentVC: UIViewController)->())?
    
    public init(name:String, action:((_ parentVC: UIViewController)->())? = nil) {
        self.name = name
        self.action = action
    }
}

public class RosterDevVC: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    var defaultSections = [[RosterDevRowContents]]()
    let cellReuseId = "DeveloperCell"
    fileprivate var sections:[[RosterDevRowContents]]!
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Developer Dashboard"

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellReuseId)
    }
    
    @IBAction func doneAction(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    public class func show(fromViewController vc: UIViewController, rowContents: [[RosterDevRowContents]], options: RosterDevOptions = .versionBuild) {
    
        let bundle = Bundle(for: RosterDevVC.self)
        let dev = UIStoryboard(name: "Developer", bundle: bundle).instantiateViewController(withIdentifier: "RosterDevVC") as! RosterDevVC
        
        let nav = UINavigationController(rootViewController: dev)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            nav.modalTransitionStyle = .coverVertical
            nav.modalPresentationStyle = .formSheet
        }
        
        if options.contains(.injectionTests) {
            var testSection = [RosterDevRowContents]()
            let testCases = RosterDevRowContents(name: "Test cases", action: { parentVC in
                let testCasesVC = UIStoryboard(name: "Developer", bundle: bundle).instantiateViewController(withIdentifier: "InjectionTestVC")
                nav.pushViewController(testCasesVC, animated: true)
            })
            testSection += [testCases]
            
            if options.contains(.runTestsMultipleTimes) {
                var runTestsMultipleTimes = RosterDevRowContents(name: "Run tests multiple times", action: { parentVC in
                    RosterDevInjectTestObjC.session().runTestsMultipleTimes = !RosterDevInjectTestObjC.session().runTestsMultipleTimes
                })
                runTestsMultipleTimes.checkMark = {
                    return RosterDevInjectTestObjC.session().runTestsMultipleTimes
                }
                testSection += [runTestsMultipleTimes]
            }
            
            dev.defaultSections += [testSection]
        }
        
        if options.contains(.versionBuild) {
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    dev.defaultSections += [[
                        RosterDevRowContents(name: "V/B \(version)/\(build)", action: nil)
                    ]]
            }
        }
        
        dev.sections = rowContents + dev.defaultSections
        vc.present(nav, animated: true, completion: nil)
    }
}

extension RosterDevVC : UITableViewDataSource, UITableViewDelegate {
    public func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].count
    }
    
    private func getContents(forRowAtIndexPath indexPath:IndexPath) -> RosterDevRowContents {
        return sections[indexPath.section][indexPath.row]
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
        let contents = getContents(forRowAtIndexPath: indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: cellReuseId, for: indexPath)
        cell.textLabel!.text = contents.name
        
        if let checkMarkAction = contents.checkMark {
            if checkMarkAction() {
                cell.accessoryType = .checkmark
            }
            else {
                cell.accessoryType = .none
            }
        }
        
        return cell
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let contents = getContents(forRowAtIndexPath: indexPath)
        if let action = contents.action {
            action(self)
        }
        
        UIView.transition(with: tableView, duration: 0.35, options: .transitionCrossDissolve, animations: {
            tableView.deselectRow(at: indexPath, animated: false)
            self.tableView.reloadData()
        })
    }
    
    public func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        var footer: UIView?
        
        // Putting a footer right after all except last, to separate them visually.
        if section != numberOfSections(in: tableView) - 1 {
            footer = UIView()
            footer!.backgroundColor = UIColor.lightGray
        }
        
        return footer
    }
    
    public func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 1
    }
}
