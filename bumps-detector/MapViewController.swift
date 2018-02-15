//
//  ViewController.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 20.8.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import UIKit
import Mapbox
import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation
import CoreLocation
import simd
import CoreData
import CoreMotion
import CFNetwork
import RealmSwift

//Navigacia je inspirovana tutorialom https://www.mapbox.com/help/ios-navigation-sdk/
class MapViewController: UIViewController {
   
    var updatingLocation = false
    
    let geocoder = CLGeocoder()
    var placemark : CLPlacemark?
    var performingReverseGeocoding = false
    var lastGeocodingError: Error?
    var destinationAnnotation = MGLPointAnnotation()
    
    var directionsRoute: Route?
    var bumpDetectionAlgorithm: BumpDetectionAlgorithm?
    let realmService = RealmService()
    
    var bumpsFromServer : Results<BumpFromServer>!
    var bumpsForServer  : Results<BumpForServer>!
    
    var downloadedItems : [Bump] = [Bump]()
    var mapAnnotations  = [MGLAnnotation]()
    //var selectedLocation : Bump = Bump()
    @IBOutlet weak var mapView: MGLMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(mapView)
        
        // Set the map view's delegate
        mapView.delegate = self
        
        // Allow the map to display the user's location
        mapView.showsUserLocation = true
        mapView.setUserTrackingMode(.follow, animated: true)
        
        // Add a gesture recognizer to the map view
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(self.didLongPress(_:)))
        mapView.addGestureRecognizer(tap)
        
        self.bumpsFromServer = realmService.realm.objects(BumpFromServer.self)
        self.bumpsForServer = realmService.realm.objects(BumpForServer.self)
        
        bumpDetectionAlgorithm = BumpDetectionAlgorithm()
        bumpDetectionAlgorithm?.bumpAlgorithmDelegate = self
        bumpDetectionAlgorithm!.startDeviceMotionSensor()
    }
    
    @objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        
        // Converts point where user did a long press to map coordinates
        let point = sender.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        
        // Create a basic point annotation and add it to the map
        let annotation = self.destinationAnnotation
            annotation.coordinate = coordinate
            annotation.title = "Start navigation"
            mapView.addAnnotation(annotation)
            
            calculateRoute(from: (mapView.userLocation!.coordinate), to: annotation.coordinate) { [unowned self] (route, error) in
                if error != nil {
                    // Print an error message
                    print("Error calculating route")
                }
            }
    }
    
    // MARK: - UIAlertActions
    func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(title: "Location Services Disabled",
                                      message: "Please enable location services for this app in Settings.",
                                      preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default,
                                     handler: nil)
        alert.addAction(okAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    @IBAction func showBumpsFromServer(_ sender: UIButton) {
        let networkService = NetworkService()
        networkService.delegate = self
        
        if let userLocation = mapView.userLocation {
            networkService.downloadBumpsFromServer( coordinate: userLocation.coordinate, net: 1 )
        } else { print("Nemam userLocation") }
            
    }
    
    @IBAction func showBumpsForServer(_ sender: Any) {
        DispatchQueue.global().async {
            let realmService = RealmService()
            let results = realmService.realm.objects(BumpForServer.self)
            let annotations = self.getAnnotations(results: results)
            
            DispatchQueue.main.async {
                if let annotations = self.mapView.annotations {
                    self.mapView.removeAnnotations(annotations)
                }
                self.mapView.addAnnotations(annotations)
            }
        }
    }
    
    func getAnnotations<T: Object>(results: Results<T>) -> [MGLAnnotation] {
            var newAnnotations = [MGLAnnotation]()
            for bump in results {
                let annotation = MGLPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(
                    latitude:  (bump.value(forKey: "latitude") as! NSString).doubleValue,
                    longitude: (bump.value(forKey: "longitude") as! NSString).doubleValue)
                annotation.title = String(describing: bump.value(forKey: "type"))
                annotation.subtitle = "hello"
                newAnnotations.append(annotation)
            }
            return newAnnotations
    }
    
    
    // Present the navigation view controller
    func presentNavigation(along route: Route) {
        let viewController = NavigationViewController(for: route)
        self.present(viewController, animated: true, completion: nil)
    }
    
    func addDetectedBumpToInternDB(intensity: String, location: CLLocationCoordinate2D, manual: String, text: String, type: String){
        
        if let location = mapView.userLocation {
            let newBump = BumpForServer(intensity: 0.description,
                                        latitude: location.coordinate.latitude.description,
                                        longitude: location.coordinate.longitude.description,
                                        manual: 0.description,
                                        text: "novy bump",
                                        type: "detectionAlgorithm")
            
            realmService.create(newBump)
        }
    }
}

extension MapViewController: BumpAlgorithmDelegate{
    func saveBumpInfoAs(data: CMAccelerometerData, average: double3, sum: double3, variance: double3, priority: double3, delta: Double) {
    }
    
    func saveBump(data: CustomAccelerometerData) {
        let requiredAccuracy = 100.0
        print("BUMP DETECTED!!!")
        if let userLocation = mapView.userLocation {
            if let location = userLocation.location {
                if (location.horizontalAccuracy.isLess(than: requiredAccuracy)){
                    let annotation = MGLPointAnnotation()
                    annotation.coordinate = CLLocationCoordinate2D(
                        latitude:  location.coordinate.latitude,
                        longitude: location.coordinate.longitude)
                    annotation.title = "Bump"
                    annotation.subtitle = "Bude sa odosielat na server"
                    addDetectedBumpToInternDB(intensity: "-1", location: location.coordinate, manual: "0", text: "Hello New Bump", type: "AutoDetect")
                    self.mapView.addAnnotation(annotation)
                } else { print("Presnost location: \(location.horizontalAccuracy) nie je dostacujuca: \(requiredAccuracy)") }
            } else { print("Neexistuje location") }
        } else { print("Neexistuje userLocation") }
    }
    
}

extension MapViewController: MGLMapViewDelegate{
    
    // Always allow callouts to appear when annotations are tapped.
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    
//    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
//        self.presentNavigation(along: directionsRoute!)
//    }
    
    // Present the navigation view controller when the callout is selected
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
//        var annotations = [MGLAnnotation]()
//        for coordinate in (self.directionsRoute!.coordinates)! {
//            let annotation = MGLPointAnnotation()
//            annotation.coordinate = CLLocationCoordinate2D(
//                latitude: coordinate.latitude,
//                longitude: coordinate.longitude)
//            annotation.title = "TYPE"
//            annotation.subtitle = "BUMP"
//            annotations.append(annotation)
//        }
        
        if let annotations = self.mapView.annotations {
            self.mapView.removeAnnotations(annotations)
        }
        let navigationViewController = NavigationViewController(for: directionsRoute!)
        print("BEFORE\(String(describing: navigationViewController.mapView?.annotations?.count))")
        navigationViewController.mapView?.addAnnotations(self.mapAnnotations)
        //navigationViewController.mapView?.showAnnotations(annotations, animated: true)
        print("AFTER\(String(describing: navigationViewController.mapView?.annotations?.count))")
        self.present(navigationViewController, animated: true, completion: nil)
    }
    
    // Calculate route to be used for navigation
    func calculateRoute(from origin: CLLocationCoordinate2D,
                        to destination: CLLocationCoordinate2D,
                        completion: @escaping (Route?, Error?) -> ()) {
        
        // Coordinate accuracy is the maximum distance away from the waypoint that the route may still be considered viable, measured in meters. Negative values indicate that a indefinite number of meters away from the route and still be considered viable.
        let origin = Waypoint(coordinate: origin, coordinateAccuracy: -1, name: "Start")
        let destination = Waypoint(coordinate: destination, coordinateAccuracy: -1, name: "Finish")
        
        // Specify that the route is intended for automobiles avoiding traffic
        let options = NavigationRouteOptions(waypoints: [origin, destination], profileIdentifier: .automobileAvoidingTraffic)
        options.includesSteps = true
        
        //shapeFormat parameter hovori formate coordinatov, ktore sa ziskaju. .polyline je su kompresovane coordinaty a teda sa prenasa mensie mnozstvo dat ako napr. pri .geoJson
        options.shapeFormat = .polyline
        
        //routeShape parameter hovori o pocte coordinatov z ktorych sa vyresli mapa
        options.routeShapeResolution = .full
        
        options.attributeOptions = .speed
        // Generate the route object and draw it on the map
        Directions.shared.calculate(options) { [unowned self] (waypoints, routes, error) in
            guard let route = routes?.first, error == nil else {
                print(error!.localizedDescription)
                return
            }
            self.directionsRoute = route
            self.drawRoute(route: self.directionsRoute!)
        }
    }
    
    func drawRoute(route: Route) {
        guard route.coordinateCount > 0 else { return }
        // Convert the route’s coordinates into a polyline
        
        var routeCoordinates = route.coordinates!
        _ = BumpNotifyAlgorithm(route: route, delegate: self)
        
        let polyline = MGLPolylineFeature(coordinates: &routeCoordinates, count: route.coordinateCount)
        
        // If there's already a route line on the map, reset its shape to the new route
        if let source = mapView.style?.source(withIdentifier: "route-source") as? MGLShapeSource {
            source.shape = polyline
        } else {
            let source = MGLShapeSource(identifier: "route-source", features: [polyline], options: nil)
            
            // Customize the route line color and width
            let lineStyle = MGLLineStyleLayer(identifier: "route-style", source: source)
            lineStyle.lineColor = MGLStyleValue(rawValue: #colorLiteral(red: 0.5843137503, green: 0.8235294223, blue: 0.4196078479, alpha: 1))
            lineStyle.lineWidth = MGLStyleValue(rawValue: 5)
            
            // Add the source and style layer of the route line to the map
            mapView.style?.addSource(source)
            mapView.style?.addLayer(lineStyle)
        }
    }
}

extension MapViewController: NetworkServiceDelegate{
    func itemsDownloaded() {
        
        DispatchQueue.global().async {
            let realmService = RealmService()
            let results = realmService.realm.objects(BumpFromServer.self)
            if let annotations = self.mapView.annotations {
                self.mapView.removeAnnotations(annotations)
            }
            self.mapAnnotations.removeAll()
            for bump in results {
                let annotation = MGLPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(
                    latitude: bump.value(forKey: "latitude") as! Double,
                    longitude: bump.value(forKey: "longitude") as! Double)
                annotation.title = String(describing: bump.value(forKey: "type"))
                annotation.subtitle = "hello"
                self.mapAnnotations.append(annotation)
            }
            DispatchQueue.main.async {
                self.mapView.addAnnotations(self.mapAnnotations)
            }
        }
        
    }
}

extension MapViewController: BumpNotifyAlgorithmDelegate {
    func notify(annotations: [MGLAnnotation]) {
        //for annotation in annotations {
            //self.directionsRoute?.routeOptions.waypoints.append(Waypoint(coordinate: annotation.coordinate, coordinateAccuracy: 2, name: "Bump"))
            self.mapAnnotations = annotations
            self.mapView.addAnnotations(self.mapAnnotations)
        //}
    }
    
    
}

