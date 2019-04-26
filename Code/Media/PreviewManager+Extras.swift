//
//  PreviewManager+Extras.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/23/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import SMLinkPreview

extension PreviewManager {
    static func setup() {
        guard let requestKeyName = MicrosoftURLPreview.requestKeyName,
            let microsoftKey = APIKey.getFromPlist(plistKeyName: "MicrosoftURLPreview", requestKeyName: requestKeyName, plistName: "APIKeys") else {
            return
        }
        
        guard let msPreview = MicrosoftURLPreview(apiKey: microsoftKey) else {
            return
        }
        
        guard let adaPreview = AdaSupportPreview(apiKey: nil) else {
            return
        }
        
        guard let mPreview = MicrolinkPreview(apiKey: nil) else {
            return
        }

        PreviewManager.session.add(source: msPreview)
        PreviewManager.session.add(source: adaPreview)
        PreviewManager.session.add(source: mPreview)
        
        PreviewManager.session.config = PreviewConfiguration(maxNumberTitleLines: 3)
    }
}
