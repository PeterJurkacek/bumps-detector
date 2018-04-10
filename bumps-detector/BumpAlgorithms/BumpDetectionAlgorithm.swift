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
    func bumpDetectedNotification(data: CustomAccelerometerData)
    func saveExportData(data: DataForExport)
}

enum DistanceAlgorithm {
    case manhatan
    case euclidian
    case minski
}

class BumpDetectionAlgorithm {
    
    var userLocation: CLLocation?
    var delegate: BumpAlgorithmDelegate?
    var motionManager: CMMotionManager?
    var motionActivityManager: CMMotionActivityManager?
    var gyroItems = [CMRotationRate]()
    var countOfDetectedBumps = 0
    var isCalibrated = false
    let THRESHOLD = 4.5
    let THRESHOLD_USER_MOVEMENTS = 1.0
    let lastFewItemsCount = 60
    let ItemsFreqiency = 60.0
    var prevAttitude: CMAttitude?
    
    var isDriving = true
    
    var queue: OperationQueue
    var date: Date?
    var timer: Timer?

    var initialDeviceAttitude: CMAttitude?
    var windowAccelData = WindowAccelData(size: 60)
    
    //MARK: Initializers
    init(){
        motionManager = CMMotionManager()
        motionActivityManager = CMMotionActivityManager()
        queue = OperationQueue()
        queue.qualityOfService = .background
        queue.name = "DeviceMotionQueue"
        queue.maxConcurrentOperationCount = 1
    }

    //MARK: Bump detection algorithms
    
    func startAlgorithm() {
        //startMotionActivity()
        start()
    }
    
    func recognizeBump(for customData: CustomAccelerometerData){
        
        let window = self.windowAccelData
        let average_delta = window.getDeltaFromAverage(for: customData)
        let average_weigth_delta = window.getDeltaFromWeigthAverage(for: customData)
        window.add(element: customData)

        if average_delta > THRESHOLD && self.delegate != nil{
            print("INFO: Class BumpDetectionAlgorithm, call recognizeBump() - Bump detected")
            let requiredLocationAccuracy = 200.0//6.0 //hodnota v metroch
            if let location = self.userLocation {
                if (location.horizontalAccuracy.isLess(than: requiredLocationAccuracy)){
                    
                    let bump = BumpForServer(intensity: average_delta.description,
                                                latitude: location.coordinate.latitude.description,
                                                longitude: location.coordinate.longitude.description,
                                                manual: "0",
                                                text: "IOS app Auto-detect bump",
                                                type: "bump")
                    //Ulozenie objektu BumpForServer do Internej databázy
                    do {
                        print(bump.rating)
                        try bump.saveMeToInternDb()
                        DispatchQueue.main.async {
                            self.countOfDetectedBumps += 1
                            self.delegate!.bumpDetectedNotification(data: customData)
                        }
                        //let networkService = NetworkService()
                        //networkService.sendBumpToServer(bump: bump)
                    } catch {
                        print("ERROR: Class BumpDetectionAlgorithm, call recognizeBump() - Nepodarilo sa mi uloz detekovany vytlk do Internej Databazy")
                    }
                } else { print("WARNING: Class BumpDetectionAlgorithm, call recognizeBump() Presnost location: \(location.horizontalAccuracy)m nie je dostacujuca: \(requiredLocationAccuracy)m") }
            } else { print("WARNING: Class BumpDetectionAlgorithm, call recognizeBump() Nepoznam aktuálnu polohu") }
        }
    }
    
    func startDeviceMotionSensor(){
        if let motionManager = self.motionManager {
            if motionManager.isDeviceMotionAvailable {
                motionManager.deviceMotionUpdateInterval = TimeInterval(1.0/ItemsFreqiency)
                
                motionManager.startDeviceMotionUpdates(to: queue){(deviceMotion, error) in
                    guard let data = deviceMotion else { return }
                    if self.isDriving {
                        if (self.isDeviceStateChanging(state: data.attitude)) {
                            self.isCalibrated = false
                            NSLog("WARNING: POHYB ZARIADENIA, NEZAZNAMENAVAM OTRASY...")
                            self.initialDeviceAttitude = data.attitude
                            motionManager.deviceMotionUpdateInterval = TimeInterval(2.0)
                        }
                        else if(!self.isCalibrated){
                            self.windowAccelData = WindowAccelData(size: 60)
                            self.windowAccelData.setPriority(accelData: data)
                            motionManager.deviceMotionUpdateInterval = TimeInterval(1.0/self.ItemsFreqiency)
                            self.isCalibrated = true
                        }
                        else {
                            let customData = CustomAccelerometerData(accelerometerData: data, priority: self.windowAccelData.priority)
                            self.recognizeBump(for: customData)
                        }
                    }
                }
            }
        } else { print("WARNING: Nebol vytvorený objekt MotionManager.") }
    }
    func startMotionActivity(){
        if let motionActivityManager = self.motionActivityManager {
                motionActivityManager.startActivityUpdates(to: queue) {(deviceActivity) in
                    guard let data = deviceActivity else { return }
                    self.isDriving = data.automotive
                }
        } else { print("WARNING: Nebol vytvorený objekt MotionAcitivityManager.") }
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
    
    private var shouldRestartMotionUpdates = false
    
    func start() {
        self.shouldRestartMotionUpdates = true
        self.restartMotionUpdates()
    }
    
    func stop() {
        self.shouldRestartMotionUpdates = false
        self.motionManager?.stopDeviceMotionUpdates()
    }
    
    @objc private func appDidEnterBackground() {
        self.restartMotionUpdates()
    }
    
    @objc private func appDidBecomeActive() {
        self.restartMotionUpdates()
    }
    
    private func restartMotionUpdates() {
        guard self.shouldRestartMotionUpdates else { return }
        
        self.motionManager?.stopDeviceMotionUpdates()
        self.startDeviceMotionSensor()
    }
    var sum = 0.0
    var count = 0.0
//    func startDeviceNewMotionSensor(){
//        if let motionManager = self.motionManager {
//            if motionManager.isDeviceMotionAvailable {
//                motionManager.deviceMotionUpdateInterval = TimeInterval(1.0/ItemsFreqiency)
//                motionManager.startDeviceMotionUpdates(to: queue){(deviceMotion, error) in
//                    guard let deviceMotion = deviceMotion else { return }
//
//                    let gravity = deviceMotion.gravity
//                    let userAcceleration = deviceMotion.userAcceleration
//
//                    let userAccelerationAlongGravity = userAcceleration.x * gravity.x + userAcceleration.y * gravity.y + userAcceleration.z * gravity.z
//                    self.count += 1
//                    self.sum += userAccelerationAlongGravity
//                    print(self.sum/self.count)
//                }
//            }
//        } else { print("WARNING: Nebol vytvorený objekt MotionManager.") }
//    }
}
