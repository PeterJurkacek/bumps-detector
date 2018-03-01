//
//  Accelerometer.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 24.10.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import Foundation
import UIKit
import CoreMotion
import simd
import CoreLocation

protocol BumpAlgorithmDelegate {
    func saveBump(data: CustomAccelerometerData)
    func saveExportData(data: DataForExport)
}

enum DistanceAlgorithm {
    case manhatan
    case euclidian
    case minski
}

class BumpDetectionAlgorithm {
    
    var userLocation: CLLocation?
    var bumpAlgorithmDelegate: BumpAlgorithmDelegate?
    var motionManager: CMMotionManager?
    var gyroItems = [CMRotationRate]()
    var isCalibrated = false
    let THRESHOLD = 4.5
    let THRESHOLD_USER_MOVEMENTS = 1.0
    let lastFewItemsCount = 60
    let ItemsFreqiency = 60.0
    var prevAttitude: CMAttitude?
    
    var queue: OperationQueue
    var date: Date?
    var timer: Timer?

    var initialDeviceAttitude: CMAttitude?
    var windowAccelData = WindowAccelData(size: 60)
    
    //MARK: Initializers
    init(){
        motionManager = CMMotionManager()
        queue = PendingOperation.shared.accelerometerQueue
    }

    //MARK: Bump detection algorithms
    
    func startAlgorithm() {
        startDeviceMotionSensor()
    }
    
    func recognizeBump(for customData: CustomAccelerometerData){
        
        print(self.userLocation)
        let window = self.windowAccelData
        let average_delta = window.getDeltaFromAverage(for: customData)
        let average_weigth_delta = window.getDeltaFromWeigthAverage(for: customData)
        window.add(element: customData)
        //print(delta)
        
        DispatchQueue.main.async {
            self.bumpAlgorithmDelegate?.saveExportData(data: DataForExport(
                customAccelData: customData,
                average: window.getAverage(),
                average_delta: average_delta,
                sum: window.getSum(),
                variance: window.getVariance(),
                weigth_average: window.getWeigthAverage(),
                weigth_sum: window.getWeigthSum(),
                weigth_average_delta: average_weigth_delta,
                priority: window.getPriority()))
        }
//        if average_delta > THRESHOLD && self.bumpAlgorithmDelegate != nil{
//            DispatchQueue.main.async {
//                self.bumpAlgorithmDelegate!.saveBump(data: data)
//            }
//        }
    }
    
    func startDeviceMotionSensor(){
        if let motionManager = self.motionManager {
            if motionManager.isDeviceMotionAvailable {
                motionManager.deviceMotionUpdateInterval = TimeInterval(1.0/ItemsFreqiency)
                motionManager.startDeviceMotionUpdates(to: queue){(deviceMotion, error) in
                    if let data = deviceMotion {
                        if (self.isDeviceStateChanging(state: data.attitude)) {
                            self.isCalibrated = false
                            NSLog("POHYB ZARIADENIA, NEZAZNAMENAVAM OTRASY...")
                            self.initialDeviceAttitude = data.attitude
                            motionManager.deviceMotionUpdateInterval = TimeInterval(2.0)
                        }
                        else if(!self.isCalibrated){
                            self.isCalibrated = true
                            self.windowAccelData.setPriority(accelData: data)
                            motionManager.deviceMotionUpdateInterval = TimeInterval(1.0/self.ItemsFreqiency)
                        }
                        else {
                            let customData = CustomAccelerometerData(accelerometerData: data, priority: self.windowAccelData.getPriority())
                            self.recognizeBump(for: customData)
                        }
                    }
                }
            }else { print("Na zariadeni nie je dostupny deviceMotion.") }
        } else { print("Nebol vytvorený objekt MotionManager.") }
    }
    
    func isDeviceStateChanging(state attitude :CMAttitude) -> Bool {
        
        if self.initialDeviceAttitude == nil {
            self.initialDeviceAttitude = attitude
            return false
        }
        else {
            let monitoringAttitude = attitude.copy() as! CMAttitude
            //print("BEFORE: \(magnitude(from: monitoringAttitude))")
            monitoringAttitude.multiply(byInverseOf: initialDeviceAttitude!)
            //print("AFTER: \(magnitude(from: monitoringAttitude))")
            let deltaMagnitude = magnitude(from: monitoringAttitude)
            //let sum = abs(magnitude(from: attitude) - initMagnitude)
            //NSLog("SUM \(sum)")
            if deltaMagnitude > THRESHOLD_USER_MOVEMENTS {
                return true
            }
            return false
        }
    }
    
    func magnitude(from rotation: CMRotationRate) -> Double {
        return sqrt(pow(rotation.x, 2) + pow(rotation.y, 2) + pow(rotation.z, 2))
    }
    
    func magnitude(from attitude: CMAttitude) -> Double {
        return sqrt(pow(attitude.roll, 2) + pow(attitude.yaw, 2) + pow(attitude.pitch, 2))
    }
    
}
