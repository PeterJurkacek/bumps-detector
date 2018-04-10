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
class MapViewController: UIViewController {
    
    var destinationAnnotation: MGLPointAnnotation?
    var navigationViewController: NavigationViewController?
    var sendDetectedBumpToServerTimer: Timer?
    var notificationToken: NotificationToken? = nil
    
    var currentRoute: Route?
    var bumpDetectionAlgorithm: BumpDetectionAlgorithm?
    var bumpNotifyAlgorithm: BumpNotifyAlgorithm?
    var annotationViewController: AnnotationsViewController?
    
    var bumpsFromServerAnnotations = [MGLPointAnnotation]()
    var bumpsForServerAnnotations = [MGLPointAnnotation]()
    var routeAnnotations = [MGLPointAnnotation]()
    
    var mapAnnotations  = [MGLAnnotation]()
    //var selectedLocation : Bump = Bump()
    var geocodingDataTask: URLSessionDataTask?
    var geocoder: GeocodingService!
    
    //MARK: - IBOutlet
    @IBOutlet weak var mapView: NavigationMapView!
    @IBOutlet weak var overviewButton: Button!
    @IBOutlet weak var reportButton: Button!
    @IBOutlet weak var recenterButton: ResumeButton!
    
    @IBOutlet weak var searchButton: Button!
    
    @IBOutlet weak var filterButton: Button!
    
    @IBOutlet weak var mapStyleButton: Button!
    
    var isInUserTrackingMode = false
    var updatingLocation = false
    var isInOverviewMode = false
    {
        didSet {
            if isInOverviewMode {
                overviewButton.isHidden = true
                recenterButton.isHidden = false
                //wayNameView.isHidden = true
                mapView.logoView.isHidden = true
            } else {
                isInUserTrackingMode = true
                overviewButton.isHidden = false
                recenterButton.isHidden = true
                mapView.logoView.isHidden = false
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        overviewButton.applyDefaultCornerRadiusShadow(cornerRadius: overviewButton.bounds.midX)
        reportButton.applyDefaultCornerRadiusShadow(cornerRadius: reportButton.bounds.midX)
        recenterButton.applyDefaultCornerRadiusShadow(cornerRadius: recenterButton.bounds.midX)
        searchButton.applyDefaultCornerRadiusShadow(cornerRadius: searchButton.bounds.midX)
        filterButton.applyDefaultCornerRadiusShadow(cornerRadius: filterButton.bounds.midX)
        mapStyleButton.applyDefaultCornerRadiusShadow(cornerRadius: mapStyleButton.bounds.midX)
        
        
        mapView.showsUserLocation = true
        mapView.delegate = self
        mapView.navigationMapDelegate = self
        
        bumpDetectionAlgorithm = BumpDetectionAlgorithm()
        bumpDetectionAlgorithm?.delegate = self
        bumpDetectionAlgorithm?.startAlgorithm()
        
        annotationViewController = AnnotationsViewController(delegate: self)
        
        sendDetectedBumpToServerTimer = Timer.scheduledTimer(timeInterval: 60.0, target: self, selector: #selector(sendAllBumpsToServer), userInfo: nil, repeats: true)
        
        // Add a gesture recognizer to the map view
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(self.didLongPress(_:)))
        mapView.addGestureRecognizer(tap)
        geocoder = AppleMapSearch()
        
    }
    
    //MARK: - IBAction
    @IBAction func showBumpsFromServer() {
        self.downloadAllBumpsFromServer()
    }
    
    @IBAction func showBumpsForServer(_ sender: Any) {
        showAnnotations(annotations: self.bumpsForServerAnnotations)
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
    
    func showAnnotations(annotations: [MGLPointAnnotation]){
        
        if let currentAnnotations = self.mapView.annotations {
            self.mapView.removeAnnotations(currentAnnotations)
        }
        
        if !annotations.isEmpty {
            self.mapView.addAnnotations(annotations)
        }
    }
    
    @IBAction func recenter(_ sender: AnyObject) {
        let authStatus = CLLocationManager.authorizationStatus()
        if authStatus == .denied || authStatus == .restricted {
            showLocationServicesDeniedAlert()
            return
        }
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
    
    @IBAction func reportAction(_ sender: Any) {
        guard let parent = parent else { return }
        
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
        let annotation = MGLPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Start navigation"
        mapView.addAnnotation(annotation)
        
        self.destinationAnnotation = annotation
        
        calculateRoute(from: (mapView.userLocation!.coordinate), to: annotation.coordinate) { [unowned self] (route, error) in
            if error != nil {
                // Print an error message
                print("Error calculating route")
            }
        }
    }
    
    // Present the navigation view controller
    func presentNavigation(along route: Route) {
        let viewController = NavigationViewController(for: route)
        print("INFO: Pridavam anotacie do navigation mapView")
        viewController.mapView?.addAnnotations(self.routeAnnotations)
        self.present(viewController, animated: true, completion: nil)
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
    
    func showIosToast(message: String = "Some message..."){
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        self.present(alert, animated: true)
        
        // duration in seconds
        let duration: Double = 1
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
            alert.dismiss(animated: true)
        }
    }
    
}

//MARK: - BumpAlgorithmDelegate
extension MapViewController: BumpAlgorithmDelegate {
    func saveExportData(data: DataForExport) {
        
    }
    
    func bumpDetectedNotification(data: CustomAccelerometerData) {
        //TODO: vyhodit upozornenie ze vytlk bol zaznamenany
        guard let bumpDetectionAlgorithm = self.bumpDetectionAlgorithm else { return }
        //showIosToast(message: bumpDetectionAlgorithm.countOfDetectedBumps.description)
        print("INFO: BUMP DETECTED!!!")
    }
    
}

//MARK: - NetworkServiceDelegate
extension MapViewController: NetworkServiceDelegate{
    func itemsDownloaded() {
        print("INFO: Items downloaded from server")
//        DispatchQueue.global().async {
//
//            if let annotations = self.mapView.annotations {
//                self.mapView.removeAnnotations(annotations)
//            }
//            self.mapAnnotations.removeAll()
//
//            let results = BumpFromServer.all()
//            for bump in results {
//                let annotation = MGLPointAnnotation()
//                annotation.coordinate = CLLocationCoordinate2D(
//                    latitude: bump.value(forKey: "latitude") as! Double,
//                    longitude: bump.value(forKey: "longitude") as! Double)
//                annotation.title = String(describing: bump.value(forKey: "type"))
//                annotation.subtitle = "hello"
//                self.mapAnnotations.append(annotation)
//            }
//            DispatchQueue.main.async {
//                self.mapView.addAnnotations(self.mapAnnotations)
//            }
//        }
        
    }
    
    func itemsUploaded() {
        print("INFO: výtlky boli odoslané na server")
    }
}

//MARK: - BumpNotifyAlgorithmDelegate
extension MapViewController: BumpNotifyAlgorithmDelegate {
    func notify(annotations: [MGLPointAnnotation]) {
        self.routeAnnotations.append(contentsOf: annotations)
        self.mapView.addAnnotations(self.routeAnnotations)
    }
}
//MARK: - MGLMapViewDelegate
extension MapViewController: MGLMapViewDelegate {
    
    // Always allow callouts to appear when annotations are tapped.
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    // Zoom to the annotation when it is selected
    func mapView(_ mapView: MGLMapView, didSelect annotation: MGLAnnotation) {
        let camera = MGLMapCamera(lookingAtCenter: annotation.coordinate, fromDistance: 4000, pitch: 0, heading: 0)
        mapView.fly(to: camera, completionHandler: nil)
    }
    
    func mapViewWillStartLocatingUser(_ mapView: MGLMapView) {
        self.updatingLocation = true
    }
    
    func mapViewDidStopLocatingUser(_ mapView: MGLMapView) {
        self.updatingLocation = false
    }
    
    //Metóda nie je volaná ked je aplikácia v background mode
    func mapView(_ mapView: MGLMapView, didUpdate userLocation: MGLUserLocation?) {
        guard let location = userLocation?.location else {
            print("ERROR: didUpdate userLocationn nil")
            return
        }
        
//        if location.horizontalAccuracy < 100 && !self.isInUserTrackingMode && !self.isInOverviewMode {
//            mapView.setUserTrackingMode(.follow, animated: false)
//            isInUserTrackingMode = true
//        }
        self.bumpDetectionAlgorithm?.userLocation = userLocation?.location
    }
    
    func mapView(_ mapView: MGLMapView, didFailToLocateUserWithError error: Error) {
        if (error as NSError).code == CLError.denied.rawValue {
            print("ERROR: didFailToLocateUserWithError denied: \(error)")
        }
        
        if (error as NSError).code == CLError.locationUnknown.rawValue {
            print("ERROR: didFailToLocateUserWithError locationUnknown: \(error)")
        }
        
        if (error as NSError).code == CLError.network.rawValue {
            print("ERROR: didFailToLocateUserWithError network: \(error)")
        }
        
        return
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MGLMapView) {
        // Allow the map to display the user's location
        //Spusti zistovanie aktualnej polohy
        mapView.setUserTrackingMode(.follow, animated: false)
    }
    
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
        if annotation.isEqual(self.destinationAnnotation) {
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
        
    }
    
    func mapView(_ mapView: MGLMapView, regionWillChangeAnimated animated: Bool) {

    }
    
    func mapView(_ mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
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
            self.routeAnnotations.removeAll()
            self.bumpNotifyAlgorithm = BumpNotifyAlgorithm(route: route, delegate: self)
            self.updateVisibleBounds()
            self.isInOverviewMode = true
            self.mapView.showRoute(route)
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
        self.mapView.setUserTrackingMode(.followWithHeading, animated: true)
        self.showAnnotations(annotations: self.bumpsForServerAnnotations)
        navigationViewController.dismiss(animated: true, completion: nil)
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didRerouteAlong route: Route){
        print("INFO: IDEM KALKULOVAT VYTLKY na turn by turn")
        self.bumpNotifyAlgorithm = BumpNotifyAlgorithm(route: route, delegate: navigationViewController)
    }
}

//MARK: - BumpNotifyAlgorithmDelegate
extension NavigationViewController: BumpNotifyAlgorithmDelegate {
    func notify(annotations: [MGLPointAnnotation]) {
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
                self.showAnnotations(annotations: annotations)
            }
        }
    }


}

// MARK: - AnnotationsViewControllerDelegate
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

extension UIView {
    func applyDefaultCornerRadiusShadow(cornerRadius: CGFloat? = 4, shadowOpacity: CGFloat? = 0.1) {
        layer.cornerRadius = cornerRadius!
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 4
        layer.shadowOpacity = Float(shadowOpacity!)
    }
}

