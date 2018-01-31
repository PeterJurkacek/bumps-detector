//
//  RealmService.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 27.1.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import RealmSwift

class RealmService {
    
    var realm: Realm
    
    init() {
       realm = try! Realm()
    }
    
    func create<T: Object>(_ object: T){
        do {
            try realm.write {
                realm.add(object)
            }
        } catch {
            print("ERROR: \(error)")
        }
    }
    
    func createOrUpdate<T: Object>(_ object: T){
        do {
            try realm.write {
                realm.add(object, update: true)
            }
        } catch {
            print("ERROR: \(error)")
        }
    }
    
    func update<T: Object>(_ object: T, with dictionary: [String: Any?]){
        do {
            try realm.write {
                for (key, value) in dictionary {
                    object.setValue(value, forKey: key)
                }
            }
        } catch {
            print("ERROR: \(error)")
        }
    }
    
    func delete<T: Object>(_ object: T){
        do {
            try realm.write {
                realm.delete(object)
            }
        } catch {
            print("ERROR: \(error)")
        }
    }
}
