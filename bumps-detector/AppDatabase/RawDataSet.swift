//
//  RawDataSet.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 9.5.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import RealmSwift
import Mapbox
import CoreMotion

@objcMembers class RawDataSet: Object {
    
    // MARK: - Persisted properties
    dynamic var isBump: Bool = false
    dynamic var isUserMovement: Bool = false
    dynamic var created_at: String = ""
    dynamic var x: Double = 0.0
    dynamic var y: Double = 0.0
    dynamic var z: Double = 0.0
    dynamic var xGravity: Double = 0.0
    dynamic var yGravity: Double = 0.0
    dynamic var zGravity: Double = 0.0
//    dynamic var roll: Double = 0.0
//    dynamic var pitch: Double = 0.0
//    dynamic var yaw: Double = 0.0
    
    // MARK: - Custom init
    
    convenience init(data: CMDeviceMotion, isBump: Bool = false, isUserMovement: Bool = false){
        self.init()
        self.isBump =  isBump
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        self.created_at = dateFormatter.string(from: Date())
        self.isUserMovement = isUserMovement
        self.x = data.userAcceleration.x
        self.y = data.userAcceleration.y
        self.z = data.userAcceleration.z
        self.xGravity = data.gravity.x
        self.yGravity = data.gravity.y
        self.zGravity = data.gravity.z
//        self.roll = data.attitude.roll
//        self.pitch = data.attitude.pitch
//        self.yaw = data.attitude.yaw
        
    }
    
}
// MARK: - Entity model methods

extension RawDataSet {
    
    static func all() -> Results<RawDataSet> {
        let realm = try! Realm()
        return realm.objects(RawDataSet.self)
    }
    
    func deleteSelf() throws {
        let realm = try! Realm()
        try realm.write {
            realm.delete(self)
        }
        print("INFO: Class BumpDetectionAlgorithm, call deleteSelf() - Deleted bump from realm")
    }
    
    func saveMeToInternDb() throws {
        let realm = try! Realm()
        try realm.write {
            realm.add(self, update: false)
        }
        print("INFO: Class BumpDetectionAlgorithm, call saveMeToInternDb() - Saved new bump to realm")
    }
}
