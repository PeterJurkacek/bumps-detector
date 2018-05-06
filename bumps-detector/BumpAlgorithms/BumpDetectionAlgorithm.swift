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
import Mapbox

protocol BumpAlgorithmDelegate {
    func bumpDetectedNotification(data: MGLPointAnnotation)
    func saveExportData(data: DataForExport)
    func notifyUser(manual: String, type: String)
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
    //FIXME: na 6
    let requiredLocationAccuracy = 6.0
    let ringBufferAccelerationData = RingBuffer(size: 60)
    let ringBufferMagnitudeData = RingBuffer(size: 60)
    
    var isDriving = false {
        didSet {
            if isDriving {
                guard let isDeviceMotionActive = self.motionManager?.isDeviceMotionActive else { return }
                if !isDeviceMotionActive {
                    start()
                }
            }
            else {
                guard let isDeviceMotionActive = self.motionManager?.isDeviceMotionActive else { return }
                if isDeviceMotionActive {
                    stop()
                }
            }
        }
    }
    
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
                            //self.recognizeBump(for: customData)
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
                    if !self.isDriving && data.automotive {
                        self.isDriving = true
                    }
                    if self.isDriving && !data.automotive {
                        self.isDriving = false
                    }
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
            let deltaMagnitude = calculateMagnitude(for: monitoringAttitude)
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
        self.startDeviceNewMotionSensor()
    }
    
    func startDeviceNewMotionSensor(){
        if let motionManager = self.motionManager {
            if motionManager.isDeviceMotionAvailable {
                motionManager.deviceMotionUpdateInterval = TimeInterval(1.0/ItemsFreqiency)
                motionManager.startDeviceMotionUpdates(to: queue){(lastData, error) in
                    guard let deviceMotion = lastData else { return }
                    //Ideme pracovat s posledne vráteným záznamom deviceMotion
                    
                    //Zistime si magnitude of vector via Pythagorean theorem
                    let magnitude = self.calculateMagnitude(for: deviceMotion.attitude)
                    
                    //Zistíme si delta(zmenu) posledneho magnitude of vector vzhľadom na priemernú magnitude of vector z ring buffera
                    let magnitudeDelta = self.ringBufferMagnitudeData.mean() - magnitude
                    
                    //Ulozime si novu hodnotu do ring buffera pre upravenie priemeru
                    self.ringBufferMagnitudeData.write(element: magnitude)
                    
                    //Pozorujeme ci pouzivatel hybe s telefonom
                    if abs(magnitudeDelta) < self.THRESHOLD_USER_MOVEMENTS {
                        
                        //Zistime si gravitacne zrychlenie telefonu
                        let userAccelerationAlongGravity = self.calculateUserAccelerationAlongGravity(deviceMotion: deviceMotion)
                    
                        //Zistíme si delta(zmenu) posledného zrýchlenia vzhľadom na priemernú hodnotu zrýchlení z ring buffera
                        let delta = self.ringBufferAccelerationData.mean() - userAccelerationAlongGravity
                    
                        //Ulozime si novu hodnotu do ring buffera pre upravnie priemeru
                        self.ringBufferAccelerationData.write(element: userAccelerationAlongGravity)
                        
                        //Zistíme, či sa jedná o výtlk
                        if delta >= self.THRESHOLD {
                            print(delta)
                            if let location = self.userLocation {
                                if location.horizontalAccuracy.isLess(than: self.requiredLocationAccuracy){
                                    //Detekovali sme vytlk tak ho musime spracovat
                                    self.processBump(delta: delta, location: location)
                                } else { print("WARNING: Nedostatocna presnost polohy: \(location.horizontalAccuracy), Required: \(self.requiredLocationAccuracy)") }
                            } else { print("WARNING: Nepoznam polohu") }
                        } //Sem spadne vzdy ked je otras prílis malý na to aby sme ho povazovali za vytlk
                    } else { print("WARNING: Rozpoznaný pohyb zariadenia.") }
                }
            }
        } else { print("WARNING: Nebol vytvorený objekt MotionManager.") }
    }
    
    func calculateUserAccelerationAlongGravity(deviceMotion: CMDeviceMotion!) -> Double {
        
        //Prevedieme si namerané zrýchlenie na metre za sekundu
        let userAccelerationInMs = convert_g_to_ms2(from: deviceMotion.userAcceleration)
        
        //Vynásobíme vektorom gravitácie
        let userAccelerationAlongGravity = userAccelerationInMs.x * deviceMotion.gravity.x + userAccelerationInMs.y * deviceMotion.gravity.y + userAccelerationInMs.z * deviceMotion.gravity.z
        
        return userAccelerationAlongGravity
    }
    
    //Pythagorean theorem
    func calculateMagnitude(for attitude: CMAttitude) -> Double {
        return sqrt(pow(attitude.roll, 2) + pow(attitude.yaw, 2) + pow(attitude.pitch, 2))
    }
    
    
    //Prevádza zrýchlenie v jednotkách G na ms^-2
    func convert_g_to_ms2(from gAcceleration: CMAcceleration) -> CMAcceleration{
        let constant = 9.80665
        let x_converted = gAcceleration.x * constant
        let y_converted = gAcceleration.y * constant
        let z_converted = gAcceleration.z * constant
        return CMAcceleration(x: x_converted, y: y_converted, z: z_converted)
    }
    
    func processBump(delta: Double, location: CLLocation, manual: String = "0", type: String = "0", text: String = "IOS app Auto-detect bump") {
        let realmService = RealmService()
        //Vytvor instanciu vytlku
        let newBump = BumpForServer(intensity: delta.description,
                                 latitude: location.coordinate.latitude.description,
                                 longitude: location.coordinate.longitude.description,
                                 manual: manual,
                                 text: text,
                                 type: type)
        
        //Ulozenie objektu BumpForServer do Internej databázy
        do {
            //Skontrolovanie ci sa objekt v internej DB uz nachádza
            if let bump = realmService.getObject(bump: newBump) {
                //Updatneme vytlk
                try realmService.update(oldBump: bump, newBump: newBump)
            }
            else {
                
                //Vložíme vytlk do DB
                try realmService.insert(bump: newBump)
                
                //Notifikujeme o detekcii delegata
                if let delegate = self.delegate {
                    let annotation = newBump.getAnnotation()
                    DispatchQueue.main.async {
                        delegate.bumpDetectedNotification(data: annotation)
                        delegate.notifyUser(manual: manual, type: type)
                        self.countOfDetectedBumps += 1
                    }
                } else { print("WARNING: BumpDetectionAlgorithm.delegate == nil") }
                
            }
        } catch {
            print("ERROR: Class BumpDetectionAlgorithm, call processBump() - Nepodarilo sa mi uloz detekovany vytlk do Internej Databazy")
        }
        
    }
    
}
