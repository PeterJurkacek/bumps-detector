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

protocol BumpAlgorithmDelegate: class {
    func bumpDetectedNotification(data: MGLPointAnnotation)
    func saveExportData(data: DataForExport)
    func notifyUser(manual: String, type: String)
}

class BumpDetectionAlgorithm : NSObject{
    
    var userLocation: CLLocation?
    weak var delegate: BumpAlgorithmDelegate?
    var motionManager: CMMotionManager?
    var motionActivityManager: CMMotionActivityManager?
    var gyroItems = [CMRotationRate]()
    var countOfDetectedBumps = 0
    var isCalibrated = false
    let THRESHOLD = 4.5
    let THRESHOLD_USER_MOVEMENTS = 0.8
    let lastFewItemsCount = 60
    let ItemsFreqiency = 60.0
    var prevAttitude: CMAttitude?
    //FIXME: na 6
    let requiredLocationAccuracy = 6.0
    let ringBufferAccelerationData = RingBuffer(size: 60)
    let ringBufferMagnitudeData = RingBuffer(size: 2)
    
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
    
    var deviceMotionQueue = OperationQueue()
    var date: Date?
    var timer: Timer?

    var initialDeviceAttitude: CMAttitude?
    var windowAccelData = WindowAccelData(size: 60)
    
    //MARK: Initializers
    init(_: Int = 0){
        super.init()
        motionManager = CMMotionManager()
        motionActivityManager = CMMotionActivityManager()
        deviceMotionQueue.qualityOfService = .background
        deviceMotionQueue.name = "DeviceMotionQueue"
        deviceMotionQueue.maxConcurrentOperationCount = 1
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
                
                motionManager.startDeviceMotionUpdates(to: deviceMotionQueue){(deviceMotion, error) in
                    guard let data = deviceMotion else { return }
                    if self.isDriving {
                        if (self.isDeviceAttitudeChanging(state: data.attitude)) {
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
                motionActivityManager.startActivityUpdates(to: deviceMotionQueue) {(deviceActivity) in
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
    
    func isDeviceAttitudeChanging(state attitude :CMAttitude) -> Bool {
        
        guard let previousAttitude = self.initialDeviceAttitude else { return false }
        
        //Vypočítaj zmenu uhla naklonenia zariadenia okolo X-osi, tzv. TopToBottom
        let deltaRoll = abs(previousAttitude.roll-attitude.roll)
        //print("deltaRoll: \(deltaRoll)")
        if deltaRoll > THRESHOLD_USER_MOVEMENTS {
            print("deltaRoll: \(deltaRoll)")
            return true
        }
        //Vypočítaj zmenu uhla nakolonenia zariadenia okolo Z-osi
        let deltaYaw = abs(previousAttitude.yaw-attitude.yaw)
        //print("deltaYaw: \(deltaYaw)")
        if deltaYaw > THRESHOLD_USER_MOVEMENTS {
            print("deltaYaw: \(deltaYaw)")
            return true
        }
        //Vypočítaj zmenu uhla nakolonenia zariadenia okolo Y-osi, tzv. SideToSide
        let deltaPitch = abs(previousAttitude.pitch-attitude.pitch)
        //print("deltaPitch: \(deltaPitch)")
        if deltaPitch > THRESHOLD_USER_MOVEMENTS {
            print("deltaPitch: \(deltaPitch)")
            return true
        }
        
        //Informuj volajúceho, že zariadenie je v pokoji
        return false
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
                motionManager.startDeviceMotionUpdates(to: deviceMotionQueue){(lastData, error) in
                    //Ideme pracovat s posledne vráteným záznamom deviceMotion
                    guard let deviceMotion = lastData else { return }
                    //let data = RawDataSet(data: deviceMotion)
                    //Kontrolujem ci pouzivatel hybe s telefonom
                    if self.initialDeviceAttitude != nil && !self.isDeviceAttitudeChanging(state: deviceMotion.attitude){
                        
                        //Zistime si gravitacne zrychlenie telefonu
                        let userAccelerationAlongGravity = self.calculateUserAccelerationAlongGravity(deviceMotion: deviceMotion)
                    
                        //Počítam zmenu zrýchlenia si posledného záznamu vzhľadom na priemernú hodnotu zrýchlení z RingBuffer
                        let zmenaZrychlenia = self.ringBufferAccelerationData.mean() - userAccelerationAlongGravity
                    
                        //Ulozime si novu hodnotu do ring buffera pre upravnie priemeru
                        self.ringBufferAccelerationData.write(element: userAccelerationAlongGravity)
                        
                        //Ak je zmena zrýchlenia väčšia ako prahová hodnota
                        if zmenaZrychlenia >= self.THRESHOLD {
                            
                            //Ak poznám aktuálnu geografickú polohu zariadenia
                            if let location = self.userLocation {
                                //Ak je presnosť polohy > požadovaná presnosť
                                if location.horizontalAccuracy.isLess(than: self.requiredLocationAccuracy){
                                    //Detekoval som vytlk
                                    self.processBump(delta: zmenaZrychlenia, location: location)
                                    //data.isBump = true
                                } else { print("WARNING: Nedostatocna presnost polohy: \(location.horizontalAccuracy), Required: \(self.requiredLocationAccuracy)") }
                            } else { print("WARNING: Nepoznam polohu") }
                        } //Zmena zrýchlenia je príliš malá na to aby sme ho povazovali za vytlk
                    } else {
                        //Nastavenie východzej polohy zariadenia
                        //data.isUserMovement = true
                        self.initialDeviceAttitude = deviceMotion.attitude
                        print("WARNING: Rozpoznaný pohyb zariadenia.")
                    }
//                    do {
//                        try data.saveMeToInternDb()
//                    }catch {
//                        print("INSERT ERROR")
//                    }
                    
                }
            }
        } else { print("WARNING: Nebol vytvorený objekt MotionManager.") }
    }
    
    func calculateUserAccelerationAlongGravity(deviceMotion: CMDeviceMotion!) -> Double {
        
        //Preved si namerané zrýchlenie na metre za sekundu
        let userAccelerationInMs = convert_g_to_ms2(from: deviceMotion.userAcceleration)
        
        //Vynásob vektorom gravitácie
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
