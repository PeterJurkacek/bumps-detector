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

class Accelerometer{
    //MARK: Fields
    let logger: CMLogItem?
    var motionManager: CMMotionManager?
    var lastFewItems = [CMAcceleration]()
    var priorityX :Double = 0.0
    var priorityY :Double = 0.0
    var priorityZ :Double = 0.0
    let ms = 9.81
    var needCalibrate = true
    let THRESHOLD = 0.08
    let lastFewItemsCount = 60
    let ItemsFreqiency = 60.0
    let THRESHOLD_USERMOVEMENTS = 0.8
    var initialAttitude: CMAttitude?
    var timer: Timer?
    var queue: OperationQueue
    var queueRecognizeBump = DispatchQueue(label: "recognizeBumpsQueue", qos : .userInteractive)
    //Initializers
    init(){
        motionManager = CMMotionManager()
        logger = CMLogItem()
        queue = OperationQueue()
    }
    
    //MARK: Calibration Methods
    func calibrate(for accItem: CMAcceleration){
        let xms = (accItem.x)
        let yms = (accItem.y)
        let zms = (accItem.z)
        
        var sum = xms + yms + zms
        let priorityX = abs(xms / sum)
        let priorityY = abs(yms / sum)
        let priorityZ = abs(zms / sum)
        //NSLog("Sum: \(sum), priorityX \(priorityX), priorityY \(priorityY), priorityZ \(priorityZ)")
        //normalizacia
        sum = priorityX + priorityY + priorityZ
        self.priorityX = priorityX / sum;
        self.priorityY = priorityY / sum;
        self.priorityZ = priorityZ / sum;
        lastFewItems.removeAll()
        //NSLog("Sum: \(sum), priorityX \(self.priorityX), priorityY \(self.priorityY), priorityZ \(self.priorityZ)")
    }
    
    func isDeviceStateChanging(state rotation :CMRotationRate) -> Bool {
        let sum = abs(rotation.x) + abs(rotation.y) + abs(rotation.z)
        //print("\(sum) = \(rotation.x) + \(rotation.y) + \(rotation.z)")
        return (abs(sum) > THRESHOLD_USERMOVEMENTS ? true : false)
    }
    func isDeviceStateChanging(state attitude :CMAttitude) -> Bool {
        if initialAttitude != nil {
            let initMagnitude = magnitude(from: initialAttitude!)
            let sum = abs(magnitude(from: attitude) - initMagnitude)
            //NSLog("SUM \(sum)")
            return sum > THRESHOLD_USERMOVEMENTS ? true: false
        }
        return false
    }

    //MARK: Bump detection algorithms
    func magnitude(from attitude: CMAttitude) -> Double {
        return sqrt(pow(attitude.roll, 2) + pow(attitude.yaw, 2) + pow(attitude.pitch, 2))
    }
    
    func detectBump(forLocation location: String, with delta: Double){
        NSLog("Idem detecovat bump")
        //sleep(4)
    }
    
    func recognizeBump(for lastAccData: CMAcceleration, lastUserAccel: CMAcceleration){
        var delta = 0.0
        //Prevod jednotiek
        let xms = lastAccData.x
        let yms = lastAccData.y
        let zms = lastAccData.z
        
        var max_diffrence = 0.0
        
        for temp in self.lastFewItems {
            //NSLog("\(lastAccData)")
            //pre kazdu os X,Y,Z sa vypocita zmena zrychlenia
            let deltaX = abs((temp.x ) - xms)
            let deltaY = abs((temp.y ) - yms)
            let deltaZ = abs((temp.z ) - zms)
            
            NSLog("\(temp.x) \(temp.y) \(temp.z)")
            NSLog("\(xms) \(yms) \(zms)")
            //na zaklade priorit jednotlivych osi sa vypocita celkova zmena zrychlenia
            delta = self.priorityX * deltaX + self.priorityY * deltaY + self.priorityZ * deltaZ
            //NSLog("\(self.priorityX) \(self.priorityY) \(self.priorityZ)")
            //NSLog("DELTA: \(delta)")
            //ak je zmena vacsia ako THRESHOLD potom spusti detekciu vytlku
            if (delta > THRESHOLD) {
                NSLog("NASIEL SOM BUMP: \(delta)")
                max_diffrence = delta
                detectBump(forLocation: "location", with: delta)
                //staci ak zmena zrychlenia prekrocila THRESHOLD raz, je to vytlk
                break
            }
        }
        if(lastFewItems.count >= lastFewItemsCount){
            lastFewItems.remove(at: 0)
        }
        lastFewItems.append(lastAccData)
        //NSLog("\(max_diffrence)")
    }

    //MARK: Sensor Methods
    func startDeviceMotionSensor(){
        guard let motionManager = self.motionManager, motionManager.isDeviceMotionAvailable else
        {
            print("Zariadenie nepodporuje DeviceMotion")
            return
        }
        motionManager.deviceMotionUpdateInterval = TimeInterval(1.0/ItemsFreqiency)
        motionManager.startDeviceMotionUpdates(to: queue){(deviceMotion, error) in
            if let data = deviceMotion{
                self.processMotionData(data)
            }
        }
        print("Step Finish")
    }
    
    func startAccelerometerSensor(){
        guard let motionManager = self.motionManager, motionManager.isAccelerometerAvailable else
        {
            print("Zariadenie nepodporuje DeviceMotion")
            return
        }
        motionManager.accelerometerUpdateInterval = TimeInterval(1.0/ItemsFreqiency)
        motionManager.startAccelerometerUpdates(to: queue){(deviceMotion, error) in
            if let data = deviceMotion{
                self.processAccelData(data)
            }
        }
    }
    
    func processAccelData(_ deviceAccel: CMAccelerometerData!){
        if let data = deviceAccel {
            NSLog("\(data.acceleration.x * ms), \(data.acceleration.y * ms), \(data.acceleration.z * ms)")
        }
    }
    
    func processMotionData(_ deviceMotion: CMDeviceMotion!){
        if let data = deviceMotion {
            DispatchQueue.global().sync {
                if self.initialAttitude == nil {
                    self.initialAttitude = data.attitude
                }
                //NSLog("BEFORE MAGNITUDE: \(self.magnitude(from: data.attitude))")
                //data.attitude.multiply(byInverseOf: self.initialAttitude!)
                //NSLog("AFTER MAGNITUDE: \(self.magnitude(from: data.attitude))")
                //NSLog("GRAVITY: \(data.gravity.x * self.ms), \(data.gravity.y * self.ms), \(data.gravity.z * self.ms)")
                if (self.isDeviceStateChanging(state: data.attitude)) {
                    NSLog("POHYB ZARIADENIA, NEZAZNAMENAVAM OTRASY...")
                    self.motionManager?.deviceMotionUpdateInterval = TimeInterval(2.0)
                    self.initialAttitude = data.attitude
                    self.needCalibrate = true
                }
                else{
                    if(self.needCalibrate){
                        //NSLog("CALIBRATION START...")
                        self.calibrate(for: data.gravity)
                        self.needCalibrate = false
                        if self.initialAttitude != nil {
                            self.initialAttitude = data.attitude
                            //NSLog("OLD VALUE: \(self.magnitude(from: self.initialAttitude!))")
                        }
                        //NSLog("NEW VALUE: \(self.magnitude(from: self.initialAttitude!))")
                        //NSLog("CALIBRATION FINISH...")
                        self.motionManager?.deviceMotionUpdateInterval = TimeInterval(1.0/ItemsFreqiency)
                    }
                    else{
                        //NSLog("ANALYZE START...")
                        self.recognizeBump(for: data.gravity, lastUserAccel: data.userAcceleration)

                        //NSLog("ANALYZE FINISH...")
                    }
                }
            }
        }
    }
}
