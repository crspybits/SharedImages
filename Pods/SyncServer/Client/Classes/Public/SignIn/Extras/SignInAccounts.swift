
//
//  SignInAccounts.swift
//  SyncServer
//
//  Created by Christopher Prince on 8/5/17.
//  Copyright © 2017 Christopher Prince. All rights reserved.
//

import UIKit

public enum SignInAccount : String {
    case existingAccount = "Existing Account"
    case newAccount = "New Account"
    case sharingAccount = "New Sharing Account"
    case signedIn = "Signed In"
}

private class SignInButtonCell : UITableViewCell {
    var signInButton:UIView!
    
    override func prepareForReuse() {
        super.prepareForReuse()
        signInButton?.removeFromSuperview()
        signInButton = nil
    }
}

class SignInAccounts : UIView {
    @IBOutlet weak var tableView: UITableView!
    let reuseIdentifier = "SignInAccountsCell"
    @IBOutlet private weak var backButton: UIButton!
    @IBOutlet weak var title: UILabel!
    var delegate:SignInSubviewDelegate?
    var currentSignIns:[GenericSignIn]?
    
    // Ignores requests to change title to other than .signedIn if user is signed in.
    func changeTitle(_ title: SignInAccount) {
        self.title.text = title.rawValue
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        tableView.register(SignInButtonCell.self, forCellReuseIdentifier: reuseIdentifier)
        tableView.delegate = self
        tableView.dataSource = self
        
        _ = SignInManager.session.signInStateChanged.addTarget!(self, with: #selector(signInStateChanged))
        
        title.adjustsFontSizeToFitWidth = true
        setup()
    }
    
    deinit {
        SignInManager.session.signInStateChanged.removeTarget!(self, with: #selector(signInStateChanged))
    }
    
    private func setup() {
        // Hiding the back button when a user is signed in because the only action we want to allow is signing out in this case. If no user is signed, then user should be able to go back, and create a new user (not sign-in) if they want.
        backButton.isHidden = SignInManager.session.userIsSignedIn
    }
    
    @objc private func signInStateChanged() {
        if SignInManager.session.userIsSignedIn {
            changeTitle(.signedIn)
        }
        else {
            changeTitle(.existingAccount)
        }
        
        currentSignIns = getCurrentSignIns()
        tableView.reloadData()
        setup()
    }
    
    @IBAction func backAction(_ sender: Any) {
        delegate?.signInNavigateBack(self)
    }
    
    fileprivate func getCurrentSignIns() -> [GenericSignIn] {
        let signIns = SignInManager.session.getSignIns(for: nil)
        if SignInManager.session.userIsSignedIn {
            changeTitle(.signedIn)

            // If user is signed in, only want to present that sign-in button, to allow them to sign out.
            return signIns.filter({$0.userIsSignedIn})
        }
        else {
            // If user is not signed in, show them the full set of possibilities. 
            return signIns
        }
    }
}

extension SignInAccounts : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return currentSignIns?.count ?? 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! SignInButtonCell
        let signInButton = currentSignIns![indexPath.row].signInButton!
        
        // Get some oddness with origins being negative.
        signInButton.frameOrigin = CGPoint.zero
        
        cell.signInButton = signInButton
        cell.contentView.addSubview(signInButton)
        
        signInButton.centerInSuperview()
        
        cell.backgroundColor = UIColor.clear
        cell.contentView.backgroundColor = UIColor.clear

        return cell
    }
}
