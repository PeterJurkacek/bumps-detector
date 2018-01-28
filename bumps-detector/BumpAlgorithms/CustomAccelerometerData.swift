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
    
    var accelerometerData: CMAccelerometerData
    var priority: double3
    var accelerationWithPriority: double3
    
    init(accelerometerData: CMAccelerometerData, priority: double3) {
        self.accelerometerData = accelerometerData
        self.priority = priority
        self.accelerationWithPriority = [accelerometerData.acceleration.x * priority.x,
                                         accelerometerData.acceleration.y * priority.y,
                                         accelerometerData.acceleration.z * priority.z]
    }
}
