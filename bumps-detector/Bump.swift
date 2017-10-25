//
//  Bump.swift
//  accelerometer
//
//  Created by Peter Jurkacek on 15.10.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import Foundation
import CoreLocation

class Bump: NSObject {
    
    //properties
    var intensity: Double?
    //var location: Location?
    var latitude: Double?
    var longitude: Double?
    var rating: Int?
    var manual: Int?
    var type: Int?
    var text: String?
    let TAG = "Bump"
    var androidId: String?
    
    //empty constructor
    
    override init()
    {
        
    }
    
    //construct with @name, @address, @latitude, and @longitude parameters
    
    init(latitude: Double, longitude: Double) {
        
        self.latitude = latitude
        self.longitude = longitude
    }
    
    
    //prints object's current state
    
    override var description: String {
        return "\(String(self.latitude!)), \(String(self.longitude!))"
        
    }
    
    
}

