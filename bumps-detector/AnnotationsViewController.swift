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

protocol AnnotationsViewControllerDelegate {
    func updateBumpsFromServerAnnotations(annotations: [MGLPointAnnotation])
    func updateBumpsForServerAnnotations(annotations: [MGLPointAnnotation])
}

//This class handle annotations on map
class AnnotationsViewController: UIViewController {

    //Ream token - https://realm.io/docs/swift/latest#notifications
    var bumpsFromServerNotificationToken: NotificationToken? = nil
    var bumpsForServerNotificationToken: NotificationToken? = nil
    var delegate: AnnotationsViewControllerDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let realm = try! Realm()
        let bumpsFromServerResult = realm.objects(BumpFromServer.self)
        // Observe Results Notifications
        bumpsFromServerNotificationToken = bumpsFromServerResult.observe({ [weak self] (changes: RealmCollectionChange) in
            guard let delegate = self?.delegate else {
                print("WARNING Nepriradil si delegata!!!")
                return
            }
            
            var annotations = [MGLPointAnnotation]()
            
            for bump in bumpsFromServerResult {
                let annotation = MGLPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(
                    latitude: bump.value(forKey: "latitude") as! Double,
                    longitude: bump.value(forKey: "longitude") as! Double)
                annotation.title = String(describing: bump.value(forKey: "info"))
                annotation.subtitle = String(describing: bump.value(forKey: "last_modified"))
                annotations.append(annotation)
            }
            
            delegate.updateBumpsFromServerAnnotations(annotations: annotations)
        })
        
        let bumpsForServerResult = realm.objects(BumpForServer.self)
        // Observe Results Notifications
        bumpsForServerNotificationToken = bumpsForServerResult.observe({ [weak self] (changes: RealmCollectionChange) in
            guard let delegate = self?.delegate else {
                print("WARNING Nepriradil si delegata!!!")
                return
            }
            
            var annotations = [MGLPointAnnotation]()
            
            for bump in bumpsForServerResult {
                let annotation = MGLPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(
                    latitude: bump.value(forKey: "latitude") as! Double,
                    longitude: bump.value(forKey: "longitude") as! Double)
                annotation.title = String(describing: bump.value(forKey: "text"))
                annotation.subtitle = String(describing: bump.value(forKey: "created_at"))
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
