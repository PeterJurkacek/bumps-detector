//
//  RoutePointChecker.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 6.5.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//
//  Rekurzia bola inspirovana https://github.com/rmnblm/mapbox-ios-examples/blob/1e66e82f807b3badc75538a4b78d106b0533359c/src/Examples/PathSelectionViewController.swift
import Foundation
import MapboxDirections
import Mapbox

protocol RoutePointCheckerDelegate : class {
    func notifyMain(bumpsOnRouteAnnotations: [MGLPointAnnotation])
}

class RoutePointChecker: NSObject {
    
    weak var delegate: RoutePointCheckerDelegate?
    let routePointCheckerQueue = DispatchQueue(label: "RoutePointCheckerQueue")
    var routes = [Route]()
    var generatedPoint: Int = 0
    var findedBumps = Set<BumpFromServer>()
    var radius = 5.0
    var howManyPoints = 0
    var done = 0 {
        didSet {
            print("done: \(done), howManyLines: \(howManyPoints), generated\(generatedPoint)")
            if done == howManyPoints {
                guard let delegate = self.delegate else { return }
                DispatchQueue.main.async {
                    var annotations = [MGLPointAnnotation]()
                    for bump in self.findedBumps {
                        annotations.append(bump.getAnnotation())
                    }
                    delegate.notifyMain(bumpsOnRouteAnnotations: annotations)
                }
            }
        }
    }
    
    init(routes: [Route], delegate: RoutePointCheckerDelegate) {
        super.init()
        self.delegate = delegate
        self.routes.append(contentsOf: routes)
        for route in routes {
            guard let coordinates = route.coordinates else { continue }
            howManyPoints += (coordinates.count)
        }
        self.startAlgorithm()
    }
    
    private func startAlgorithm(){
        for route in self.routes {
            guard let coordinates = route.coordinates else { continue }
            for (index, _) in coordinates.enumerated() {
                if index != 0 {
                    let from = coordinates[index-1]
                    let to = coordinates[index]
                    self.split(from, to)
                }
                done+=1
            }
        }
    }
    
    private func split(_ from: CLLocationCoordinate2D, _ to: CLLocationCoordinate2D) {
        if distance(from, to) > 2*radius { // THRESHOLD is radius in square meter
            let middle = mid(from, to)
            isBumpOnThis(coordinate: middle)
            split(from, middle)
            split(middle, to)
        }
        
        isBumpOnThis(coordinate: from)
        isBumpOnThis(coordinate: to)
    }
    
    private func distance(_ from: CLLocationCoordinate2D, _ to: CLLocationCoordinate2D) -> Double {
        let fromLoc = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLoc = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLoc.distance(from: toLoc)
    }
    
    private func mid(_ from: CLLocationCoordinate2D, _ to: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        let latitude = (from.latitude + to.latitude) / 2
        let longitude = (from.longitude + to.longitude) / 2
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    private func isBumpOnThis(coordinate: CLLocationCoordinate2D) {
        DispatchQueue.global().async {
            // Unowned reference to self to prevent retain cycle
            [unowned self] in
            self.generatedPoint+=1
            let realmService = RealmService()
            let result = realmService.findNearby(type: BumpFromServer.self, origin: coordinate, radius: self.radius, sortAscending: true)
            for bump in result {
                //print(bump)
                self.findedBumps.insert(BumpFromServer(value: bump))
            }
        }
    }
}
