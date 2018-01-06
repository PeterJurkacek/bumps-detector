//
//  WindowAccelData.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 5.1.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation
import simd
import CoreMotion

class WindowAccelData {
    var priority: double3   = [0.0,0.0,0.0]
    var sum     : double3   = [0.0,0.0,0.0]
    var average : double3   = [0.0,0.0,0.0]
    var variance: double3   = [0.0,0.0,0.0]
    var fifo = Array<CMAccelerometerData>()
    var size: Int
    var queue = DispatchQueue(label: "WindowAccelData queue")
    
    
    init(size: Int, accelData: CMAccelerometerData) {
        self.size = size
        self.priority = getPriority(accelData: accelData)
    }
    
    func getPriority(accelData: CMAccelerometerData) -> double3{
        return queue.sync {
            let xms = abs(accelData.acceleration.x)
            let yms = abs(accelData.acceleration.y)
            let zms = abs(accelData.acceleration.z)
            
            let sum = xms + yms + zms
            
            return [xms / sum, yms / sum, zms / sum]
        }
    }
    
    func add(element: CMAccelerometerData){
        queue.sync {
            self.fifo.append(element)
            updateVariance  ( for: element )
            updateSum       ( for: element )
            updateAverage   ( for: element )
        }
    }
    
    private func updateVariance(for element: CMAccelerometerData){
        
        if(fifo.count > 1){
            let pre_last_x_ms2 = convert_g_to_ms2(from: fifo[fifo.count-2].acceleration.x)
            let pre_last_y_ms2 = convert_g_to_ms2(from: fifo[fifo.count-2].acceleration.y)
            let pre_last_z_ms2 = convert_g_to_ms2(from: fifo[fifo.count-2].acceleration.z)
            
            let last_x_ms2 = convert_g_to_ms2(from: fifo[fifo.count-1].acceleration.x)
            let last_y_ms2 = convert_g_to_ms2(from: fifo[fifo.count-1].acceleration.y)
            let last_z_ms2 = convert_g_to_ms2(from: fifo[fifo.count-1].acceleration.z)
            
            variance.x += abs(pre_last_x_ms2 - last_x_ms2)
            variance.y += abs(pre_last_y_ms2 - last_y_ms2)
            variance.z += abs(pre_last_z_ms2 - last_z_ms2)
        } else {
            print("ERROR updateVariance: Nie je dostatocný počet prvkov v poli")
        }
    }
    
    private func updateSum(for element: CMAccelerometerData){
        
        //Započítaj nový element do budúceho výpočtu priemeru
        sum.x += convert_g_to_ms2(from: element.acceleration.x)
        sum.y += convert_g_to_ms2(from: element.acceleration.y)
        sum.z += convert_g_to_ms2(from: element.acceleration.z)
        
        //Odpočítaj starý element z budúceho výpočtu priemeru
        if(size != 0 && self.fifo.count >= size){
            sum.x -= convert_g_to_ms2(from: self.fifo[0].acceleration.x)
            sum.y -= convert_g_to_ms2(from: self.fifo[0].acceleration.y)
            sum.z -= convert_g_to_ms2(from: self.fifo[0].acceleration.z)
            self.fifo.remove(at: 0)
        } else {
            print("ERROR updateSum: Počet prvkov v poli je menej \(size)")
        }
    }
    
    private func updateAverage(for element: CMAccelerometerData){
        
        if(!self.fifo.isEmpty){
            let fifoCount = Double(self.fifo.count)
            //Zisti aktuálnu hodnotu priemeru fifo pola
            average  = [sum.x/fifoCount, sum.y/fifoCount, sum.z/fifoCount]
        } else {
            print("ERROR updateAverage: Pole je prázdne \(self.fifo.count)")
        }
    }
    
    //Prevádza zrýchlenie v jednotkách G na ms
    func convert_g_to_ms2(from gunit: Double) -> Double{
        return gunit * 9.80665
    }
    
    func getAverage() -> double3{
        return queue.sync {
            return self.average
        }
    }
    
    func getSum() -> double3{
        return queue.sync {
            return self.sum
        }
    }
    
    func getVariance() -> double3{
        return queue.sync {
            return self.variance
        }
    }
    
    func getDelta(for element: CMAccelerometerData) -> Double {
        
        return queue.sync {
            let sumX = abs(average.x - element.acceleration.x) * self.priority.x
            let sumY = abs(average.y - element.acceleration.y) * self.priority.y
            let sumZ = abs(average.z - element.acceleration.z) * self.priority.z
            
            return sumX + sumY + sumZ
        }
    }
}
