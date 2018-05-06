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
    
    var longTapAnnotation: MGLPointAnnotation?
    var destinationAnnotation: MGLPointAnnotation?
    var navigationViewController: NavigationViewController?
    var sendDetectedBumpToServerTimer: Timer?
    var downloadBumpFromServerTimer: Timer?
    var simulateLocationUpdate: Timer?
    //Activity Indicator
    let activityIndicator = UIActivityIndicatorView()
    var notificationToken: NotificationToken? = nil
    let simulationIsEnabled = false
    
    var currentRoute: Route? {
        didSet {
            if currentRoute != nil {
                overviewButton.isHidden = false
            }
            else {
                overviewButton.isHidden = true
            }
        }
    }
    var bumpDetectionAlgorithm: BumpDetectionAlgorithm?
    var bumpNotifyAlgorithm: BumpNotifyAlgorithm?
    var annotationViewController: RealmNotification?
    
    var bumpsFromServerAnnotations = [MGLPointAnnotation]()
    var bumpsForServerAnnotations = [MGLPointAnnotation]()
    var routeAnnotations = [MGLPointAnnotation]()
    
    var routes = [Route]()
    
    var mapAnnotations  = [MGLAnnotation]()
    //var selectedLocation : Bump = Bump()
    var geocodingDataTask: URLSessionDataTask?
    var geocoder: GeocodingService!
    
    //MARK: - IBOutlet
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var mapView: NavigationMapView!
    @IBOutlet weak var overviewButton: Button!
    @IBOutlet weak var reportButton: Button!
    @IBOutlet weak var recenterButton: ResumeButton!
    
    @IBOutlet weak var navigationBar: UINavigationItem!
    @IBOutlet weak var searchButton: Button!
    
    @IBOutlet weak var filterButton: Button!
    
    @IBOutlet weak var mapStyleButton: Button!
    
    @IBOutlet weak var detectionCount: UILabel!
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
    
    //MARK: viewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        overviewButton.applyDefaultCornerRadiusShadow(cornerRadius: overviewButton.bounds.midX)
        overviewButton.isHidden = true
        reportButton.applyDefaultCornerRadiusShadow(cornerRadius: reportButton.bounds.midX)
        reportButton.isHidden = true
        recenterButton.applyDefaultCornerRadiusShadow(cornerRadius: recenterButton.bounds.midX)
        searchButton.applyDefaultCornerRadiusShadow(cornerRadius: searchButton.bounds.midX)
        searchButton.isHidden = true
        filterButton.applyDefaultCornerRadiusShadow(cornerRadius: filterButton.bounds.midX)
        mapStyleButton.applyDefaultCornerRadiusShadow(cornerRadius: mapStyleButton.bounds.midX)


        mapView.showsUserLocation = true
        mapView.delegate = self
        mapView.navigationMapDelegate = self

        bumpDetectionAlgorithm = BumpDetectionAlgorithm()
        bumpDetectionAlgorithm?.delegate = self
        bumpDetectionAlgorithm?.startAlgorithm()

        annotationViewController = RealmNotification(delegate: self)

        //Setup activit Indicator
        activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        mapView.addSubview(activityIndicator)

        sendDetectedBumpToServerTimer = Timer.scheduledTimer(timeInterval: 1*60.0, target: self, selector: #selector(sendAllBumpsToServer), userInfo: nil, repeats: true)
        downloadBumpFromServerTimer = Timer.scheduledTimer(timeInterval: 5*60.0, target: self, selector: #selector(synchronizeWithServer), userInfo: nil, repeats: true)

        // Add a gesture recognizer to the map view
        let tap = UILongPressGestureRecognizer(target: self, action: #selector(self.didLongPress(_:)))
        mapView.addGestureRecognizer(tap)
        geocoder = AppleMapSearch()
        

    }
    
    //MARK: - IBAction
    @IBAction func enableBumpDetection(_ sender: UISwitch) {
        if sender.isOn {
            self.bumpDetectionAlgorithm?.start()
        } else {
            self.bumpDetectionAlgorithm?.stop()
        }
    }

    @IBAction func showBumpsFromServer() {
        self.synchronizeWithServer()
    }
    
    @IBAction func showBumpsForServer(_ sender: Any) {
        showAnnotations(annotations: self.bumpsForServerAnnotations)
    }
    
    @objc func sendAllBumpsToServer() {
        print("INFO: sendAllBumpsToServer()")
        DispatchQueue.global().async {
            let networkService = NetworkService(delegate: self)
            networkService.delegate = self
            networkService.sendAllBumpsToServer()
        }
    }
    
    @objc func synchronizeWithServer(){
        print("INFO: downloadAllBumpsFromServer()")
        if let userLocation = self.mapView.userLocation {
            DispatchQueue.global().async {
                let networkService = NetworkService(delegate: self)
                networkService.downloadBumpsFromServer( coordinate: userLocation.coordinate, net: 0 )
            }
        } else { print("Nemam userLocation") }
    }
    
    func showAnnotations(annotations: [MGLPointAnnotation]){
        
        self.mapView.removeAnnotations(self.mapView.annotations ?? [])
        
        if let destination = self.destinationAnnotation {
            self.mapView.addAnnotation(destination)
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
        //mapView.tracksUserCourse = true
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
        updateVisibleBounds(along: self.currentRoute!)
        isInOverviewMode = true
    }

    func updateVisibleBounds(along route: Route) {
        guard let userLocation = mapView.userLocation?.coordinate else { return }

        let overviewContentInset = UIEdgeInsets(top: 55, left: 85, bottom: 55, right: 30)
        
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
        guard parent != nil else { return }
        
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
        
        let ziadneAction = UIAlertAction(title: "Žiadne", style: .default) { (action) in
            self.showAnnotations(annotations: [])
        }
        
        let cancelAction = UIAlertAction(title: "Zrušiť", style: .cancel) { (action) in
        }
        
        alertController.addAction(maleAction)
        alertController.addAction(stredneAction)
        alertController.addAction(velkeAction)
        alertController.addAction(vsetkyAction)
        alertController.addAction(ziadneAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    func annotationActionMenu(for annotation: MGLAnnotation!) {
        let alertController = UIAlertController(title: "Vybratá poloha", message: "S touto polohou môžem vykonať nasledovné akcie.", preferredStyle: .actionSheet)
        
        let navigationAction = UIAlertAction(title: "Navigovať", style: .default) { (action) in
            if self.currentRoute != nil && self.destinationAnnotation != nil && self.destinationAnnotation!.isEqual(annotation){
                self.presentNavigation(along: self.currentRoute!)
            }
            else {
                if !Reachability.isConnectedToNetwork(){
                    self.showNoInternetAlert()
                }
                //Zistime si trasu
                self.calculateRoute(from: (self.mapView.userLocation!.coordinate), to: annotation.coordinate) { (routes, error) in
                    if error != nil {
                        print("Error calculating route")
                    }
                    guard let route = routes?.first else { return }
                    self.currentRoute = route
                    self.presentNavigation(along: route)
                }
            }
        }
        let routeOptionsAction = UIAlertAction(title: "Zobraziť trasu", style: .default) { (action) in
            //TODO: Implementovať výber z vrátených trás
            if self.currentRoute != nil && self.destinationAnnotation != nil && self.destinationAnnotation!.isEqual(annotation){
                self.updateVisibleBounds(along: self.currentRoute!)
                self.isInOverviewMode = true
            }
            else {
                if !Reachability.isConnectedToNetwork(){
                    self.showNoInternetAlert()
                    
                }
                //Zistime si trasu
                self.calculateRoute(from: (self.mapView.userLocation!.coordinate), to: annotation.coordinate){ (routes, error) in
                    if error != nil {
                        print("Error calculating route")
                    }
                    guard let cesty = routes else { return }
//                    if !self.routeAnnotations.isEmpty {
//                        self.mapView.removeAnnotations(self.routeAnnotations)
//                        self.routeAnnotations.removeAll()
//                    }
                    for route in cesty {
                        _ = BumpNotifyAlgorithm(route: route, delegate: self)
                    }
                    self.currentRoute = cesty.first!
                    self.mapView.showRoutes(cesty)
                    self.updateVisibleBounds(along: self.currentRoute!)
                    self.isInOverviewMode = true
                }
            }
        }
        
        let toggleBumpAction = UIAlertAction(title: "Manuálne označiť výtlk", style: .default) { (action) in
            //TODO: Implementovať funkcionalitu pre manuálne pridávanie výtlku
            if let bumpDetectionAlgoritm = self.bumpDetectionAlgorithm {
                bumpDetectionAlgoritm.processBump(delta: 0, location: CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude), manual: "1", type: "0", text: "IOS-manual-bump")
            }
            else {
                self.showErrorAlert(message: "Hlásenie sa nepodarilo zaznamenať.")
            }
        }
        
        let cancelAction = UIAlertAction(title: "Zrušiť", style: .cancel) { (action) in
        }
        
        alertController.addAction(navigationAction)
        alertController.addAction(routeOptionsAction)
        alertController.addAction(toggleBumpAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    @IBAction func searchButtonClick(_ sender: StylableButton) {
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.delegate = self
        present(searchController, animated: true, completion: nil)
    }
    
    @objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else { return }
        
        // Converts point where user did a long press to map coordinates
        let point = sender.location(in: mapView)
        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        setLongTapAnnotation(for: coordinate)
    }
    
    func setLongTapAnnotation(for coordinate:CLLocationCoordinate2D){
        if let annotation = self.longTapAnnotation {
            self.mapView.removeAnnotation(annotation)
        }
        
        let annotation = MGLPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Možnosti?"
        self.longTapAnnotation = annotation
        mapView.addAnnotation(annotation)
        mapView.selectAnnotation(annotation, animated: false)

    }
    
    // Present the navigation view controller
    func presentNavigation(along route: Route!) {
        //navigationViewController.mapView?.addAnnotations(self.routeAnnotations)
        startEmbeddedNavigation(along: route)
    }
    
    func startEmbeddedNavigation(along route: Route!) {
        let navigationViewController = NavigationViewController(for: route)
        navigationViewController.showsReportFeedback = false
        navigationViewController.delegate = self
        _ = BumpNotifyAlgorithm(route: route, delegate: navigationViewController)
        
        if simulationIsEnabled {
            simulateLocationUpdate = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(simulateUpdate), userInfo: nil, repeats: true)
            navigationViewController.routeController.locationManager = SimulatedLocationManager(route: route!)
        }
        
        addChildViewController(navigationViewController)
        containerView.addSubview(navigationViewController.view)
        navigationViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            navigationViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 0),
            navigationViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 0),
            navigationViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 0),
            navigationViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0)
            ])
        self.navigationViewController = navigationViewController
        self.didMove(toParentViewController: self)
    }
    
    @objc func simulateUpdate(){
        if let location = navigationViewController?.routeController.locationManager.location {
            self.bumpDetectionAlgorithm?.userLocation = location
            print(location)
        }
    }
    
    func endEmbeddedNavigation(navigationViewController: NavigationViewController!) {
        
        navigationViewController.willMove(toParentViewController: nil)
        navigationViewController.view.removeFromSuperview()
        navigationViewController.view.removeConstraints([
            navigationViewController.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 0),
            navigationViewController.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: 0),
            navigationViewController.view.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 0),
            navigationViewController.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: 0)
            ])
        navigationViewController.removeFromParentViewController()
        
        navigationViewController.dismiss(animated: true, completion: nil)
        
        if simulationIsEnabled {

            simulateLocationUpdate?.invalidate()
            simulateLocationUpdate = nil
        }

    }
    
    // MARK: - UIAlertActions
    func showErrorAlert(message: String = "Niekde nastala chyba. Pokúste sa prosím akciu zopakovať neskôr.") {
        let alert = UIAlertController(title: "Chyba",
                                      message: message,
                                      preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default,
                                     handler: nil)
        alert.addAction(okAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(title: "Neznáma poloha",
                                      message: "Prosím, v nastaveniach povoľte aplikácií pristupovať k vašej polohe.",
                                      preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default,
                                     handler: nil)
        alert.addAction(okAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    func showNoInternetAlert() {
        let alert = UIAlertController(title: "Nemám Internetové pripojenie",
                                      message: "Prosím, skontrolujte si Internetové pripojenie",
                                      preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default,
                                     handler: nil)
        alert.addAction(okAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    func showOkAlert(title: String? = nil, message: String = "Some message..."){
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default,
                                     handler: nil)
        alert.addAction(okAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    func showQuickAlert(title: String? = nil, message: String = "Some message..."){
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        
        present(alert, animated: true, completion: nil)
        // duration in seconds
        let duration: Double = 1

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + duration) {
            alert.dismiss(animated: true)
        }
    }
    
}

//MARK: - BumpAlgorithmDelegate
extension MapViewController: BumpAlgorithmDelegate {
    
    func notifyUser(manual: String, type: String) {
        if manual == "1" {
            self.showOkAlert(title: "Manuálne nahlásený výtlk", message: "Vaše hlásenie bolo zaznamenané. Ďakujeme, že pomáhate zlepšovať kvality ciest na Slovensku :)")
        }
        else {
            self.showQuickAlert(title: "Automaticky detegovaný výtlk", message: "Vaše hlásenie bolo zaznamenané. Ďakujeme, že pomáhate zlepšovať kvality ciest na Slovensku :)")
        }
    }
    
    func bumpDetectedNotification(data: MGLPointAnnotation) {
        print("INFO: BUMP DETECTED!!!")
        //self.mapView.addAnnotation(data)
    }
    
    func saveExportData(data: DataForExport) {
        
    }
    
    
    
}

//MARK: - NetworkServiceDelegate
extension MapViewController: NetworkServiceDelegate{
    
    func synchronizationWithServerResult(userMessage usserMessage: String) {
        print("INFO: synchronizationWithServerResult: \(usserMessage)")
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
        if self.navigationViewController != nil {
            guard let mapView = self.navigationViewController!.mapView else {
                print("ERROR: - BumpNotifyAlgorithmDelegate func notify")
                return
            }
            mapView.addAnnotations(self.routeAnnotations)
        }
        else {
            self.mapView.addAnnotations(self.routeAnnotations)
        }
    }
}

//Mark: - CLLocationManagerDelegate
//extension MapViewController: CLLocationManagerDelegate {
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        if let location = locations.last {
//            print(location)
//        }
//    }
//}

//MARK: - MGLMapViewDelegate
extension MapViewController: MGLMapViewDelegate {
    
    // Always allow callouts to appear when annotations are tapped.
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    // Zoom to the annotation when it is selected
    func mapView(_ mapView: MGLMapView, didSelect annotation: MGLAnnotation) {
        
        let camera = MGLMapCamera(lookingAtCenter: annotation.coordinate, fromDistance: 4000, pitch: 0, heading: 0)
        mapView.userTrackingMode = .none
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
        self.bumpDetectionAlgorithm?.userLocation = location
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
        if let route = self.currentRoute {
            self.mapView.showRoutes([route])
        }
        if !isInOverviewMode {
            mapView.setUserTrackingMode(.followWithHeading, animated: false)
        }
    }
    
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
        
        if ((self.destinationAnnotation != nil && annotation.isEqual(destinationAnnotation)) ||  (self.longTapAnnotation != nil && annotation.isEqual(longTapAnnotation))) {
            annotationActionMenu(for: annotation)
        }
//            if let annotations = self.mapView.annotations {
//                self.mapView.removeAnnotations(annotations)
//            }
//            if let currentRoute = self.currentRoute {
//                self.navigationViewController = NavigationViewController(for: currentRoute)
//                if let navigationViewController = self.navigationViewController {
//                    navigationViewController.delegate = self
//                    navigationViewController.showsReportFeedback = false
//                    let deadlineTime = DispatchTime.now() + .seconds(2)
//                    DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
//                        _ = BumpNotifyAlgorithm(route: currentRoute, delegate: self)
//                    }
//                    self.present(navigationViewController, animated: true, completion: nil)
//                    print("AFTER NAVIGATION VIEW")
//                }
//            }
        
    }
    
    func mapView(_ mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
        recenterButton.isHidden = false
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
    
    func mapViewDidFinishLoadingMap(_ mapView: NavigationMapView) {
        // Allow the map to display the user's location
        //Spusti zistovanie aktualnej polohy
        print("Hello world")
        //mapView.setUserTrackingMode(.followWithCourse, animated: false)
    }
    
    // Calculate route to be used for navigation
    func calculateRoute(from origin: CLLocationCoordinate2D,
                        to destination: CLLocationCoordinate2D,
                        completion: @escaping ([Route]?, Error?) -> ()) {
        if let annotations = self.mapView.annotations {
            self.mapView.removeAnnotations(annotations)
        }
        if let annotation = self.destinationAnnotation {
            self.mapView.removeAnnotation(annotation)
        }
        
        let annotation = MGLPointAnnotation()
        annotation.coordinate = destination
        annotation.title = "Možnosti?"
        mapView.addAnnotation(annotation)
        
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
        UIApplication.shared.endIgnoringInteractionEvents()
        self.activityIndicator.startAnimating()
        _ = Directions.shared.calculate(options) { [unowned self] (waypoints, routes, error) in
            self.activityIndicator.stopAnimating()
            UIApplication.shared.endIgnoringInteractionEvents()
            if let routes = routes {
                return completion(routes, error)
            }
//            guard let route = routes?.first, error == nil else {
//                print(error!.localizedDescription)
//                return
//            }
            
//            self.currentRoute = route
//            self.routeAnnotations.removeAll()
//            //self.bumpNotifyAlgorithm = BumpNotifyAlgorithm(route: route, delegate: self)
//            self.updateVisibleBounds()
//            self.isInOverviewMode = true
//            //self.mapView.showRoutes([route])
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
        //self.mapView.removeRoutes()
        self.mapView.setUserTrackingMode(.followWithHeading, animated: true)
        self.endEmbeddedNavigation(navigationViewController: navigationViewController)
        self.navigationViewController = nil
    }
    
}

//MARK: - BumpNotifyAlgorithmDelegate
extension NavigationViewController: BumpNotifyAlgorithmDelegate {
    func notify(annotations: [MGLPointAnnotation]) {
        self.mapView?.addAnnotations(annotations)
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didRerouteAlong route: Route){
        print("INFO: IDEM KALKULOVAT VYTLKY na turn by turn")
        self.mapView?.removeAnnotations(self.mapView?.annotations ?? [])
        _ = BumpNotifyAlgorithm(route: route, delegate: navigationViewController)
    }
    
}

//MARK: - FilterPopOverViewDelegate
extension MapViewController: FilterPopOverViewDelegate {

    func filterBumps(rating: String?) {
        DispatchQueue.global().async {
            let results = BumpFromServer.findByRating(rating: rating)
            var annotations = [MGLPointAnnotation]()
            for bump in results {
                annotations.append(bump.getAnnotation())
            }
            DispatchQueue.main.async {
                self.showAnnotations(annotations: annotations)
                
            }
        }
    }


}

// MARK: - AnnotationsViewControllerDelegate
extension MapViewController: RealmNotificationDelegate {
    
    func updateBumpsFromServerAnnotations(annotations: [MGLPointAnnotation]) {
        
        //mapView.removeAnnotations(bumpsFromServerAnnotations)
        bumpsFromServerAnnotations.removeAll()
        bumpsFromServerAnnotations.append(contentsOf: annotations)
        //mapView.addAnnotations(bumpsFromServerAnnotations)
    }
    
    func updateBumpsForServerAnnotations(annotations: [MGLPointAnnotation]) {

        //mapView.removeAnnotations(bumpsForServerAnnotations)
        bumpsForServerAnnotations.removeAll()
        bumpsForServerAnnotations.append(contentsOf: annotations)
        //mapView.addAnnotations(bumpsForServerAnnotations)
    }
    
}

//Vytvorene podla - http://theswiftguy.com/index.php/2017/07/03/mapviewsearch/
//MARK: - UISearchControllerDelegate
extension MapViewController: UISearchBarDelegate {
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar)
    {
        //Ignoring user
        UIApplication.shared.beginIgnoringInteractionEvents()
        activityIndicator.startAnimating()
        
        //Hide search bar
        searchBar.resignFirstResponder()
        dismiss(animated: true, completion: nil)
        //Create the search request
        let searchRequest = MKLocalSearchRequest()
        searchRequest.naturalLanguageQuery = searchBar.text

        let activeSearch = MKLocalSearch(request: searchRequest)

//        activeSearch.start { (response, error) in
//            UIApplication.shared.endIgnoringInteractionEvents()
//            activityIndicator.stopAnimating()
//            guard let response = response else {
//                print(error.debugDescription)
//                return
//            }
//
//            for item in response.mapItems {
//                print(item)
//            }
//        }
        activeSearch.start { (response, error) in

            UIApplication.shared.endIgnoringInteractionEvents()
            self.activityIndicator.stopAnimating()
            guard let response = response else {
                print(error.debugDescription)
                return
            }

            //Getting data
            let latitude = response.boundingRegion.center.latitude
            let longitude = response.boundingRegion.center.longitude

            //Create annotation
            let coordinate = CLLocationCoordinate2DMake(latitude, longitude)
            self.setLongTapAnnotation(for: coordinate)

        }
    }
}

extension UIView {
    //Zagulatenie action Buttonov
    func applyDefaultCornerRadiusShadow(cornerRadius: CGFloat? = 4, shadowOpacity: CGFloat? = 0.1) {
        layer.cornerRadius = cornerRadius!
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 4
        layer.shadowOpacity = Float(shadowOpacity!)
    }
}

//MARK: NavigationMapView extension
extension NavigationMapView {
    func addRouteAnnotations(annotations: [MGLAnnotation]) {
        guard let style = style else { return }
        
        addAnnotations(annotations)
       
    }
}

extension MapViewController: UINavigationControllerDelegate{
    
}

