//
//  AnnotationsViewController.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 3.4.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import UIKit
import RealmSwift
import Mapbox

protocol RealmNotificationDelegate : class{
    func updateBumpsFromServerAnnotations(annotations: [MGLPointAnnotation])
    func updateBumpsForServerAnnotations(annotations: [MGLPointAnnotation])
}

//This class handle annotations on map
class RealmNotification: NSObject {

    //Ream token - https://realm.io/docs/swift/latest#notifications
    var bumpsFromServerNotificationToken: NotificationToken? = nil
    var bumpsForServerNotificationToken: NotificationToken? = nil
    var detectedBumpToken: NotificationToken? = nil
    weak var delegate: RealmNotificationDelegate?
    var bumpsFromServerResult: Results<BumpFromServer>?
    var bumpsForServerResult: Results<BumpForServer>?
    
    init(delegate: RealmNotificationDelegate) {
        super.init()
        let realm = try! Realm()
        self.delegate = delegate
            
        // Observe Results Notifications
        
        bumpsFromServerResult = realm.objects(BumpFromServer.self)
        // Observe Results Notifications
        bumpsFromServerNotificationToken = bumpsFromServerResult?.observe({ [weak self] (changes: RealmCollectionChange<Results<BumpFromServer>>) in
            guard let delegate = self?.delegate else {
                print("WARNING Nepriradil si delegata!!!")
                return
            }
            
            guard let result = self?.bumpsFromServerResult else {
                print("WARNING: !!!")
                return
            }
            
            var annotations = [MGLPointAnnotation]()
            
            for bump in result {
                let annotation = MGLPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(
                    latitude: bump.value(forKey: "latitude") as! Double,
                    longitude: bump.value(forKey: "longitude") as! Double)
                annotation.title = (bump.value(forKey: "info") as! NSString).description
                annotation.subtitle = (bump.value(forKey: "last_modified") as! NSString).description
                annotations.append(annotation)
            }
            
            delegate.updateBumpsFromServerAnnotations(annotations: annotations)
        })
        
        bumpsForServerResult = realm.objects(BumpForServer.self)
        // Observe Results Notifications
        bumpsForServerNotificationToken = bumpsForServerResult?.observe({ [weak self] (changes: RealmCollectionChange<Results<BumpForServer>>) in
            guard let delegate = self?.delegate else {
                print("WARNING Nepriradil si delegata!!!")
                return
            }
            
            guard let result = self?.bumpsForServerResult else {
                print("WARNING: !!!")
                return
            }
            
            var annotations = [MGLPointAnnotation]()
            
            for bump in result {
                let annotation = MGLPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(
                    latitude: (bump.value(forKey: "latitude") as! NSString).doubleValue,
                    longitude: (bump.value(forKey: "longitude") as! NSString).doubleValue)
                annotation.title = (bump.value(forKey: "text") as! NSString).description
                annotation.subtitle = (bump.value(forKey: "created_at") as! NSDate).description
                annotations.append(annotation)
            }
            
            delegate.updateBumpsForServerAnnotations(annotations: annotations)
        })
    }
    
    deinit {
        bumpsFromServerNotificationToken?.invalidate()
        bumpsForServerNotificationToken?.invalidate()
    }
    
}
