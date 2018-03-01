//
//  DataForExport.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 28.2.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import CoreMotion
import simd

class DataForExport {
    
    let customAccelData: CustomAccelerometerData?
    let average: double3?
    let average_delta: Double?
    let sum: double3?
    let variance: double3?
    let weigth_average: double3?
    let weigth_sum: double3?
    let weigth_average_delta: Double?
    let priority: double3?
    
    init (customAccelData: CustomAccelerometerData
        ,average: double3
        ,average_delta: Double
        ,sum: double3
        ,variance: double3
        ,weigth_average: double3
        ,weigth_sum: double3
        ,weigth_average_delta: Double
        ,priority: double3) {
        
        self.customAccelData = customAccelData
        self.average = average
        self.average_delta = average_delta
        self.sum = sum
        self.variance = variance
        self.weigth_average = weigth_average
        self.weigth_sum = weigth_sum
        self.weigth_average_delta = weigth_average_delta
        self.priority = priority
    }
}
