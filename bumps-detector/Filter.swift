//
//  Filter.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 5.5.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation

class Filter {
    var count:        Int = 0
    var b_id:         String = ""
    var rating:       String = ""
    var manual:       String = ""
    var type:         String = ""
    var fix:          String = ""
    var admin_fix:    String = ""
    var info:         String = ""
    var last_modified:String = ""
    
    init(
        count: Int      = 0,
        b_id: String    = "",
        rating: String  = "",
        manual: String  = "",
        type: String    = "",
        fix: String     = "",
        admin_fix: String = "",
        info: String    = "",
        last_modified: String = ""){
        
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
    
}
