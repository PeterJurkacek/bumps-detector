//
//  CurrentLocationViewController.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 27.9.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import UIKit
import CoreLocation
import simd

class ExportDataViewController: UIViewController, CLLocationManagerDelegate{
    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var latitudeLabel: UILabel!
    @IBOutlet weak var longitudeLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var tagButton: UIButton!
    @IBOutlet weak var getButton: UIButton!
    
    var bumpDetectionAlgorithm: BumpDetectionAlgorithm?
    var allDataStorage = [(datum: Date, proces: Double, procesAverage: Double, x: Double, y: Double, z: Double, threshold: Double)]()
    
    let locationManager = CLLocationManager()
    var location: CLLocation?
    var updatingLocation = false
    var lastLocationError: Error?
    
    let geocoder = CLGeocoder()
    var placemark: CLPlacemark?
    var performingReverseGeocoding = false
    var lastGeocodingError: Error?
    var testNumber = 0
    
    @IBAction func export(sender: AnyObject) {
        testNumber += 1
        let fileName = "test\(testNumber).txt"
        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
        
        var csvText = "Date Cas Stotiny, posledny_s_kazdym, posledny_s_priemerom, x, y, z, Threshold\n"
        
        
        let count = allDataStorage.count
        
        if count > 0 {
            
            let sortedAllDataStorage = allDataStorage.sorted(by: {$0.datum < $1.datum})
            
            
            csvText.append("\(sortedAllDataStorage.count) \(3)")
            
            for data in sortedAllDataStorage {
                
                //let datum = "\(data.datum)"
                //let proces = String(format: "%.1f", data.proces)
                let procesAverage = String(format: "%.3f", data.procesAverage)
                let x = String(format: "%.3f", data.x)
                let y = String(format: "%.3f", data.y)
                let z = String(format: "%.3f", data.z)
                //let threshold = String(format: "%.1f", data.threshold)
                
                //let newLine = "\(datum), \(proces), \(procesAverage), \(x), \(y), \(z), \(threshold)\n"
                
                //Write file podla k-means
                let newLine = "\(x) \(y) \(z) \(procesAverage))\n"
                
                csvText.append(newLine)
            }
            
            do {
                try csvText.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
                
                let vc = UIActivityViewController(activityItems: [path!], applicationActivities: [])
                vc.excludedActivityTypes = [
                    UIActivityType.assignToContact,
                    UIActivityType.saveToCameraRoll,
                    UIActivityType.postToFlickr,
                    UIActivityType.postToVimeo,
                    UIActivityType.postToTencentWeibo,
                    UIActivityType.postToTwitter,
                    UIActivityType.postToFacebook,
                    UIActivityType.openInIBooks
                ]
                present(vc, animated: true, completion: nil)
                
            } catch {
                print("Failed to create file")
                print("\(error)")
            }
            
        } else {
            print("Error with export file")
        }
    }
    
    @IBAction func getLocation() {
        let authStatus = CLLocationManager.authorizationStatus()
        
        if authStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        
        if authStatus == .denied || authStatus == .restricted {
            showLocationServicesDeniedAlert()
            return
        }
        if updatingLocation {
            stopLocationManager()
        } else {
            location = nil
            lastLocationError = nil
            startLocationManager()
        }
        updateLabels()
        configureGetButton()
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        //updateLabels()
        //configureGetButton()
        bumpDetectionAlgorithm = BumpDetectionAlgorithm()
        bumpDetectionAlgorithm?.bumpAlgorithmDelegate = self
        DispatchQueue.global(qos: .utility).async{
            self.bumpDetectionAlgorithm!.startAccelGyro()
        }
    }

    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        print("didFailWithError \(error)")
        
        if (error as NSError).code == CLError.locationUnknown.rawValue {
            return
        }
        lastLocationError = error
        stopLocationManager()
        updateLabels()
        configureGetButton()
    }
    
    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        let newLocation = locations.last!
        print("didUpdateLocations \(newLocation)")
        
        if newLocation.timestamp.timeIntervalSinceNow < -5 {
            return
        }
        // 2
        if newLocation.horizontalAccuracy < 0 {
            return
        }
        // 3
        if location == nil || location!.horizontalAccuracy > newLocation.horizontalAccuracy {
        
            // 4
            lastLocationError = nil
            location = newLocation
            updateLabels()
            // 5
            if newLocation.horizontalAccuracy <= locationManager.desiredAccuracy{
                print("*** We're done!")
                stopLocationManager()
                configureGetButton()
            }
            if !performingReverseGeocoding {
                print("*** Going to geocode")
                performingReverseGeocoding = true
                geocoder.reverseGeocodeLocation(newLocation, completionHandler: {
                    placemarks, error in
                    print("*** Found placemarks: \(placemarks), error: \(String(describing: error))")
                })
            }
        }
        
    }

    func showLocationServicesDeniedAlert() {
        let alert = UIAlertController(title: "Location Services Disabled",
                                      message:
            "Please enable location services for this app in Settings.",
                                      preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default,
                                     handler: nil)
        present(alert, animated: true, completion: nil)
        alert.addAction(okAction)
    }
    
    func updateLabels() {
        if let location = location {
            latitudeLabel.text =
                String(format: "%.8f", location.coordinate.latitude)
            longitudeLabel.text =
                String(format: "%.8f", location.coordinate.longitude)
            tagButton.isHidden = false
            messageLabel.text = ""
        } else {
            latitudeLabel.text = ""
            longitudeLabel.text = ""
            addressLabel.text = ""
            tagButton.isHidden = true
            // The new code starts here:
            let statusMessage: String
            if let error = lastLocationError as NSError? {
                if error.domain == kCLErrorDomain &&
                    error.code == CLError.denied.rawValue {
                    statusMessage = "Location Services Disabled"
                } else {
                    statusMessage = "Error Getting Location"
                }
            } else if !CLLocationManager.locationServicesEnabled() {
                statusMessage = "Location Services Disabled"
            } else if updatingLocation {
                statusMessage = "Searching..."
            } else {
                statusMessage = "Tap 'Get My Location' to Start"
            }
            messageLabel.text = statusMessage
        }
    }

    func startLocationManager() {
        if CLLocationManager.locationServicesEnabled() {
            DispatchQueue.global(qos: .userInitiated).async {
                self.locationManager.delegate = self
                self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                self.locationManager.startUpdatingLocation()
                self.updatingLocation = true
            }
        }
    }
    
    func stopLocationManager() {
        if updatingLocation {
            locationManager.stopUpdatingLocation()
            locationManager.delegate = nil
            updatingLocation = false
        }
    }
    
    func configureGetButton() {
        if updatingLocation {
            getButton.setTitle("Stop", for: .normal)
        } else {
            getButton.setTitle("Get My Location", for: .normal)
        }
    }
}

extension ExportDataViewController: BumpAlgorithmDelegation{
    func saveBump(data: double3, date: Date) {
        
    }
    
    
}


