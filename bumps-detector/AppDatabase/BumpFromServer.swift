//
//  Database.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 26.1.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import RealmSwift

@objcMembers class BumpFromServer: Object {
    
    dynamic var latitude:     Double = 0.0
    dynamic var longitude:    Double = 0.0
    dynamic var count:        Int = 0
    dynamic var b_id:         String = ""
    dynamic var rating:       String = ""
    dynamic var manual:       String = ""
    dynamic var type:         String = ""
    dynamic var fix:          String = ""
    dynamic var admin_fix:    String = ""
    dynamic var info:         String = ""
    dynamic var last_modified:String = ""
    
    convenience init(
                    latitude: Double,
                    longitude: Double,
                    count: Int,
                    b_id: String,
                    rating: String,
                    manual: String,
                    type: String,
                    fix: String,
                    admin_fix: String,
                    info: String,
                    last_modified: String){
        
        self.init()
        self.latitude = latitude
        self.longitude = longitude
        self.count = count
        self.b_id = b_id
        self.rating = rating
        self.manual = manual
        self.type = type
        self.fix = fix
        self.admin_fix = admin_fix
        self.info = info
        self.last_modified=last_modified
        
    }
    
    override static func primaryKey() -> String? {
        return "b_id"
    }
}

