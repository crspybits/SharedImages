//
//  AddressNavigation.swift
//  SharedImages
//
//  Created by Christopher G Prince on 4/6/19.
//  Copyright © 2019 Spastic Muffin, LLC. All rights reserved.
//

import Foundation

class AddressNavigation {
/*
    func mapTap() {
        // TODO: Should we do an `updateCoordinates` here?
        if let currentCoords = currentCoords {
            if UIApplication.shared.canOpenURL(URL(string: "comgooglemaps://")!) {
                var message = "Navigate "
                if let placeName = place.name {
                    message += "to \(placeName) "
                }
                message += "using: "
                
                let alert = UIAlertController(title: message, message: nil, preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { alert in
                })
                alert.addAction(UIAlertAction(title: "Apple Maps", style: .default) { alert in
                    self.navigateUsingAppleMaps(to: currentCoords)
                })
                alert.addAction(UIAlertAction(title: "Google Maps", style: .default) { alert in
                    self.navigateUsingGoogleMaps(to: currentCoords)
                })
                viewController.present(alert, animated: true, completion: nil)
            }
            else {
                // No Google maps; just use the native map app
                navigateUsingAppleMaps(to: currentCoords)
            }
        }
    }
    
    private func navigateUsingGoogleMaps(to coords:CLLocation) {
        // URL from https://developers.google.com/maps/documentation/urls/guide#directions-action
        let googleMapsURL = URL(string:"https://www.google.com/maps/dir/?api=1&destination=\(coords.coordinate.latitude),\(coords.coordinate.longitude)")!
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(googleMapsURL, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(googleMapsURL)
        }
    }
    
    // Based on https://stackoverflow.com/questions/12504294/programmatically-open-maps-app-in-ios-6/46507696#46507696
    private func navigateUsingAppleMaps(to coords:CLLocation, locationName: String? = nil) {
        var mapItemName:String?
        if let locationName = locationName {
            mapItemName = locationName
        }
        else {
            mapItemName = place.name
        }
    
        let placemark = MKPlacemark(coordinate: coords.coordinate, addressDictionary:nil)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = mapItemName
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        let currentLocationMapItem = MKMapItem.forCurrentLocation()

        MKMapItem.openMaps(with: [currentLocationMapItem, mapItem], launchOptions: launchOptions)
    }
*/
}
