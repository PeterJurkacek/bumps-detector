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
//        B[4, 8]
//        x = 1 + 3t
//        y = 2 + 5t
        let constant = calculateConstant(start: start, end: end)
        
        //Vzdialenost medzi dvoma bodmi na mape
        let distanceBetween = start.distance(to: end)
        
        let areaInMeters = 4.0
        
        var t = areaInMeters
        var counter = 0
        var previousCoordinate = start
        var newCoordinates = [CLLocationCoordinate2D]()
        var distance = 0.0
        while true {
            let findedCoordinate = calculateEquationsOfLines(coordinate: start, constant: constant, t: (t/distanceBetween))
            if findedCoordinate.distance(to: end) <= areaInMeters {
                //print("LAST DISTANCE: \(findedCoordinate.distance(to: end)) \(t)/\(distanceBetween)")
                return newCoordinates
            }

            let result = BumpFromServer.findNearby(origin: findedCoordinate, radius: areaInMeters/2, sortAscending: nil)
            for bump in result {
                self.bumps.insert(bump)
            }
            
            if(counter >= 1000){
//                if(counter > 0) {
//                    distance = distance / Double(counter)
//                }
                print("KONSTANTA: \(constant.latitude) \(constant.longitude), DISTANCE: \(distance)")
                print("COUNTER: JE \(counter)")
                return newCoordinates
            }

            distance = findedCoordinate.distance(to: previousCoordinate)
            newCoordinates.append(findedCoordinate)
            t += areaInMeters
            counter += 1
            previousCoordinate = findedCoordinate
        }
    }
    
    func findAllBumpsBetween(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> [BumpFromServer] {
        
        let constant = calculateConstant(start: start, end: end)
        
        //Vzdialenost medzi dvoma bodmi na mape
        let distanceBetween = start.distance(to: end)
        
        let areaInMeters = 4.0
        
        var t = areaInMeters
        var counter = 0
        var previousCoordinate = start
        var bumps = Set<BumpFromServer>()
        var newCoordinates = [CLLocationCoordinate2D]()
        var distance = 0.0
        while true {
            let findedCoordinate = calculateEquationsOfLines(coordinate: start, constant: constant, t: (t/distanceBetween))
            if findedCoordinate.distance(to: end) <= areaInMeters {
                //print("LAST DISTANCE: \(findedCoordinate.distance(to: end)) \(t)/\(distanceBetween)")
                updateMainUI(bumps: bumps)
                return Array<BumpFromServer>(bumps)
            }
            
            let result = BumpFromServer.findNearby(origin: findedCoordinate, radius: areaInMeters/2, sortAscending: nil)
            for bump in result {
                //print(bump)
                bumps.insert(BumpFromServer(value: bump))
            }
            
            if(counter >= 1000){
                print("KONSTANTA: \(constant.latitude) \(constant.longitude), DISTANCE: \(distance)")
                print("COUNTER: JE \(counter)")
                return Array<BumpFromServer>(bumps)
            }
            
            distance = findedCoordinate.distance(to: previousCoordinate)
            newCoordinates.append(findedCoordinate)
            t += areaInMeters
            counter += 1
            previousCoordinate = findedCoordinate
        }
    }
    
    func updateMainUI(bumps: Set<BumpFromServer>){
        var annotations = [MGLAnnotation]()
        for bump in bumps {
            let annotation = MGLPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(
                latitude: bump.value(forKey: "latitude") as! Double,
                longitude: bump.value(forKey: "longitude") as! Double)
            annotation.title = String(describing: bump.value(forKey: "type"))
            annotation.subtitle = "hello"
            annotations.append(annotation)
        }
        DispatchQueue.main.async {
            self.delegate.notify(annotations: annotations)
        }
    }
    
    func calculateConstant(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        
        let newLatitude = (end.latitude - start.latitude)//.rounded(toPlaces: 10)
        let newLongitude = (end.longitude - start.longitude)//.rounded(toPlaces: 10)
        
        return CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)
    }
    
    func calculateEquationsOfLines(coordinate: CLLocationCoordinate2D, constant: CLLocationCoordinate2D, t: Double) -> CLLocationCoordinate2D {
        
        let newLatitude = coordinate.latitude + constant.latitude * t
        let newLongitude = coordinate.longitude + constant.longitude * t
        
        return CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude)
    }
    
    func concurrentFindAllBumpsOnTheRoute(array: [CLLocationCoordinate2D], numThreads: Int = 5) -> [BumpFromServer] {
        var best = [BumpFromServer]()  // 1
        let size = array.count
        DispatchQueue.concurrentPerform(iterations: numThreads, execute: { (i) in
            // divide up the work
            let batchSize = size / numThreads  // 2
            
            let start = i * batchSize
            let end: Int
            if i == numThreads - 1 {  // 4
                // have the last thread finish it off in case our array is an odd size
                end = array.count - 1
            } else {
                end = (i + 1) * batchSize  // 3
            }
            
            // do our part
            let batchBest = findBumpsForChunk(start, end, array)
            best.append(contentsOf: batchBest)  // 5
        })
        return best  // 6
    }
    
    func findBumpsForChunk(_ start: Int, _ end: Int, _ array: [CLLocationCoordinate2D]) -> [BumpFromServer]{
        var best = [BumpFromServer]()
        for i in start..<end {
            if(i < array.count-1){
                let A = array[i]
                let B = array[i+1]
                best.append(contentsOf: self.findAllBumpsBetween(start: A, end: B))
            }
        }
        return best
    }
    
    func startAlgorithm() {
        DispatchQueue.global().async {
            if let routeCoordinate = self.route?.coordinates {
                
                var findedBumps = [BumpFromServer]()
                //findedBumps.append(contentsOf: self.findBumpsForChunk(0, routeCoordinate.count, routeCoordinate))
                findedBumps = self.findBumpsForChunk(0, routeCoordinate.count, routeCoordinate)
                print("routeCoordinate.count: \(routeCoordinate.count)")
                print("findedBumps: \(findedBumps.count)")
                
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

