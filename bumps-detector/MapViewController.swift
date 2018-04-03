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
import MapboxGeocoder
import CoreLocation
import simd
import CoreData
import CoreMotion
import CFNetwork
import RealmSwift
import Foundation
import MapKit
import Turf

//Navigacia je inspirovana tutorialom https://www.mapbox.com/help/ios-navigation-sdk/
class MapViewController: UIViewController, CLLocationManagerDelegate {
    var destinationAnnotation = MGLPointAnnotation()
    var navigationViewController: NavigationViewController?
    var sendDetectedBumpToServerTimer: Timer?
    var notificationToken: NotificationToken? = nil
    
    var currentRoute: Route?
    var bumpDetectionAlgorithm: BumpDetectionAlgorithm?
    var bumpNotifyAlgorithm: BumpNotifyAlgorithm?
    //var locationManager = CLLocationManager()

    
    var bumpsFromServerAnnotations = [MGLPointAnnotation]()
    var bumpsForServerAnnotations = [MGLPointAnnotation]()
    
    var downloadedItems : [Bump] = [Bump]()
    var mapAnnotations  = [MGLAnnotation]()
    //var selectedLocation : Bump = Bump()
    var geocodingDataTask: URLSessionDataTask?
    var geocoder: GeocodingService!
    var mapStyles = Dictionary<String, MGLStyle>()
    
    let blackView = UIView()
    @IBOutlet weak var mapView: NavigationMapView!
    @IBOutlet weak var overviewButton: Button!
    @IBOutlet weak var reportButton: Button!
    @IBOutlet weak var recenterButton: ResumeButton!
    
    var isInOverviewMode = false

    @IBAction func recenter(_ sender: AnyObject) {
        mapView.setUserTrackingMode(.followWithHeading, animated: true)
        isInOverviewMode = false
    }
    
    @IBAction func handleMapViewStyle(_ sender: Any) {
    
        let alertController = UIAlertController(title: "Zobrazenie máp", message: "Môžete si z viacerých zobrazení pre mapu.", preferredStyle: .actionSheet)
        
        let sateliteStyleAction = UIAlertAction(title: "Satelitné", style: .default) { (action) in
            self.showMapViewStyle(style: "1")
        }
        
        
        let streetStyleAction = UIAlertAction(title: "Obyčajné", style: .default) { (action) in
            self.showMapViewStyle(style: "2")
        }
        
        let cancelAction = UIAlertAction(title: "Zrušiť", style: .cancel) { (action) in
        }
        
        alertController.addAction(sateliteStyleAction)
        alertController.addAction(streetStyleAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
        
    }
    
    func showMapViewStyle(style: String?){
        if let styleIndetifier = style {
            switch(styleIndetifier){
                case "1": self.mapView.styleURL = MGLStyle.satelliteStreetsStyleURL()
                case "2": self.mapView.styleURL = MGLStyle.streetsStyleURL()
                default: self.mapView.styleURL = MGLStyle.streetsStyleURL()
            }
        }
        
    }
    
    //Odiali pohlad na mapu tak aby bola vidiet cela cesta
    @IBAction func toggleOverview(_ sender: Any) {
        updateVisibleBounds()
        isInOverviewMode = true
    }

    func updateVisibleBounds() {
        guard let userLocation = mapView.userLocation?.coordinate else { return }

        let overviewContentInset = UIEdgeInsets(top: 65, left: 20, bottom: 55, right: 20)
        guard let route = self.currentRoute else { return }
        
        let slicedLine = Polyline(route.coordinates!).sliced(from: userLocation, to: route.coordinates!.last).coordinates
        
        let line = MGLPolyline(coordinates: slicedLine, count: UInt(slicedLine.count))

        let camera = mapView.camera
        camera.pitch = 0
        camera.heading = 0
        mapView.camera = camera

        // Don't keep zooming in
        guard line.overlayBounds.ne.distance(to: line.overlayBounds.sw) > 200 else { return }

        mapView.setVisibleCoordinateBounds(line.overlayBounds, edgePadding: overviewContentInset, animated: true)
    }
    
    @IBAction func report(_ sender: Any) {
//        guard let parent = parent else { return }
//
//        let controller = FeedbackViewController.loadFromStoryboard()
//        let feedbackId = routeController.recordFeedback()
//
//        controller.sendFeedbackHandler = { [weak self] (item) in
//            guard let strongSelf = self else { return }
//            strongSelf.delegate?.mapViewController(strongSelf, didSend: feedbackId, feedbackType: item.feedbackType)
//            strongSelf.routeController.updateFeedback(feedbackId: feedbackId, type: item.feedbackType, description: nil)
//            strongSelf.dismiss(animated: true) {
//                DialogViewController.present(on: parent)
//            }
//        }
//
//        controller.dismissFeedbackHandler = { [weak self] in
//            guard let strongSelf = self else { return }
//            strongSelf.delegate?.mapViewControllerDidCancelFeedback(strongSelf)
//            strongSelf.routeController.cancelFeedback(feedbackId: feedbackId)
//            strongSelf.dismiss(animated: true, completion: nil)
//        }
//
//        parent.present(controller, animated: true, completion: nil)
//        delegate?.mapViewControllerDidOpenFeedback(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mapView.styleURL = MGLStyle.lightStyleURL()
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.tintColor = .darkGray

        mapView.setCenter(
            CLLocationCoordinate2D(latitude: 37.753574, longitude: -122.447303),
            zoomLevel: 10,
            animated: false)
        view.addSubview(mapView)

        //locationManager.delegate = self
        //locationManager.requestWhenInUseAuthorization()

        automaticallyAdjustsScrollViewInsets = false
        mapView.delegate = self
        mapView.navigationMapDelegate = self
        isInOverviewMode = false

        bumpDetectionAlgorithm = BumpDetectionAlgorithm()
        bumpDetectionAlgorithm?.bumpAlgorithmDelegate = self
        bumpDetectionAlgorithm!.startDeviceMotionSensor()

        sendDetectedBumpToServerTimer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(sendAllBumpsToServer), userInfo: nil, repeats: true)

        // Add a gesture recognizer to the map view
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(self.didLongPress(_:)))
        mapView.addGestureRecognizer(tap)
        geocoder = AppleMapSearch()

    }
    
    @IBAction func filterOptions() {
       let alertController = UIAlertController(title: "Filtrovať výtlky na mape?", message: "Výtlky na mape môžete filtrovať podľa ich veľkosti.", preferredStyle: .actionSheet)
        
        let maleAction = UIAlertAction(title: "Malé", style: .default) { (action) in
            self.filterBumps(rating: "1")
        }
        
        
        let stredneAction = UIAlertAction(title: "Stredné", style: .default) { (action) in
            self.filterBumps(rating: "2")
        }
        
        let velkeAction = UIAlertAction(title: "Veľké", style: .default) { (action) in
            self.filterBumps(rating: "3")
        }
        
        let vsetkyAction = UIAlertAction(title: "Všetky", style: .default) { (action) in
            self.filterBumps(rating: nil)
        }
        
        let cancelAction = UIAlertAction(title: "Zrušiť", style: .cancel) { (action) in
        }
        
        alertController.addAction(maleAction)
        alertController.addAction(stredneAction)
        alertController.addAction(velkeAction)
        alertController.addAction(vsetkyAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
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
        self.downloadAllBumpsFromServer()
    }
    
    @IBAction func showBumpsForServer(_ sender: Any) {
        DispatchQueue.global().async {
            let results = BumpForServer.all()
            let annotations = self.getAnnotations(results: results)
            DispatchQueue.main.async {
                if let currentAnnotations = self.mapView.annotations {
                    self.mapView.removeAnnotations(currentAnnotations)
                }
                if (annotations.count > 0) {
                    self.mapView.addAnnotations(annotations)
                }
            }
        }
    }
    
    @IBAction func sendAllBumpsToServer() {
        print("INFO: sendAllBumpsToServer()")
        DispatchQueue.global().async {
            let networkService = NetworkService(delegate: self)
            networkService.delegate = self
            networkService.sendAllBumpsToServer()
        }
    }
    
    func downloadAllBumpsFromServer(){
        if let userLocation = self.mapView.userLocation {
            DispatchQueue.global().async {
                let networkService = NetworkService(delegate: self)
                networkService.downloadBumpsFromServer( coordinate: userLocation.coordinate, net: 1 )
            }
        } else { print("Nemam userLocation") }
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
        print("INFO: Pridavam anotacie do navigation mapView")
        viewController.mapView?.addAnnotations(self.mapAnnotations)
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

//MARK: - BumpAlgorithmDelegate
extension MapViewController: BumpAlgorithmDelegate {
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

//MARK: - NetworkServiceDelegate
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
    
    func itemsUploaded() {
        print("INFO: výtlky boli odoslané na server")
    }
}

//MARK: - BumpNotifyAlgorithmDelegate
extension MapViewController: BumpNotifyAlgorithmDelegate {
    func notify(annotations: [MGLAnnotation]) {
        //self.mapView.removeAnnotations(self.mapAnnotations)
        //self.mapAnnotations.removeAll()
        self.mapAnnotations = annotations
        self.mapView.addAnnotations(self.mapAnnotations)
    }
}
//MARK: - MGLMapViewDelegate
extension MapViewController: MGLMapViewDelegate {
    
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
        
        if Reachability.isConnectedToNetwork(){
            print("Internet Connection Available!")
            self.sendAllBumpsToServer()
            self.downloadAllBumpsFromServer()
        }else{
            print("No Internet Connection!")
        }
    }
    
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
        
        if let annotations = self.mapView.annotations {
            self.mapView.removeAnnotations(annotations)
        }
        if let currentRoute = self.currentRoute {
            self.navigationViewController = NavigationViewController(for: currentRoute)
            if let navigationViewController = self.navigationViewController {
                navigationViewController.navigationDelegate = self
                _ = BumpNotifyAlgorithm(route: currentRoute, delegate: navigationViewController)
                self.present(navigationViewController, animated: true, completion: nil)
                print("AFTER NAVIGATION VIEW")
            }
        }
        
    }
    
    func mapView(_ mapView: MGLMapView, regionWillChangeAnimated animated: Bool) {
        
        //geocoder.reverseGeocoding(latitude: (mapView.userLocation?.coordinate.latitude)!, longitude: (mapView.userLocation?.coordinate.longitude)!)
    }
    
    func mapView(_ mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
//        geocodingDataTask?.cancel()
//        let options = ReverseGeocodeOptions(coordinate: mapView.centerCoordinate)
//        geocodingDataTask = geocoder.geocode(options) { [unowned self] (placemarks, attribution, error) in
//            if let error = error {
//                NSLog("%@", error)
//            } else if let placemarks = placemarks, !placemarks.isEmpty {
//                //self.resultsLabel.text = placemarks[0].qualifiedName
//            } else {
//                //self.resultsLabel.text = "No results"
//            }
//        }
    }
}

//MARK: - NavigationMapViewDelegate
extension MapViewController: NavigationMapViewDelegate {
    
//    func navigationMapView(_ mapView: NavigationMapView, didSelect route: Route) {
//        currentRoute = route
//    }
    // To use these delegate methods, set the `VoiceControllerDelegate` on your `VoiceController`.
    //
    // Called when there is an error with speaking a voice instruction.
    func voiceController(_ voiceController: RouteVoiceController, spokenInstructionsDidFailWith error: Error) {
        print(error.localizedDescription)
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
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didRerouteAlong route: Route){
        print("INFO: IDEM KALKULOVAT VYTLKY na turn by turn")
        self.bumpNotifyAlgorithm = BumpNotifyAlgorithm(route: route, delegate: navigationViewController)
    }
}

//MARK: - BumpNotifyAlgorithmDelegate
extension NavigationViewController: BumpNotifyAlgorithmDelegate {
    func notify(annotations: [MGLAnnotation]) {
        self.mapView?.addAnnotations(annotations)
    }
}

//MARK: - FilterPopOverViewDelegate
extension MapViewController: FilterPopOverViewDelegate {
    
    func filterBumps(rating: String?) {
        DispatchQueue.global().async {
            let results = BumpFromServer.findByRating(rating: rating)
            var annotations = [MGLPointAnnotation]()
            for bump in results {
                let annotation = MGLPointAnnotation()
                annotation.coordinate = CLLocationCoordinate2D(
                    latitude: bump.value(forKey: "latitude") as! Double,
                    longitude: bump.value(forKey: "longitude") as! Double)
                annotation.title = String(describing: bump.value(forKey: "type"))
                annotation.subtitle = "hello"
                annotations.append(annotation)
            }
            DispatchQueue.main.async {
                if let currentAnnotations = self.mapView.annotations {
                    self.mapView.removeAnnotations(currentAnnotations)
                }
                if (annotations.count > 0) {
                    self.mapView.addAnnotations(annotations)
                }
            }
        }
    }
    
    
}

// MARK: - NavigationMapViewCourseTrackingDelegate
extension MapViewController: AnnotationsViewControllerDelegate {
    
    func updateBumpsFromServerAnnotations(annotations: [MGLPointAnnotation]) {
        
        mapView.removeAnnotations(bumpsFromServerAnnotations)
        bumpsFromServerAnnotations.removeAll()
        bumpsFromServerAnnotations.append(contentsOf: annotations)
        mapView.addAnnotations(bumpsFromServerAnnotations)
    }
    
    func updateBumpsForServerAnnotations(annotations: [MGLPointAnnotation]) {

        mapView.removeAnnotations(bumpsForServerAnnotations)
        bumpsForServerAnnotations.removeAll()
        bumpsForServerAnnotations.append(contentsOf: annotations)
        mapView.addAnnotations(bumpsForServerAnnotations)
    }
    
}

// MARK: - NavigationMapViewCourseTrackingDelegate
//extension MapViewController: NavigationMapViewCourseTrackingDelegate {
//    func navigationMapViewDidStartTrackingCourse(_ mapView: NavigationMapView) {
//        .isHidden = true
//        mapView.logoView.isHidden = false
//    }
//    
//    func navigationMapViewDidStopTrackingCourse(_ mapView: NavigationMapView) {
//        recenterButton.isHidden = false
//        mapView.logoView.isHidden = true
//    }
//}

//Vytvorene podla - http://theswiftguy.com/index.php/2017/07/03/mapviewsearch/
//MARK: - UISearchControllerDelegate
extension MapViewController: UISearchBarDelegate {
    
    @IBAction func searchButtonClick(_ sender: StylableButton) {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.delegate = self
        present(searchController, animated: true, completion: nil)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar)
    {
        //Ignoring user
        UIApplication.shared.beginIgnoringInteractionEvents()
        
        //Activity Indicator
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.startAnimating()
        
        self.view.addSubview(activityIndicator)
        
        //Hide search bar
        searchBar.resignFirstResponder()
        dismiss(animated: true, completion: nil)
        //Create the search request
        let searchRequest = MKLocalSearchRequest()
        searchRequest.naturalLanguageQuery = searchBar.text

        let activeSearch = MKLocalSearch(request: searchRequest)

        activeSearch.start { (response, error) in
            UIApplication.shared.endIgnoringInteractionEvents()
            activityIndicator.stopAnimating()
            guard let response = response else {
                print("Search error: \(error)")
                return
            }
            
            for item in response.mapItems {
                print(item)
            }
        }
//        activeSearch.start { (response, error) in
//
//            UIApplication.shared.endIgnoringInteractionEvents()
//
//            if response == nil
//            {
//                print("ERROR")
//            }
//            else
//            {
//                //Remove annotations
//                let annotations = self.mapView.annotations
//                self.mapView.removeAnnotations(annotations!)
//
//                //Getting data
//                let latitude = response?.boundingRegion.center.latitude
//                let longitude = response?.boundingRegion.center.longitude
//
//                //Create annotation
//                let annotation = MGLPointAnnotation()
//                annotation.title = searchBar.text
//                annotation.coordinate = CLLocationCoordinate2DMake(latitude!, longitude!)
//                self.mapView.addAnnotation(annotation)
//
//                //Zooming in on annotation
//                let coordinate:CLLocationCoordinate2D = CLLocationCoordinate2DMake(latitude!, longitude!)
//                let span = MKCoordinateSpanMake(0.1, 0.1)
//                let region = MKCoordinateRegionMake(coordinate, span)
//
//            }
//
//        }
    }
    
    
    
}

