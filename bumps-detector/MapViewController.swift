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
class MapViewController: UIViewController, CLLocationManagerDelegate {
   
    var updatingLocation = false
    
    let geocoder = CLGeocoder()
    var placemark : CLPlacemark?
    var performingReverseGeocoding = false
    var lastGeocodingError: Error?
    var destinationAnnotation = MGLPointAnnotation()
    var navigationViewController: NavigationViewController?
    
    var currentRoute: Route?
    var bumpDetectionAlgorithm: BumpDetectionAlgorithm?
    var bumpNotifyAlgorithm: BumpNotifyAlgorithm?
    var locationManager = CLLocationManager()
     var alertController: UIAlertController!
    
    var bumpsFromServer : Results<BumpFromServer>!
    var bumpsForServer  : Results<BumpForServer>!
    
    var downloadedItems : [Bump] = [Bump]()
    var mapAnnotations  = [MGLAnnotation]()
    //var selectedLocation : Bump = Bump()
    @IBOutlet weak var mapView: NavigationMapView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        view.addSubview(mapView)
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        automaticallyAdjustsScrollViewInsets = false
        mapView.delegate = self
        mapView.navigationMapDelegate = self

        
        bumpDetectionAlgorithm = BumpDetectionAlgorithm()
        bumpDetectionAlgorithm?.bumpAlgorithmDelegate = self
        bumpDetectionAlgorithm!.startDeviceMotionSensor()
        
        // Add a gesture recognizer to the map view
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(self.didLongPress(_:)))
        mapView.addGestureRecognizer(tap)
        
    }

    @objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        
        if let annotations = self.mapView.annotations {
            self.mapView.removeAnnotations(annotations)
        }
        
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
    
    @IBAction func showBumpsFromServer() {
        let networkService = NetworkService()
        networkService.delegate = self
        
        if let userLocation = mapView.userLocation {
            networkService.downloadBumpsFromServer( coordinate: userLocation.coordinate, net: 1 )
        } else { print("Nemam userLocation") }
            
    }
    
    @IBAction func showBumpsForServer(_ sender: Any) {
        DispatchQueue.global().async {
            let results = BumpForServer.all()
            let annotations = self.getAnnotations(results: results)
            
            DispatchQueue.main.async {
                if let annotations = self.mapView.annotations {
                    self.mapView.removeAnnotations(annotations)
                }
                self.mapView.addAnnotations(annotations)
            }
        }
    }
    
    @IBAction func sendBumpToServer(_ sender: UIButton) {
        
        DispatchQueue.global().async {
            let networkService = NetworkService()
            networkService.delegate = self
            networkService.sendAllBumpsToServer()
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
            do {
                try newBump.saveMeToInternDb()
            }
            catch {
                print("ERROR: class MapViewController, call addDetectedBumpToInternDB - Nepodarilo sa mi uloz \(newBump) do inernej DB")
            }
        }
    }
}

extension MapViewController: BumpAlgorithmDelegate{
    func saveExportData(data: DataForExport) {
        
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
                    addDetectedBumpToInternDB(intensity: "-1", location: location.coordinate, manual: "0", text: "Hello New Bump", type: "0")
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
    
    func mapView(_ mapView: MGLMapView, didUpdate userLocation: MGLUserLocation?) {
        self.bumpDetectionAlgorithm?.userLocation = userLocation?.location
    }

    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        // Allow the map to display the user's location
        mapView.showsUserLocation = true
        mapView.setUserTrackingMode(.followWithHeading, animated: true)
    }
    
//    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
//        // Try to reuse the existing ‘pisa’ annotation image, if it exists.
//        var annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: "pothole")
//        
//        if annotationImage == nil {
//            // Leaning Tower of Pisa by Stefan Spieler from the Noun Project.
//            var image = UIImage(named: "pothole")!
//            let size = CGSize(width: 50, height: 50)
//            UIGraphicsBeginImageContext(size)
//            image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
//            // The anchor point of an annotation is currently always the center. To
//            // shift the anchor point to the bottom of the annotation, the image
//            // asset includes transparent bottom padding equal to the original image
//            // height.
//            //
//            // To make this padding non-interactive, we create another image object
//            // with a custom alignment rect that excludes the padding.
//            image = image.withAlignmentRectInsets(UIEdgeInsets(top: 0, left: 0, bottom: image.size.height/2, right: 0))
//            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
//            UIGraphicsEndImageContext()
//            // Initialize the ‘pisa’ annotation image with the UIImage we just loaded.
//            annotationImage = MGLAnnotationImage(image: resizedImage!, reuseIdentifier: "pothole")
//        }
//        
//        return annotationImage
//    }
    
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
        self.navigationViewController = NavigationViewController(for: currentRoute!)
        if let navigationViewController = self.navigationViewController {
            navigationViewController.navigationDelegate = self
            self.present(navigationViewController, animated: true, completion: nil)
            print("AFTER NAVIGATION VIEW")
        }
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
        
        //routeShape parameter hovori o pocte coordinatov z ktorych sa vykresli mapa
        options.routeShapeResolution = .full
        
        options.attributeOptions = .speed
        // Generate the route object and draw it on the map
        Directions.shared.calculate(options) { [unowned self] (waypoints, routes, error) in
            guard let route = routes?.first, error == nil else {
                print(error!.localizedDescription)
                return
            }
            self.currentRoute = route
            //self.drawRoute(route: self.directionsRoute!)
            self.mapView.showRoute(route)
            self.bumpNotifyAlgorithm = BumpNotifyAlgorithm(route: route, delegate: self)
        }
    }
}

extension MapViewController: NetworkServiceDelegate{
    func itemsDownloaded() {
        
        DispatchQueue.global().async {
            
            if let annotations = self.mapView.annotations {
                self.mapView.removeAnnotations(annotations)
            }
            self.mapAnnotations.removeAll()
            
            let results = BumpFromServer.all()
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
        self.mapView.addAnnotations(annotations)
    }
    
    
}

//MARK: - NavigationMapViewDelegate
extension MapViewController: NavigationMapViewDelegate {
    
    func navigationMapView(_ mapView: NavigationMapView, didSelect route: Route) {
        currentRoute = route
    }
    
    // To use these delegate methods, set the `VoiceControllerDelegate` on your `VoiceController`.
    //
    // Called when there is an error with speaking a voice instruction.
    func voiceController(_ voiceController: RouteVoiceController, spokenInstructionsDidFailWith error: Error) {
        print(error.localizedDescription)
    }
}

//MARK: NavigationViewControllerDelegate
extension MapViewController: NavigationViewControllerDelegate {
    // By default, when the user arrives at a waypoint, the next leg starts immediately.
    // If you implement this method, return true to preserve this behavior.
    // Return false to remain on the current leg, for example to allow the user to provide input.
    // If you return false, you must manually advance to the next leg. See the example above in `confirmationControllerDidConfirm(_:)`.
    
    
    // Called when the user hits the `Cancel` button.
    // If implemented, you are responsible for also dismissing the UI.
    func navigationViewControllerDidCancelNavigation(_ navigationViewController: NavigationViewController) {
        print("The user has exited")
        self.mapView.removeRoute()
        navigationViewController.dismiss(animated: true, completion: nil)
    }
}
