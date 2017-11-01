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

class Accelerometer{
    
    let logger: CMLogItem?
    var motionManager: CMMotionManager?
    var lastFewItems = [double3]()
    var priorityX :Double = 0.0
    var priorityY :Double = 0.0
    var priorityZ :Double = 0.0
    let ms = 9.81
    var isCalibrated = false
    let THRESHOLD = 5.0
    let lastFewItemsCount = 60
    let ItemsFreqiency = 60.0
    let THRESHOLD_USER_MOVEMENTS = 1.0
    var initialRotation: CMRotationRate?
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
        lastFewItems.removeAll()
    }
    
    func isDeviceStateChanging(state rotation :CMRotationRate, _ date: Date) -> Bool {
        if initialRotation == nil {
            self.initialRotation = rotation
        }
        let initMagnitude = magnitude(from: initialRotation!)
        let sum = abs(magnitude(from: rotation) - initMagnitude)
        self.zaznamyGyroskopu.append(date, sum, rotation.x, rotation.y, rotation.z, self.THRESHOLD_USER_MOVEMENTS)
        //NSLog("DEVICE STATE \(sum)")
        return (abs(sum) > THRESHOLD_USER_MOVEMENTS ? true : false)
    }

    //MARK: Bump detection algorithms
    func magnitude(from rotation: CMRotationRate) -> Double {
        return sqrt(pow(rotation.x, 2) + pow(rotation.y, 2) + pow(rotation.z, 2))
    }
    
    func detectBump(forLocation location: String, with delta: Double){
        NSLog("Idem detecovat bump")
        //sleep(4)
    }
    
    func recognizeBump(for data:double3, _ date: Date){
        var delta = 0.0
        let x = data.x
        let y = data.y
        let z = data.z
        
        var averageDelta = 0.0
        var nasiel_som_deltu = 0.0
        
        var bumpDetected = false
        for temp in self.lastFewItems {
            
            let deltaX = abs((temp.x ) - x)
            let deltaY = abs((temp.y ) - y)
            let deltaZ = abs((temp.z ) - z)
            
            //na zaklade priorit jednotlivych osi sa vypocita celkova zmena zrychlenia
            delta = self.priorityX * deltaX + self.priorityY * deltaY + self.priorityZ * deltaZ
            averageDelta = averageDelta + delta
            //ak je zmena vacsia ako THRESHOLD potom spusti detekciu vytlku
            if (nasiel_som_deltu == 0.0 && delta > THRESHOLD) {
                NSLog("NASIEL SOM BUMP: \(delta)")
                detectBump(forLocation: "location", with: delta)
                bumpDetected = true
                nasiel_som_deltu += delta
                //staci ak zmena zrychlenia prekrocila THRESHOLD raz, je to vytlk
            }
            
        }
        if(lastFewItems.count >= lastFewItemsCount){
            lastFewItems.remove(at: 0)
        }
        lastFewItems.append(data)
        self.zaznamyZAccelerometra.append((date, nasiel_som_deltu, averageDelta/Double(self.lastFewItems.count), data.x, data.y, data.z, self.THRESHOLD))
//        if !bumpDetected {
//            self.zaznamy.append((date, 0.0, 0.0, data.x, data.y, data.z))
//        }
//        else{
//           self.zaznamy.append((date, nasiel_som_deltu, averageDelta/Double(self.lastFewItems.count), data.x, data.y, data.z))
//        }
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
}
