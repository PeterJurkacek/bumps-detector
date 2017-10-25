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

class ViewController: UIViewController, MGLMapViewDelegate, HomeModelProtocol, CLLocationManagerDelegate{
    
    func itemsDownloaded(items: [Bump]) {
        downloadedItems = items
    }
    
   
    let locationManager = CLLocationManager()
    var location: CLLocation?
    var updatingLocation = false
    var lastLocationError: Error?
    
    let geocoder = CLGeocoder()
    var placemark: CLPlacemark?
    var performingReverseGeocoding = false
    var lastGeocodingError: Error?

    var directionsRoute: Route?
    var origin: CLLocationCoordinate2D?
    
    var downloadedItems: [Bump] = [Bump]()
    var selectedLocation : Bump = Bump()
    @IBOutlet weak var mapView: MGLMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(self.didLongPress(_:)))
        mapView.addGestureRecognizer(tap)
      
        // Allow the map view to display the user's location
        mapView.setUserTrackingMode(MGLUserTrackingMode.follow, animated: true)
        // Set the map view's delegate
        mapView.delegate = self
        sync_database()
    }
    
    func sync_database(){
        // 1
        let queue = DispatchQueue.global()
        // 2
        queue.async {
            var request = URLRequest(url: URL(string: "http://vytlky.fiit.stuba.sk//sync_bump.php")!)
            request.httpMethod = "POST"
            let postString = "date=2017-10-13+14%3A32%3A31&latitude=48.1607117&longitude=17.0958196&net=1"
            request.httpBody = postString.data(using: .utf8)
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {                                                 // check for fundamental networking error
                    print("error=\(error)")
                    return
                }
                
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                    print("response = \(response)")
                    
                }
                
                let responseString = String(data: data, encoding: .utf8)
                if let jsonDictionary = self.parse(json: responseString!) {
                    print("Dictionary \(jsonDictionary)")
                    self.downloadedItems = self.parseDic(dictionary: jsonDictionary)
                }
                //print("responseString = \(responseString)")
            }
            task.resume()
        }
    }
    
    func parseDic(dictionary: [String: Any]) -> [Bump]{
        // 1.
        //Firstthereisabitofdefensiveprogrammingtomakesurethedictionaryhasa key named results that contains an array.
        //It probably will, but better safe than sorry.
        guard let array = dictionary["bumps"] as? [Any] else {
            print("Expected 'results' array")
            return []
        }
        var bumps: [Bump] = []
        // 2.
        //Onceitissatisfiedthatarrayexists,themethodusesaforinlooptolookat each of the array’s elements in turn.
        for bumpDict in array {
            // 3.
            //Eachoftheelementsfromthearrayisanotherdictionary.
            //Asmallwrinkle:the type of resultDict isn’t Dictionary as we’d like it to be, but Any, because the contents of the array could in theory be anything.
            //To make sure these objects really do represent dictionaries, you have to cast them to the right type first. You’re using the optional cast as? here as another defensive measure. In theory it’s possible resultDict doesn’t actually hold a [String: Any] dictionary and then you don’t want to continue.
            if let bumpDict = bumpDict as? [String: Any] {
                // 4.
                //Foreachofthedictionaries,youprintoutthevalueofitswrapperTypeandkind fields.
                //Indexing a dictionary always gives you an optional, which is why you’re using if let to unwrap these two values. And because the dictionary only contains values of type Any, you also cast to the more useful String.
                if let latitude = bumpDict["latitude"] as? String,
                    let longitude = bumpDict["longitude"] as? String {
                    print("latitude: \(latitude), longitude: \(longitude)")
                    
                    bumps.append(Bump(latitude: Double(latitude)!, longitude: Double(longitude)!))
                }
            }
        }
        return bumps
    }
    
    func parse(json: String) -> [String: Any]? {
        
        //guard let works like if let, it unwraps the optionals for you. But if unwrapping fails, i.e. if json.data(...) returns nil, the guard’s else block is executed and you
        guard let data = json.data(using: .utf8, allowLossyConversion: false)
            else { return nil }
        do {
            //We are using the JSONSerialization object here to convert the JSON search results to a Dictionary.
            //Just to be sure, you’re using the as? cast to check that the object returned by JSONSerialization is truly a Dictionary.
            return try JSONSerialization.jsonObject(
                with: data, options: []) as? [String: Any]
        } catch {
            //return nil to indicate that parse(json) failed. This “should” never happen in our app, but it’s good to be vigilant about this kind of thing. (Never say never!)
            print("JSON Error: \(error)")
            return nil
        }
        
    }
    
    func didLongPress(_ sender: UILongPressGestureRecognizer) {
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
        for bump in downloadedItems {
            let point = MGLPointAnnotation()
            point.coordinate = CLLocationCoordinate2D(latitude: Double(bump.latitude!), longitude: Double(bump.longitude!))
            point.title = "Bump"
            //point.subtitle = "Intensity" + bump.intensity!
            
            self.mapView.addAnnotation(point)
            self.mapView.setCenter(point.coordinate, animated: true)
           
        }
        
        print(downloadedItems)
    }


    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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

}

