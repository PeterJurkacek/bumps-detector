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

protocol BumpAlgorithmDelegate: NSObjectProtocol{
    func saveBump(data: double3, date: Date)
    func saveBumpInfoAs(data: CMAccelerometerData, average: double3, sum: double3, variance: double3, priority: double3, delta: Double )
}

enum DistanceAlgorithm {
    case manhatan
    case euclidian
    case minski
}

class BumpDetectionAlgorithm{
    
    weak var bumpAlgorithmDelegate: BumpAlgorithmDelegate?
    
    var motionManager: CMMotionManager?
    var gyroItems = [CMRotationRate]()
    var isCalibrated = false
    let THRESHOLD = 4.5
    let lastFewItemsCount = 60
    let ItemsFreqiency = 60.0
    let THRESHOLD_USER_MOVEMENTS = 3.0
    var queue: OperationQueue
    var queueRecognizeBump = DispatchQueue(label: "recognizeBumpsQueue")
    var date: Date?
    var timer: Timer?
    
    var windowAccelData: WindowAccelData?
    
    //MARK: Initializers
    init(){
        motionManager = CMMotionManager()
        queue = OperationQueue()
        queue.qualityOfService = .utility
        queue.name = "BumpDetection Thread"
        queue.maxConcurrentOperationCount = 1
    }
    
    //MARK: Calibration Methods
    
    func isDeviceStateChanging(state rotation :CMRotationRate, _ date: Date) -> Bool {
        return queueRecognizeBump.sync {
            var deltaX = 0.0
            var deltaY = 0.0
            var deltaZ = 0.0
            
            for temp in self.gyroItems {
                
                deltaX = deltaX + (temp.x)
                deltaY = deltaY + (temp.y)
                deltaZ = deltaZ + (temp.z)
                
            }
            
            if(gyroItems.count >= lastFewItemsCount){
                gyroItems.remove(at: 0)
            }
            gyroItems.append(rotation)
            
            let gyroItemsDouble = Double(gyroItems.count)
            
            let averageData: double3 = [deltaX/gyroItemsDouble, deltaY/gyroItemsDouble, deltaZ/gyroItemsDouble]
            
            let sumX = abs(abs(averageData.x) - abs(rotation.x))
            let sumY = abs(abs(averageData.y) - abs(rotation.y))
            let sumZ = abs(abs(averageData.z) - abs(rotation.z))
            
            var opositePriority : double3 = [1.0, 1.0, 1.0]
            
            if let window = windowAccelData{
                opositePriority.x =  opositePriority.x - (window.getPriority().x)
                opositePriority.y =  opositePriority.x - (window.getPriority().y)
                opositePriority.z =  opositePriority.x - (window.getPriority().z)
            }
            let sum = sumX*opositePriority.x + sumY*opositePriority.y + sumZ*opositePriority.z
            
            return (sum > THRESHOLD_USER_MOVEMENTS ? true : false)
        }
    }
        
    //MARK: Bump detection algorithms
 
    func magnitude(from rotation: double3) -> Double {
        
        let opositePriorityX = 1.0 - (windowAccelData?.getPriority().x)!
        let opositePriorityY = 1.0 - (windowAccelData?.getPriority().y)!
        let opositePriorityZ = 1.0 - (windowAccelData?.getPriority().z)!
        
        return sqrt(pow(rotation.x*opositePriorityX, 2) + pow(rotation.y*opositePriorityY, 2) + pow(rotation.z*opositePriorityZ, 2))
    }
    
    func detectBump(forLocation location: String, with delta: Double){
        NSLog("Idem detecovat bump")
        //sleep(4)
    }
    
    func recognizeBump(for data: CMAccelerometerData, with window: WindowAccelData){
        
        let delta = window.getDelta(for: data)
        print("\(delta)")
        window.add(element: data)
        
//        TODO: if deltaAllData > THRESHOLD {
//            DispatchQueue.main.async{
//                self.bumpAlgorithmDelegate.saveBump(data: data, date: date)
//            }
//        }
        DispatchQueue.main.async{
            //if(self.bumpAlgorithmDelegate != nil){
                self.bumpAlgorithmDelegate?.saveBumpInfoAs(data: data, average: window.average, sum: window.sum, variance: window.variance, priority: window.priority, delta: delta)
            //}
        }
    }

    //MARK: Sensor Methods
    
    func startAccelerometer() {
        
        // Make sure the accelerometer hardware is available.
            if let motionManager = self.motionManager {
                if motionManager.isAccelerometerAvailable {
                    motionManager.accelerometerUpdateInterval = TimeInterval(1.0/self.ItemsFreqiency)
                    motionManager.startAccelerometerUpdates(to: self.queue){(accelData, error) in
                        if let data = accelData {
                            if(!self.isCalibrated){
                                self.windowAccelData = WindowAccelData(size: 60, accelData: data)
                                //self.calibrate(for: self.get_g_Unit(for: data.acceleration))
                                self.isCalibrated = true
                            }
                            else{
                                self.recognizeBump(for: data, with: self.windowAccelData!)
                            }
                            //NSLog("ACCEL \(data.acceleration)")
                        } else { print("Accelerometer nevrátil dáta.") }
                    }
                }else { print("Na zariadeni nie je dostupny akcelerometer.") }
            } else { print("Nebol vytvorený objekt MotionManager.") }
    }
    
    func startAccelGyro(){
        guard let motionManager = self.motionManager, motionManager.isAccelerometerAvailable, motionManager.isGyroAvailable else
        {
            print("Zariadenie neposkytuje Gyroscope alebo Accelerometer")
            return
        }
        motionManager.gyroUpdateInterval = TimeInterval(1.0/ItemsFreqiency)
        motionManager.startGyroUpdates(to: queue){(gyroData, error) in
            if let data = gyroData{
                if (self.isDeviceStateChanging(state: data.rotationRate, (Date(timeIntervalSince1970: data.timestamp)))) {
                    //Ak sa meni stav zariadenia stopni akcelerometer
                    if motionManager.isAccelerometerActive {
                        motionManager.stopAccelerometerUpdates()
                        self.isCalibrated = false
                    }
                }
                else {
                    if !motionManager.isAccelerometerActive {
                        motionManager.accelerometerUpdateInterval = TimeInterval(1.0/self.ItemsFreqiency)
                        motionManager.startAccelerometerUpdates(to: self.queue){(accelData, error) in
                            if let data = accelData {
                                if(!self.isCalibrated){
                                    self.windowAccelData = WindowAccelData(size: 60, accelData: data)
                                    //self.calibrate(for: self.get_g_Unit(for: data.acceleration))
                                    self.isCalibrated = true
                                }
                                else{
                                    self.recognizeBump(for: data, with: self.windowAccelData!)
                                }
                                //NSLog("ACCEL \(data.acceleration)")
                            }
                        }
                    }
                }
            }
        }
        print("Step Finish")
    }
}
