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
    
    //MARK: Fields
    let logger: CMLogItem?
    var motionManager: CMMotionManager?
    var lastFewItems = [double3]()
    var priorityX :Double = 0.0
    var priorityY :Double = 0.0
    var priorityZ :Double = 0.0
    let ms = 9.81
    var needCalibrate = true
    let THRESHOLD = 5.0
    let lastFewItemsCount = 60
    let ItemsFreqiency = 60.0
    let THRESHOLD_USERMOVEMENTS = 1.0
    var initialRotation: CMRotationRate?
    var timer: Timer?
    var queue: OperationQueue
    var queueRecognizeBump = DispatchQueue(label: "recognizeBumpsQueue", qos : .userInteractive)
    
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
        let xms = (accItem.x)
        let yms = (accItem.y)
        let zms = (accItem.z)
        
        var sum = xms + yms + zms
        let priorityX = abs(xms / sum)
        let priorityY = abs(yms / sum)
        let priorityZ = abs(zms / sum)

        //normalizacia
        sum = priorityX + priorityY + priorityZ
        self.priorityX = priorityX / sum;
        self.priorityY = priorityY / sum;
        self.priorityZ = priorityZ / sum;
        lastFewItems.removeAll()
    }
    
    func isDeviceStateChanging(state rotation :CMRotationRate) -> Bool {
        if initialRotation == nil {
            self.initialRotation = rotation
        }
        let initMagnitude = magnitude(from: initialRotation!)
        let sum = abs(magnitude(from: rotation) - initMagnitude)
        //NSLog("DEVICE STATE \(sum)")
        return (abs(sum) > THRESHOLD_USERMOVEMENTS ? true : false)
    }

    //MARK: Bump detection algorithms
    func magnitude(from rotation: CMRotationRate) -> Double {
        return sqrt(pow(rotation.x, 2) + pow(rotation.y, 2) + pow(rotation.z, 2))
    }
    
    func detectBump(forLocation location: String, with delta: Double){
        NSLog("Idem detecovat bump")
        //sleep(4)
    }
    
    func recognizeBump(for data:double3){
        var delta = 0.0
        
        let x = data.x
        let y = data.y
        let z = data.z
        
        for temp in self.lastFewItems {
            
            let deltaX = abs((temp.x ) - x)
            let deltaY = abs((temp.y ) - y)
            let deltaZ = abs((temp.z ) - z)
            
            //na zaklade priorit jednotlivych osi sa vypocita celkova zmena zrychlenia
            delta = self.priorityX * deltaX + self.priorityY * deltaY + self.priorityZ * deltaZ
            
            //ak je zmena vacsia ako THRESHOLD potom spusti detekciu vytlku
            if (delta > THRESHOLD) {
                NSLog("NASIEL SOM BUMP: \(delta)")
                detectBump(forLocation: "location", with: delta)
                //staci ak zmena zrychlenia prekrocila THRESHOLD raz, je to vytlk
                break
            }
        }
        if(lastFewItems.count >= lastFewItemsCount){
            lastFewItems.remove(at: 0)
        }
        lastFewItems.append(data)
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
                if (self.isDeviceStateChanging(state: data.rotationRate)) {
                    //Ak sa meni stav zariadenia stopni akcelerometer
                    if motionManager.isAccelerometerActive {
                        motionManager.stopAccelerometerUpdates()
                        self.needCalibrate = true
                    }
                }
                else {
                    if !motionManager.isAccelerometerActive {
                        motionManager.accelerometerUpdateInterval = TimeInterval(1.0/self.ItemsFreqiency)
                        motionManager.startAccelerometerUpdates(to: self.queue){(accelData, error) in
                            if let data = accelData{
                                if(self.needCalibrate){
                                    self.calibrate(for: self.get_g_Unit(for: data.acceleration))
                                    self.needCalibrate = false
                                }
                                else{
                                    self.recognizeBump(for: self.get_g_Unit(for: data.acceleration))
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
