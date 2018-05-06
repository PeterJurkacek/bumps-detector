//
//  Database.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 26.1.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import RealmSwift
import Mapbox

@objcMembers class BumpForServer: Object {
    
    // MARK: - Persisted properties
    
    //dynamic var id         =  UUID().uuidString
    dynamic var id:           String = ""
    dynamic var created_at =  Date()
    dynamic var intensity:    String = ""
    dynamic var latitude:     String = ""
    dynamic var longitude:    String = ""
    dynamic var manual:       String = ""
    dynamic var text:         String = ""
    dynamic var type:         String = ""
    dynamic var rating:       String = ""
    
    // MARK: - Custom init
    
    convenience init(
                    intensity: String,
                    latitude:  String,
                    longitude: String,
                    manual:    String,
                    text:      String,
                    type:      String){
        self.init()
        self.intensity = intensity
        self.rating = calculateRating(from: intensity)
        self.latitude = latitude
        self.longitude = longitude
        self.manual = manual
        self.text = text
        self.type = type
        self.id = "\(latitude)#\(longitude)"
        
    }
    
    private func calculateRating(from intensity: String) -> String {
        if let double_intensity = Double(intensity) {
            if      (0.0 <= double_intensity && double_intensity < 6.0)       { return "1" } //Maly vytlk
            else if (6.0 <= double_intensity && double_intensity < 10.0)      { return "2" } //Stredny vytlk
            else if (10.0 <= double_intensity && double_intensity < 10000.0)  { return "3" } //Velky vytlk
            else {
                print("ERROR: Class BumpForServer, call calculateRating() - Hodnota \(double_intensity) mimo intervalu)")
                return "-1"
            } //Chyba
        }
        else {
            print("ERROR: Class BumpForServer, call calculateRating() - Nepodarilo sa Double(\(intensity))")
            return "-1"}
    }
    
    func getAnnotation() -> MGLPointAnnotation {
        let annotation = MGLPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(
            latitude: (self.value(forKey: "latitude") as! NSString).doubleValue,
            longitude: (self.value(forKey: "longitude") as! NSString).doubleValue)
        annotation.title = (self.value(forKey: "text") as! NSString).description
        annotation.subtitle = (self.value(forKey: "created_at") as! NSDate).description
        return annotation
    }
    
    // MARK: - Model meta information
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
}

// MARK: - Entity model methods

extension BumpForServer {
    
    static func all() -> Results<BumpForServer> {
        let realm = try! Realm()
        return realm.objects(BumpForServer.self)
    }
    
    func deleteSelf() throws {
        let realm = try! Realm()
        if let bump = realm.object(ofType: BumpForServer.self, forPrimaryKey: self.id) {
            try realm.write {
                realm.delete(bump)
            }
            print("INFO: Class BumpDetectionAlgorithm, call deleteSelf() - Deleted bump from realm")
        }
    }
    
    func saveMeToInternDb() throws {
        let realm = try! Realm()
        if let bump = realm.object(ofType: BumpForServer.self, forPrimaryKey: self.id) {
            if bump.rating <= self.rating {
                try realm.write {
                    realm.add(self, update: true)
                }
                print("INFO: Class BumpDetectionAlgorithm, call saveMeToInternDb() - Updated bump to realm")
            }
        } else {
            try realm.write {
                realm.add(self, update: false)
            }
             print("INFO: Class BumpDetectionAlgorithm, call saveMeToInternDb() - Saved new bump to realm")
        }
        
    }
}

