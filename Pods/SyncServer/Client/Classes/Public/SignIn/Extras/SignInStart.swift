
//
//  SignInStart.swift
//  SyncServer
//
//  Created by Christopher Prince on 8/5/17.
//  Copyright © 2017 Christopher Prince. All rights reserved.
//

import UIKit
import SyncServer_Shared

public class SignInStart : UIView {
    @IBOutlet weak var signIn: UIButton!
    var delegate:SignInSubviewDelegate?

    public override func awakeFromNib() {
        super.awakeFromNib()
        signIn.titleLabel?.textAlignment = .center
    }
    
    @IBAction func signInAction(_ sender: Any) {
        delegate?.showSignIns(for: .existingAccount, forSignInSubView: self)
    }
    
    @IBAction func createNewAccountAction(_ sender: Any) {
        delegate?.showSignIns(for: .newAccount, forSignInSubView: self)
    }
}
