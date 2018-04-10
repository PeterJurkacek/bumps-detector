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
import CoreMotion

class ExportDataViewController: UIViewController, CLLocationManagerDelegate{
    
    @IBOutlet weak var messageLabel: UILabel!
    @IBOutlet weak var dataCountLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    
    var bumpDetectionAlgorithm: BumpDetectionAlgorithm?
    var timer = Timer()
    var seconds = 0;
    var dataCount = 0;
    
    let locationManager = CLLocationManager()
    var location: CLLocation?
    var updatingLocation = false
    var lastLocationError: Error?
    
    let geocoder = CLGeocoder()
    var placemark: CLPlacemark?
    var performingReverseGeocoding = false
    var lastGeocodingError: Error?
    var testNumber = 0
    
    let fileUtils = FileUtils()
    
    let dispatchQueue = DispatchQueue(label: "testQueue")
    
    @IBAction func export(sender: AnyObject) {
//        let fileName = "test\(Date()).txt"
//        let path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName)
//
//        var csvText = "Date Cas Stotiny, posledny_s_kazdym, posledny_s_priemerom, x, y, z, Threshold\n"
//
//       dispatchQueue.sync{
//        let count = allDataStorage.count
//
//        if count > 0 {
//
//            let sortedAllDataStorage = allDataStorage.sorted(by: {$0.datum < $1.datum})
//
//            
//            csvText.append("\(sortedAllDataStorage.count) 3\n")
//
//            for data in sortedAllDataStorage {
//
//                //let datum = "\(data.datum)"
//                //let proces = String(format: "%.1f", data.proces)
//                let delta = String(format: "%.3f", data.delta)
////                let x = String(format: "%.3f", data.x)
////                let y = String(format: "%.3f", data.y)
////                let z = String(format: "%.3f", data.z)
//                //let threshold = String(format: "%.1f", data.threshold)
//
//                //let newLine = "\(datum), \(proces), \(delta), \(x), \(y), \(z), \(threshold)\n"
//
//                //Write file podla k-means
//                //let newLine = "\(x) \(y) \(z) \(delta)\n"
//
//                let newLine = "\(delta)\n"
//                csvText.append(newLine)
//            }
//
//            do {
//                try csvText.write(to: path!, atomically: true, encoding: String.Encoding.utf8)
//
//                let vc = UIActivityViewController(activityItems: [path!], applicationActivities: [])
//                vc.excludedActivityTypes = [
//                    UIActivityType.assignToContact,
//                    UIActivityType.saveToCameraRoll,
//                    UIActivityType.postToFlickr,
//                    UIActivityType.postToVimeo,
//                    UIActivityType.postToTencentWeibo,
//                    UIActivityType.postToTwitter,
//                    UIActivityType.postToFacebook,
//                    UIActivityType.openInIBooks
//                ]
//                present(vc, animated: true, completion: nil)
//
//            } catch {
//                print("Failed to create file")
//                print("\(error)")
//            }
//
//        } else {
//            print("Error with export file")
//        }
//    }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //updateLabels()
        //configureGetButton()
    
        
        bumpDetectionAlgorithm = BumpDetectionAlgorithm()
        bumpDetectionAlgorithm?.delegate = self
        bumpDetectionAlgorithm!.startAlgorithm()
        runTimer()
    }
    
    func updateLabels() {
        dataCountLabel.text = "\(dataCount)"
        timeLabel.text = "\(seconds)"
        dataCount += 1
    }
    
    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1, target: self,   selector: (#selector(ExportDataViewController.updateTimer)), userInfo: nil, repeats: true)
    }
    
    @objc func updateTimer() {
        seconds += 1     //This will decrement(count down)the seconds.
    }
}

extension ExportDataViewController: BumpAlgorithmDelegate{
    func saveExportData(data: DataForExport) {
        dispatchQueue.async{
            //print(tuple)
            self.fileUtils.dataForExport.append(data)
            
            if(self.fileUtils.dataForExport.count > 1000){
                self.fileUtils.createFile()
                
                self.fileUtils.dataForExport.removeAll()
            }
            DispatchQueue.main.async {
                self.updateLabels()
            }
        }
    }
    
    func bumpDetectedNotification(data: CustomAccelerometerData) {
    }
    
    
}


