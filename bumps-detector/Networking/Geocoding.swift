//
//  Geocoding.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 1.4.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import CoreLocation
import Contacts

protocol GeocodingService {
    func forwardGeocoding(address: String)
    func reverseGeocoding(latitude: CLLocationDegrees, longitude: CLLocationDegrees)
}

class AppleMapSearch : GeocodingService {
    
    func forwardGeocoding(address: String) {
        CLGeocoder().geocodeAddressString(address, completionHandler: { (placemarks, error) in
            if error != nil {
                print(error!.localizedDescription)
                return
            }
            if (placemarks?.count)! > 0 {
                let placemark = placemarks?[0]
                let location = placemark?.location
                let coordinate = location?.coordinate
                print("\nlat: \(coordinate!.latitude), long: \(coordinate!.longitude)")
                if (placemark?.areasOfInterest?.count)! > 0 {
                    let areaOfInterest = placemark!.areasOfInterest![0]
                    print(areaOfInterest)
                } else {
                    print("No area of interest found.")
                }
            }
        })
    }
    
    func reverseGeocoding(latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
//        let location = CLLocation(latitude: latitude, longitude: longitude)
//        CLGeocoder().reverseGeocodeLocation(location, completionHandler: {(placemarks, error) -> Void in
//            if error != nil {
//                print(error.debugDescription)
//                return
//            }
//            else if (placemarks?.count)! > 0 {
//                let pm = placemarks![0]
//                CNPostalAddressFormatter(coder: <#T##NSCoder#>)
//                let address = CNPostalAddressFormatter(pm.addressDictionary!, false)
//                print("\n\(address)")
//                if (pm.areasOfInterest?.count)! > 0 {
//                    let areaOfInterest = pm.areasOfInterest?[0]
//                    print(areaOfInterest!)
//                } else {
//                    print("No area of interest found.")
//                }
//            }
//        })
    }
    
}
