//
//  Database.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 26.1.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers class BumpForServer: Object {
    
    dynamic var created_at =  Date()
    dynamic var intensity:    String = ""
    dynamic var latitude:     String = ""
    dynamic var longitude:    String = ""
    dynamic var manual:       String = ""
    dynamic var text:         String = ""
    dynamic var type:         String = ""
    
    convenience init(
                    intensity: String,
                    latitude: String,
                    longitude: String,
                    manual: String,
                    text: String,
                    type: String){
        self.init()
        self.intensity = intensity
        self.latitude = latitude
        self.longitude = longitude
        self.manual = manual
        self.text = text
        self.type = type
        
    }
}

