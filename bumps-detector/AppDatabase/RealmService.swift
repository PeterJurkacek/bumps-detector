//
//  RealmService.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 27.1.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import RealmSwift
import GeoQueries
import CoreLocation

class RealmService {
    
    var realm: Realm
    
    init() {
       realm = try! Realm()
    }
    
    func create<T: Object>(_ object: T){
        do {
            try realm.write {
                realm.add(object)
                print("INFO: Class RealmService, call create() - succes)")
            }
        } catch {
            print("ERROR: Class RealmService, func create()\(error)")
        }
    }
    
    func createOrUpdate<T: Object>(_ object: T){
        do {
            try realm.write {
                realm.add(object, update: true)
                print("INFO: Class RealmService, call createOrUpdate() - succes)")
            }
           
        } catch {
            print("ERROR: Class RealmService, func createOrUpdate()\(error)")
        }
    }
    
    func updateAll<T: Object>( objects: [T]){
        do {
            try realm.write {
                for object in objects {
                    realm.add(object, update: true)
                }
                print("INFO: Class RealmService, call updateAll() - succes)")
            }
        } catch {
            print("ERROR: Class RealmService, func updateAll()\(error)")
        }
    }
    
    func delete<T: Object>(_ object: T){
        do {
            try realm.write {
                realm.delete(object)
                print("INFO: Class RealmService, call delete() - succes)")
            }
        } catch {
            print("ERROR: Class RealmService, call delete()\(error)")
        }
    }
    
    func findNearby<T: Object>(type: T.Type, origin center: CLLocationCoordinate2D, radius: Double, sortAscending sort: Bool?, latitudeKey: String = "latitude", longitudeKey: String = "longitude") -> [T] {
        do {
            return try realm.findNearby(type: type, origin: center, radius: radius, sortAscending: nil)
        } catch {
            print("ERROR: Class RealmService, call findNearby()\(error)")
            return []
        }
    }
    
    func objects<T: Object>(type: T.Type) -> Results<T> {
        return realm.objects(type)
    }
}
