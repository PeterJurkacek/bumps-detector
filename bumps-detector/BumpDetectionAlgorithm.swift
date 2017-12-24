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

protocol BumpAlgorithmDelegation {
    func saveBump(data: double3, date: Date)
    func saveBumpInfoAs(tuple: (datum: Date, proces: Double, delta: Double, x: Double, y: Double, z: Double, threshold: Double))
}

enum DistanceAlgorithm {
    case manhatan
    case euclidian
    case minski
}

class BumpDetectionAlgorithm{
    
    var bumpAlgorithmDelegate: BumpAlgorithmDelegation!
    
    let logger: CMLogItem?
    var motionManager: CMMotionManager?
    var windowAllData = [double3]()
    var windowCalmData = [double3]()
    var gyroItems = [CMRotationRate]()
    var priorityX :Double = 0.0
    var priorityY :Double = 0.0
    var priorityZ :Double = 0.0
    let ms = 9.81
    var isCalibrated = false
    let THRESHOLD = 4.5
    let lastFewItemsCount = 60
    let ItemsFreqiency = 60.0
    let THRESHOLD_USER_MOVEMENTS = 3.0
    //var initialRotation: CMRotationRate?
    var timer: Timer?
    var queue: OperationQueue
    var queueRecognizeBump = DispatchQueue(label: "recognizeBumpsQueue", qos : .userInteractive)
    var zaznamyZAccelerometra = [(Date, Double, Double, Double, Double, Double, Double)]()
    var zaznamyGyroskopu = [(Date, Double, Double, Double, Double, Double)]()
    var date: Date?
    //MARK: Initializers
    init(){
        motionManager = CMMotionManager()
        logger = CMLogItem()
        queue = OperationQueue()
    }
    
    //MARK: Calibration Methods
    func get_g_Unit(for accData: CMAcceleration) -> double3 {
        let changedData: double3 = [(accData.x * ms), (accData.y * ms), (accData.z * ms)]
        return changedData
    }
    
    func calibrate(for accItem: double3){
        let xms = abs(accItem.x)
        let yms = abs(accItem.y)
        let zms = abs(accItem.z)
        
        let sum = xms + yms + zms
        
        self.priorityX = xms / sum
        self.priorityY = yms / sum
        self.priorityZ = zms / sum

        //print(self.priorityX + self.priorityY + self.priorityZ)
        windowAllData.removeAll()
    }
    
    func isDeviceStateChanging(state rotation :CMRotationRate, _ date: Date) -> Bool {
        
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
        
        let opositePriorityX = 1.0 - priorityX
        let opositePriorityY = 1.0 - priorityY
        let opositePriorityZ = 1.0 - priorityZ

        let sum = sumX*opositePriorityX + sumY*opositePriorityY + sumZ*opositePriorityZ
        
        self.zaznamyGyroskopu.append((date, sum, rotation.x, rotation.y, rotation.z, self.THRESHOLD_USER_MOVEMENTS))
        //NSLog("DEVICE STATE \(sum)")
        //print("\(sum)")
        return (sum > THRESHOLD_USER_MOVEMENTS ? true : false)
    }

    //MARK: Bump detection algorithms
 
    func magnitude(from rotation: double3) -> Double {
        
        let opositePriorityX = 1.0 - priorityX
        let opositePriorityY = 1.0 - priorityY
        let opositePriorityZ = 1.0 - priorityZ
        
        return sqrt(pow(rotation.x*opositePriorityX, 2) + pow(rotation.y*opositePriorityY, 2) + pow(rotation.z*opositePriorityZ, 2))
    }
    
    func detectBump(forLocation location: String, with delta: Double){
        NSLog("Idem detecovat bump")
        //sleep(4)
    }
    
    func getChangeBetween(lastData data: double3, window windowData: [double3]) -> Double{
        let x = data.x
        let y = data.y
        let z = data.z
        
        var deltaX = 0.0
        var deltaY = 0.0
        var deltaZ = 0.0
        
        for temp in windowData {
            
            deltaX = deltaX + (temp.x)
            deltaY = deltaY + (temp.y)
            deltaZ = deltaZ + (temp.z)
            
        }
        
        let windowCountDouble = Double(windowData.count)
        
        let averageData: double3 = [deltaX/windowCountDouble, deltaY/windowCountDouble, deltaZ/windowCountDouble]
        
        let sumX = abs(abs(averageData.x) - abs(x))
        let sumY = abs(abs(averageData.y) - abs(y))
        let sumZ = abs(abs(averageData.z) - abs(z))
        
        return  (self.priorityX * sumX + self.priorityY * sumY + self.priorityZ * sumZ)
    }
    
    func recognizeBump(for data:double3, _ date: Date){
        
        //Window1 -> all data
        var deltaAllData = 0.0
        
        if self.windowAllData.count >= lastFewItemsCount {
            deltaAllData = getChangeBetween(lastData: data, window: self.windowAllData)
            windowAllData.remove(at: 0)
        }
        windowAllData.append(data)
        
//        TODO: if deltaAllData > THRESHOLD {
//            DispatchQueue.main.async{
//                self.bumpAlgorithmDelegate.saveBump(data: data, date: date)
//            }
//        }
        DispatchQueue.main.async{
            self.bumpAlgorithmDelegate.saveBumpInfoAs(tuple: (datum: date, proces: 0.0, delta: deltaAllData, x: data.x, y: data.y, z: data.z, threshold: self.THRESHOLD))
        }
        
        //Window2 -> only calm data
        var deltaCalmData = 0.0
        
        if self.windowAllData.count >= lastFewItemsCount {
            deltaCalmData = getChangeBetween(lastData: data, window: self.windowCalmData)
            if(deltaCalmData < THRESHOLD) {
                windowCalmData.remove(at: 0)
                windowCalmData.append(data)
            }
        }
        else{
            windowCalmData.append(data)
        }

        self.zaznamyZAccelerometra.append((date, deltaCalmData, deltaAllData, data.x, data.y, data.z, self.THRESHOLD))
    }

    //MARK: Sensor Methods
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
                    self.zaznamyZAccelerometra.append((Date(timeIntervalSince1970: data.timestamp),0.0, 0.0, 0.0, 0.0, 0.0, self.THRESHOLD))
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
                            if let data = accelData{
                                if(!self.isCalibrated){
                                    
                                    self.zaznamyZAccelerometra.append((Date(timeIntervalSince1970: data.timestamp),-20.0, -20.0, data.acceleration.x * self.ms, data.acceleration.y * self.ms, data.acceleration.z * self.ms, self.THRESHOLD))
                                    self.calibrate(for: self.get_g_Unit(for: data.acceleration))
                                    self.isCalibrated = true
                                }
                                else{
                                    self.recognizeBump(for: self.get_g_Unit(for: data.acceleration), Date(timeIntervalSince1970: data.timestamp))
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
    
    func startAccelerationManager() {
        guard let motionManager = self.motionManager, motionManager.isAccelerometerAvailable else
        {
            print("Zariadenie nepodporuje Accelerometer")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            motionManager.accelerometerUpdateInterval = TimeInterval(1.0/self.ItemsFreqiency)
            motionManager.startAccelerometerUpdates()
        }
    }
    
    func stopAccelerationManager() {
        if self.motionManager != nil {
            self.motionManager!.stopAccelerometerUpdates()
        }
    }
    
    func startGyroManager() {
        guard let motionManager = self.motionManager, motionManager.isGyroAvailable else
        {
            print("Zariadenie nepodporuje Gyro")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            motionManager.gyroUpdateInterval = TimeInterval(1.0/self.ItemsFreqiency)
            motionManager.startGyroUpdates()
        }
    }
    
    func stopGyroManager() {
        if self.motionManager != nil {
            self.motionManager!.stopGyroUpdates()
        }
    }
}
