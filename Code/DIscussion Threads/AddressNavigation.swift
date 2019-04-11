//
//  AddressNavigation.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/6/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation
import Karte
import CoreLocation
import LMGeocoderUniversal

class AddressNavigation {
    static func navigate(to address: String, using viewController: UIViewController) {
        LMGeocoder.sharedInstance().geocodeAddressString(address, service: .appleService) { addresses, error in
            guard let addresses = addresses, let addrObj = addresses.first, error == nil else {
                return
            }
            
            let coord = addrObj.coordinate
            let location = Location(name: address, coordinate: coord)
            Karte.presentPicker(destination: location, presentOn: viewController, title: "Navigate to address using:")
        }
    }
}
