//
//  BumpNotifyAlgorithm.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 23.12.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import Foundation
import GeoQueries
import CoreLocation
import MapboxDirections
import Mapbox

protocol BumpNotifyAlgorithmDelegate {
    func notify(annotations: [MGLAnnotation])
}

class BumpNotifyAlgorithm {
    
    var delegate: BumpNotifyAlgorithmDelegate!
    
    var date: Date?
    var timer: Timer?
    var coordinates = [CLLocationCoordinate2D]()
    var bumps = Set<BumpFromServer>()
    var route: Route!
    
    //MARK: Initializers
    init(route: Route, delegate: BumpNotifyAlgorithmDelegate){
        self.route = route
        self.delegate = delegate
        self.startAlgorithm()
    }
    
    //MARK: Bump detection algorithms
    func getAllCoordinatesBetween(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> [CLLocationCoordinate2D]{
//        A[1, 2]
//        B[2, 4]
//        x = 1 + 1t
//        y = 2 + 2t
        let constant = calculateConstant(start: start, end: end)
        
        //Vzdialenost medzi dvoma bodmi na mape
        let distanceBetween = start.distance(to: end)
        
        
        var t = 0.0
        var counter = 0
        var previousCoordinate = start
        var newCoordinates = [CLLocationCoordinate2D]()
        var distance = 0.0
        while true {
            let findedCoordinate = calculate(coordinate: start, constant: constant, t: (t/distanceBetween))
//            if findedCoordinate.latitude == end.latitude && findedCoordinate.longitude == end.longitude {
//                if(counter > 0) {
//                    distance = distance / Double(counter)
//                }
//                print("KONSTANTA: \(constant.latitude) \(constant.longitude), DISTANCE: \(distance)")
//                return newCoordinates
//            }
            if findedCoordinate.distance(to: end) <= 4 {
                if(counter > 0) {
                    distance = distance / Double(counter)
                }
                print("KONSTANTA: \(constant.latitude) \(constant.longitude), DISTANCE: \(distance)")
                return newCoordinates
            }

            do {
                let result = try RealmService().realm.findNearby(type: BumpFromServer.self, origin: findedCoordinate, radius: 2, sortAscending: nil)
                for bump in result {
                    self.bumps.insert(bump)
                }
            } catch {
                print("ERROR: RealmService().realm.findNearby")
            }
            newCoordinates.append(findedCoordinate)
            t += 4
            counter += 1
            if(counter >= 1000){
                if(counter > 0) {
                    distance = distance / Double(counter)
                }
                print("KONSTANTA: \(constant.latitude) \(constant.longitude), DISTANCE: \(distance)")
                print("COUNTER: JE \(counter)")
                return newCoordinates
            }

            distance = distance + findedCoordinate.distance(to: previousCoordinate)
            //print("DISTANCE: \(distance)")
//            print("finded  : \(findedCoordinate)")
//            print("previous: \(previousCoordinate)")
            previousCoordinate = findedCoordinate
        }
    }
    
    func calculateConstant(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        
        let newLatitude = (end.latitude - start.latitude)//.rounded(toPlaces: 10)
        let newLongitude = (end.longitude - start.longitude)//.rounded(toPlaces: 10)
        
        return CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)
    }
    
    func calculate(coordinate: CLLocationCoordinate2D, constant: CLLocationCoordinate2D, t: Double) -> CLLocationCoordinate2D {
        
        let newLatitude = coordinate.latitude + constant.latitude * t
        let newLongitude = coordinate.longitude + constant.longitude * t
        
        return CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)
    }
    
    func startAlgorithm() {
        DispatchQueue.global().async {
            if let routeCoordinate = self.route?.coordinates {
                
                var generatedCoordinate = [CLLocationCoordinate2D]()
                
                for i in 0..<routeCoordinate.count {
//                    A[1, 2]
//                    B[2, 4]
//
//                    x = 1 + 1t
//                    y = 2 + 2t
                    
                    if(i < routeCoordinate.count-1){
                        let A = routeCoordinate[i]
                        let B = routeCoordinate[i+1]
                        generatedCoordinate.append(contentsOf: self.getAllCoordinatesBetween(start: A, end: B))
                    }
                    
                }
                
                print("routeCoordinate.count: \(routeCoordinate.count)")
                print("generatedCoordinate.coutn: \(generatedCoordinate.count)")
                
                var annotations = [MGLAnnotation]()
                for bump in self.bumps {
                    let annotation = MGLPointAnnotation()
                    annotation.coordinate = CLLocationCoordinate2D(
                        latitude: bump.value(forKey: "latitude") as! Double,
                        longitude: bump.value(forKey: "longitude") as! Double)
                    annotation.title = String(describing: bump.value(forKey: "type"))
                    annotation.subtitle = "hello"
                    annotations.append(annotation)
                }
                
//                var annotations = [MGLAnnotation]()
//                for bump in generatedCoordinate {
//                    let annotation = MGLPointAnnotation()
//                    annotation.coordinate = CLLocationCoordinate2D(
//                        latitude: bump.latitude,
//                        longitude: bump.longitude)
//                    annotation.subtitle = "hello"
//                    annotations.append(annotation)
//                }


                DispatchQueue.main.async {
                    self.delegate.notify(annotations: annotations)
                }
            }
        }
    }
    
}

extension Double {
    func rounded(toPlaces places:Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

