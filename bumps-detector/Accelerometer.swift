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
    let THRESHOLD = 4.6
    let lastFewItemsCount = 5
    let THRESHOLD_USERMOVEMENTS = 0.8
    var initialAttitude: CMAttitude?
    var timer: Timer?
    //Initializers
    init(){
        motionManager = CMMotionManager()
        logger = CMLogItem()
    }
    
    //MARK: Calibration Methods
    func calibrate(for accItem: CMAcceleration){
        let xms = accItem.x * ms
        let yms = accItem.y * ms
        let zms = accItem.z * ms
        
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
    
    func recognizeBump(for lastAccData: CMAcceleration){
        var delta = 0.0
        //Prevod jednotiek
        let xms = lastAccData.x * ms
        let yms = lastAccData.y * ms
        let zms = lastAccData.z * ms
        
        for temp in self.lastFewItems {
            //pre kazdu os X,Y,Z sa vypocita zmena zrychlenia
            let deltaX = abs((temp.x * ms) - xms)
            let deltaY = abs((temp.y * ms) - yms)
            let deltaZ = abs((temp.z * ms) - zms)
            
            
            //na zaklade priorit jednotlivych osi sa vypocita celkova zmena zrychlenia
            delta = self.priorityX * deltaX + self.priorityY * deltaY + self.priorityZ * deltaZ
            //NSLog("DELTA: \(delta)")
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
        //NSLog("\(lastAccData)")
        lastFewItems.append(lastAccData)
    }

    //MARK: Sensor Methods
    func startDeviceMotionSensor(){
        guard let motionManager = self.motionManager, motionManager.isDeviceMotionAvailable else
        {
            print("Zariadenie nepodporuje DeviceMotion")
            return
        }
        motionManager.deviceMotionUpdateInterval = TimeInterval(1.0/5)
        motionManager.startDeviceMotionUpdates()
        // Configure a timer to fetch the motion data.
        self.timer = Timer(fire: Date(), interval: (1.0/60.0), repeats: true,
                           block: { (timer) in
                            if let data = motionManager.deviceMotion {
                                // Get the attitude relative to the magnetic north reference frame.
                                self.processMotionData(data)
                            }
        })
        // Add the timer to the current run loop.
        RunLoop.current.add(self.timer!, forMode: .defaultRunLoopMode)
//        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main){(deviceMotion, error) in
//            if let data = deviceMotion{
//                print("ATTITUDE \(data.attitude.pitch), \(data.attitude.roll), \(data.attitude.yaw)")
//                //NSLog("GRAVITY: \(data.gravity.x * self.ms), \(data.gravity.y * self.ms), \(data.gravity.z * self.ms)")
//                if (self.isDeviceStateChanging(state: data.attitude)) {
//                    NSLog("POHYB ZARIADENIA, NEZAZNAMENAVAM OTRASY...")
//                    self.needCalibrate = true
//                }
//                else{
//                    if(self.needCalibrate){
//                        self.calibrate(for: data.gravity)
//                        self.needCalibrate = false
//                        self.initialAttitude = data.attitude
//                    }
//                    else{
//                        NSLog("ANALYZE BUMP")
//                            //self.recognizeBump(for: data.gravity)
//                        if(self.initialAttitude != nil){
//                            NSLog("ATTITUDE magnitude \(self.magnitude(from: self.initialAttitude!))")
//                            NSLog("ATTITUDE multiply \(data.attitude.multiply(byInverseOf: self.initialAttitude!))")
//                        }
//                    }
//                //NSLog("rotaionRate: \(data.rotationRate.x + data.rotationRate.y + data.rotationRate.z)")
//                }
//            }
//        }
    }
    
    func processMotionData(_ deviceMotion: CMDeviceMotion!){
        if let data = deviceMotion {
            print("ATTITUDE \(data.attitude.pitch), \(data.attitude.roll), \(data.attitude.yaw)")
            //NSLog("GRAVITY: \(data.gravity.x * self.ms), \(data.gravity.y * self.ms), \(data.gravity.z * self.ms)")
            if (self.isDeviceStateChanging(state: data.attitude)) {
                NSLog("POHYB ZARIADENIA, NEZAZNAMENAVAM OTRASY...")
                self.needCalibrate = true
            }
            else{
                if(self.needCalibrate){
                    self.calibrate(for: data.gravity)
                    self.needCalibrate = false
                    self.initialAttitude = data.attitude
                }
                else{
                    NSLog("ANALYZE BUMP")
                        //self.recognizeBump(for: data.gravity)
                    if(self.initialAttitude != nil){
                        NSLog("ATTITUDE magnitude \(self.magnitude(from: self.initialAttitude!))")
                        NSLog("ATTITUDE multiply \(data.attitude.multiply(byInverseOf: self.initialAttitude!))")
                    }
                }
            //NSLog("rotaionRate: \(data.rotationRate.x + data.rotationRate.y + data.rotationRate.z)")
            }
        }
    }
}
