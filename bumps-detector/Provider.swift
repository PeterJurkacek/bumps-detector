//
//  Provider.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 17.11.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import Foundation

struct bumps_detect_tb {
    let TABLE_NAME_BUMPS = "my_bumps"
    let B_ID_BUMPS = "b_id_bumps"
    let RATING = "rating"
    let COUNT = "count"
    let LAST_MODIFIED = "last_modified"
    let LATITUDE = "latitude"
    let LONGTITUDE = "longitude"
    let MANUAL = "manual"
    let TYPE = "type"
    let FIX = "fix"
    let INFO = "info"
    let ADMIN_FIX = "admin_fix"
}

struct new_bumps_tb {
    let TABLE_NAME_NEW_BUMPS = "new_bumps"
    let LATITUDE = "latitude"
    let LONGTITUDE = "longitude"
    let INTENSITY = "intensity"
    let MANUAL = "manual"
    let CREATED_AT = "created_at"
    let TYPE = "type"
    let TEXT = "text"
}


