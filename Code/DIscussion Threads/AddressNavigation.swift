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
import SwiftLocation

class AddressNavigation {
    static func navigate(to address: String, using viewController: UIViewController) {
        Locator.location(fromAddress: address, onSuccess: { places in
            guard places.count > 0, let coordinate = places[0].coordinates else {
                return
            }
            let location = Location(name: address, coordinate: coordinate)
            Karte.presentPicker(destination: location, presentOn: viewController, title: "Navigate to address using:")
        }) { error  in
            Log.error("error: \(error)")
        }
    }
}
