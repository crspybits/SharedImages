//
//  ShareAlbumHelpCell.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/3/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import UIKit

class ShareAlbumHelpCell: UITableViewCell {
    @IBOutlet private weak var helpText: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        guard let url = Bundle.main.url(forResource: "SharingInvitationHelp", withExtension: "html"),
            let data = try? Data(contentsOf: url) else {
            return
        }
        
        // See https://stackoverflow.com/questions/5743844/uilabel-text-as-html-text
        guard let attrString = try? NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html], documentAttributes: nil) else {
            return
        }
      
        helpText.attributedText = attrString
    }
}
