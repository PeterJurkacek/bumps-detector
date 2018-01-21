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

class MapViewController: UIViewController, CLLocationManagerDelegate{
    
   
    let locationManager = CLLocationManager()
    var location: CLLocation?
    var updatingLocation = false
    var lastLocationError: Error?
    
    let geocoder = CLGeocoder()
    var placemark: CLPlacemark?
    var performingReverseGeocoding = false
    var lastGeocodingError: Error?
    
    var bumps: [NSManagedObject] = []
    var gpsAccuracy = CLLocationAccuracy()

    var directionsRoute: Route?
    var origin: CLLocationCoordinate2D?
    var bumpDetectionAlgorithm: BumpDetectionAlgorithm?
    
    
    var downloadedItems: [Bump] = [Bump]()
    //var selectedLocation : Bump = Bump()
    @IBOutlet weak var mapView: MGLMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(self.didLongPress(_:)))
        mapView.addGestureRecognizer(tap)
      
        // Allow the map view to display the user's location
        mapView.setUserTrackingMode(MGLUserTrackingMode.follow, animated: true)
        // Set the map view's delegate
        //mapView.delegate = self
        //sync_database()
        bumpDetectionAlgorithm = BumpDetectionAlgorithm()
        bumpDetectionAlgorithm?.bumpAlgorithmDelegate = self
        DispatchQueue.global(qos: .utility).async{
            self.bumpDetectionAlgorithm!.startAccelGyro()
        }
        fetchCoreData(from: "NewBump")
    }
    
    @objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        
        // Converts point where user did a long press to map coordinates
        let point = sender.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        
        // Create a basic point annotation and add it to the map
        let annotation = MGLPointAnnotation()
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
    
    // Calculate route to be used for navigation
    func calculateRoute(from origin: CLLocationCoordinate2D,
                        to destination: CLLocationCoordinate2D,
                        completion: @escaping (Route?, Error?) -> ()) {
        
        let originWaypoint = Waypoint(coordinate: origin, name: "Start")
        
        let destinationWaypoint = Waypoint(coordinate: destination, name: "Finish")
        
        let options = NavigationRouteOptions(waypoints: [originWaypoint, destinationWaypoint], profileIdentifier: .automobileAvoidingTraffic)
        
        _ = Directions.shared.calculate(options) { (waypoints, routes, error) in
            guard let route = routes?.first else { return }
            self.directionsRoute = route
            self.drawRoute(route: self.directionsRoute!)
        }
    }
    
    func drawRoute(route: Route) {
        guard route.coordinateCount > 0 else { return }
        // Convert the route’s coordinates into a polyline.
        var routeCoordinates = route.coordinates!
        let polyline = MGLPolylineFeature(coordinates: &routeCoordinates, count: route.coordinateCount)
        
        // If there's already a route line on the map, reset its shape to the new route
        if let source = mapView.style?.source(withIdentifier: "route-source") as? MGLShapeSource {
            source.shape = polyline
        } else {
            let source = MGLShapeSource(identifier: "route-source", features: [polyline], options: nil)
            let lineStyle = MGLLineStyleLayer(identifier: "route-style", source: source)
            
            mapView.style?.addSource(source)
            mapView.style?.addLayer(lineStyle)
        }
    }
    
    // Always allow callouts to appear when annotations are tapped.
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    func getLocation() {
        
        //checks the app’s authorization status for using location services
        let authStatus = CLLocationManager.authorizationStatus()
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        if authStatus == .denied || authStatus == .restricted {
            showLocationServicesDeniedAlert()
            return
        }
        
        //It tells the location manager that the view controller is its delegate and that you want to receive locations with an accuracy of up to ten meters.
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        
        //Start the location manager.
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print("didFailWithError \(error)")
    }
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.last!
        self.location = newLocation
        print("didUpdateLocations \(newLocation)")
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
    
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
        self.presentNavigation(along: directionsRoute!)
    }
    
    @IBAction func getBump(_ sender: UIButton) {
//        let homeModel = HomeModel()
//        homeModel.delegate = self
//        homeModel.downloadItems()
//        sync_database()
        for bump in bumps {
            print(bump.value(forKey: "latitude"))
            print(bump.value(forKey: "longitude"))
//            let point = MGLPointAnnotation()
            
//            guard let lat = bump.value(forKey: "latitude") as? Double else { return }
//            guard let lon = bump.value(forKey: "longitude") as? Double else { return }
            
//            point.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
//            point.title = String(describing: bump.value(forKey: "text"))
            //point.subtitle = "Intensity" + bump.intensity!

//            self.mapView.addAnnotation(point)
            //self.mapView.setCenter(point.coordinate, animated: true)

        }
//
//        print(downloadedItems)
    }
    
    // Present the navigation view controller
    func presentNavigation(along route: Route) {
        let viewController = NavigationViewController(for: route)
        self.present(viewController, animated: true, completion: nil)
    }
    
    @IBAction func createBump(_ sender: Any) {
        //TODO: Získať údaj o aktuálnej polohe
//        let bump = Bump(
//            latitude : (self.mapView.userLocation?.coordinate.latitude)!,
//            longitude: (self.mapView.userLocation?.coordinate.longitude)!,
//            intensity: 0.5)
        //TODO: Vytvoriť JSON object
        //TODO: Poslať http post request na MySQL
    }

    func addBumpAnotaionToMap(){
        guard mapView.userLocation != nil else { return }
        print("Zaznamenal som výtlk idem kontrolovať, či mám dobrú location\(mapView.userLocation?.location?.horizontalAccuracy)")
        if (mapView.userLocation?.location?.horizontalAccuracy.isLess(than: 100.0))!{
            guard let appDelegate =
                UIApplication.shared.delegate as? AppDelegate else {
                    return
            }
            
            // 1
            let managedContext =
                appDelegate.persistentContainer.viewContext
            
            // 2
            let entity =
                NSEntityDescription.entity(forEntityName: "NewBump",
                                           in: managedContext)!
            
            let bump = NSManagedObject(entity: entity,
                                       insertInto: managedContext)
            
            // 3
            
            bump.setValue(String(describing: mapView.userLocation?.coordinate.latitude), forKeyPath: "latitude")
            bump.setValue(String(describing: mapView.userLocation?.coordinate.longitude), forKeyPath: "longitude")
            bump.setValue("20", forKeyPath: "intensity")
            bump.setValue("0", forKeyPath: "manual")
            bump.setValue(String(describing:Date()), forKeyPath: "created_at")
            bump.setValue("0", forKeyPath: "type")
            bump.setValue("bump", forKeyPath: "text")
            
            print("bump\(bump.value(forKey: "latitude") ?? "")")
            // 4
            do {
                try managedContext.save()
                //people.append(person)
            } catch let error as NSError {
                print("Could not save. \(error), \(error.userInfo)")
            }
            let annotation = MGLPointAnnotation()
            annotation.coordinate = (mapView.userLocation!.coordinate)
            annotation.title = "New Bump"
            annotation.subtitle = "hello"
            mapView.addAnnotation(annotation)
        }
    }
    
    func fetchCoreData(from table: String){
        //1
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        
        let managedContext =
            appDelegate.persistentContainer.viewContext
        
        //2
        let fetchRequest =
            NSFetchRequest<NSManagedObject>(entityName: table)
        
        //3
        do {
            bumps = try managedContext.fetch(fetchRequest)
        } catch let error as NSError {
            print("Could not fetch. \(error), \(error.userInfo)")
        }
    }
}

extension MapViewController: BumpAlgorithmDelegate{
    
    func saveBump(data: double3, date: Date) {
        addBumpAnotaionToMap()
    }
    func saveBumpInfoAs(data: CMAccelerometerData, average: double3, sum: double3, variance: double3, priority: double3, delta: Double ){
    
    }
    
}

extension MapViewController: MGLMapViewDelegate{
    
}

extension MapViewController: ConnectionDelegate{
    func itemsDownloaded(items: [Bump]) {
        print("Stiahol som items mozem s nimi pracovat")
}
    
    
}

