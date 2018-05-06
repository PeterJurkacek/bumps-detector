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
    
//    func delete<T: Object>(_ object: T){
//        do {
//            try realm.write {
//                realm.delete(object)
//                print("INFO: Class RealmService, call delete() - succes)")
//            }
//        } catch {
//            print("ERROR: Class RealmService, call delete()\(error)")
//        }
//    }
    
    func delete(bumpObject: BumpForServer) throws {
        let realm = try! Realm()
        if let bump = realm.object(ofType: BumpForServer.self, forPrimaryKey: bumpObject.id) {
            try realm.write {
                realm.delete(bump)
            }
            print("INFO: Class BumpDetectionAlgorithm, call deleteSelf() - Deleted bump from realm")
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
    
    func insert(bump :BumpForServer) throws {
        try realm.write {
            realm.add(bump, update: false)
        }
        print("INFO: Class BumpDetectionAlgorithm, call saveMeToInternDb() - Saved new bump to realm")
        
    }
    
    func update(oldBump:BumpForServer, newBump:BumpForServer) throws {
        if oldBump.rating <= newBump.rating {
            try realm.write {
                realm.add(newBump, update: true)
            }
            print("INFO: Class BumpDetectionAlgorithm, call saveMeToInternDb() - Updated bump to realm")
        }
    }
    
    func getObject(bump: BumpForServer) -> BumpForServer?{
        return realm.object(ofType: BumpForServer.self, forPrimaryKey: bump.id)
    }
    
    func updateBumpsFromServer(bumps: [Bump]) {
        var bumpsForUpdate = [BumpFromServer]()
        for item in bumps {
            let newBump = BumpFromServer(latitude: (item.latitude as NSString).doubleValue,
                                         longitude: (item.longitude as NSString).doubleValue,
                                         count: (item.count as NSString).integerValue,
                                         b_id: item.b_id,
                                         rating: item.rating,
                                         manual: item.manual,
                                         type: item.type,
                                         fix: item.fix,
                                         admin_fix: item.admin_fix,
                                         info: item.info,
                                         last_modified: item.last_modified)
            bumpsForUpdate.append(newBump)
        }
        let realm = try! Realm()
        try! realm.write {
            bumpsForUpdate.forEach {bump in
                realm.add(bump, update: true)
            }
        }
    }
}
