//
//  Database.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 26.1.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import RealmSwift
import CoreLocation
import GeoQueries

@objcMembers class BumpFromServer: Object {
    
    // MARK: - Persisted properties
    
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
    
    // MARK: - Dynamic non-persisted properties
    
    var coordinates: CLLocationCoordinate2D {
        return CLLocationCoordinate2DMake(latitude, longitude)
    }
    
    // MARK: - Custom init
    
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
    
    // MARK: - Model meta information
    
    override static func primaryKey() -> String? {
        return "b_id"
    }
    
    override static func indexedProperties() -> [String] {
        return ["rating", "count", "type", "fix"]
    }
    
    override static func ignoredProperties() -> [String] {
        return ["coordinates"]
    }
    
}

extension BumpFromServer {
    
    static func all() -> Results<BumpFromServer> {
        let realm = try! Realm()
        return realm.objects(BumpFromServer.self)
    }
    
    static func addOrUpdate(_ bumps: [BumpFromServer]) {
        let realm = try! Realm()
        try! realm.write {
            bumps.forEach {bump in
                realm.add(bump, update: true)
            }
        }
    }
    
    static func findNearby(origin center: CLLocationCoordinate2D, radius: Double, sortAscending sort: Bool?, latitudeKey: String = "latitude", longitudeKey: String = "longitude") -> [BumpFromServer] {
        let realm = try! Realm()
        do {
            let result = try realm.findNearby(type: BumpFromServer.self, origin: center, radius: radius, sortAscending: nil)
            return result
        } catch {
            print("ERROR: Class RealmService, call findNearby()\(error)")
            return []
        }
    }
}

