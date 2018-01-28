//
//  AccelerometerData.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 28.1.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import CoreMotion
import simd

/*
 * trieda slúži na odkladanie každého záznamu z akcelerometra
 * pricom sa ukladá aktuálna hodnota calibrácia/priority osí
 */
class CustomAccelerometerData {
    
    var accelerometerData: CMDeviceMotion
    var priority: double3
    var acceleration: double3 = [0.0,0.0,0.0]
    
    init(accelerometerData: CMDeviceMotion, priority: double3) {
        self.accelerometerData = accelerometerData
        self.priority = priority
        self.acceleration = [convert_g_to_ms2(from: accelerometerData.userAcceleration.x) * priority.x,
                             convert_g_to_ms2(from: accelerometerData.userAcceleration.y) * priority.y,
                             convert_g_to_ms2(from: accelerometerData.userAcceleration.z) * priority.z]
    }
    //Prevádza zrýchlenie v jednotkách G na ms^-2
    func convert_g_to_ms2(from gunit: Double) -> Double{
        return gunit * 9.80665
    }
}
