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
    var period = Array<CMAccelerometerData>()
    var fifo = Array<CMAccelerometerData>()
    var min: CMAccelerometerData?
    var max: CMAccelerometerData?
    var size: Int
    var queue = DispatchQueue(label: "WindowAccelData queue")
    
    
    init(size: Int, accelData: CMAccelerometerData) {
        self.size = size
        setPriority(accelData: accelData)
    }
    
    func setPriority(accelData: CMAccelerometerData) {
        queue.sync {
            let xms = abs(accelData.acceleration.x)
            let yms = abs(accelData.acceleration.y)
            let zms = abs(accelData.acceleration.z)
            
            let sum = xms + yms + zms
            
            self.priority = [xms / sum, yms / sum, zms / sum]
        }
    }
    
    func add(element: CMAccelerometerData){
        queue.sync {
            self.fifo.append(element)
            //print("add: \(self.fifo.count)")
            updateVariance  ( for: element )
            updateSum       ( for: element )
            updateAverage   ( for: element )
            
            if(self.fifo.count > size){
                self.fifo.remove(at: 0)
            }
            
//            print("fifo Count: \(fifo.count)")
//            print("variance x: \(self.variance.x), sum x: \(self.sum.x), average x: \(self.average.x)")
//            print("variance y: \(self.variance.y), sum y: \(self.sum.y), average y: \(self.average.y)")
//            print("variance z: \(self.variance.z), sum z: \(self.sum.z), average z: \(self.average.z)")
//            print(" ")
        }
    }
    
    func calculatePeriod(for element: CMAccelerometerData){
        if !self.period.isEmpty {
        }
    }
    
    func changeSize(new size: Int){
        queue.sync {
            
            if self.fifo.count > size {
                minimazeFifo(new: size)
            }
            else {
                maximazeFifo(new: size)
            }
        }
    }
    
    private func minimazeFifo(new size: Int){
        
        var temp_fifo = Array<CMAccelerometerData>()
        let new_first_index = self.size - size
        
        for index in new_first_index..<self.size {
            temp_fifo.append(self.fifo[index])
        }
        
        self.fifo.removeAll()
        self.size = size
        self.sum        = [0.0,0.0,0.0]
        self.average    = [0.0,0.0,0.0]
        self.variance   = [0.0,0.0,0.0]
        
        for element in temp_fifo {
            self.add(element: element)
        }
    }
    
    private func maximazeFifo(new size: Int){
        self.size = size
    }
    
    //MARK: VARIANCE
    
    private func updateVariance(for element: CMAccelerometerData){
        //print("updateVariance: \(self.fifo.count)")
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
            
            if(size != 0 && self.fifo.count > size){
                let first_x_ms2 = convert_g_to_ms2(from: fifo[0].acceleration.x)
                let first_y_ms2 = convert_g_to_ms2(from: fifo[0].acceleration.y)
                let first_z_ms2 = convert_g_to_ms2(from: fifo[0].acceleration.z)
                
                let second_x_ms2 = convert_g_to_ms2(from: fifo[1].acceleration.x)
                let second_y_ms2 = convert_g_to_ms2(from: fifo[1].acceleration.y)
                let second_z_ms2 = convert_g_to_ms2(from: fifo[1].acceleration.z)
                
                variance.x -= abs(first_x_ms2 - second_x_ms2)
                variance.y -= abs(first_y_ms2 - second_y_ms2)
                variance.z -= abs(first_z_ms2 - second_z_ms2)

            }
        } else {
            print("ERROR updateVariance: Nie je dostatocný počet prvkov v poli")
        }
    }
    
    //MARK: SUM
    
    private func updateSum(for element: CMAccelerometerData){
        //print("updateSum: \(self.fifo.count)")
        //Započítaj nový element do budúceho výpočtu priemeru
        sum.x += convert_g_to_ms2(from: element.acceleration.x)
        sum.y += convert_g_to_ms2(from: element.acceleration.y)
        sum.z += convert_g_to_ms2(from: element.acceleration.z)
        
        //Odpočítaj starý element z budúceho výpočtu priemeru
        if(size != 0 && self.fifo.count > size){
            sum.x -= convert_g_to_ms2(from: self.fifo[0].acceleration.x)
            sum.y -= convert_g_to_ms2(from: self.fifo[0].acceleration.y)
            sum.z -= convert_g_to_ms2(from: self.fifo[0].acceleration.z)
        } else {
            print("ERROR updateSum: Počet prvkov v poli je menej \(size)")
        }
    }
    
    //MARK: AVERAGE
    
    private func updateAverage(for element: CMAccelerometerData){
        //print("updateAverage: \(self.fifo.count)")
        if(!self.fifo.isEmpty){
            let fifoCount = Double(self.fifo.count)
            //Zisti aktuálnu hodnotu priemeru fifo pola
            average  = [sum.x/fifoCount, sum.y/fifoCount, sum.z/fifoCount]
        } else {
            print("ERROR updateAverage: Pole je prázdne \(self.fifo.count)")
        }
    }
    
    //MARK: GETTERS
    func getDeltaOf(items count: Int) -> Double{
        return queue.sync {
            if(!fifo.isEmpty && self.fifo.count > count){
                let new_first_index = self.fifo.count - count
                
                var sum     : double3   = [0.0,0.0,0.0]
                
                for index in new_first_index..<self.fifo.count {
                    sum.x += self.fifo[index].acceleration.x
                    sum.y += self.fifo[index].acceleration.y
                    sum.z += self.fifo[index].acceleration.z
                }
                
                let doubleCount = Double(count)
                
                let sumX = abs(self.average.x - convert_g_to_ms2(from: sum.x/doubleCount)) * self.priority.x
                let sumY = abs(self.average.y - convert_g_to_ms2(from: sum.y/doubleCount)) * self.priority.y
                let sumZ = abs(self.average.z - convert_g_to_ms2(from: sum.z/doubleCount)) * self.priority.z
                
                return sumX + sumY + sumZ
                
            } else { return 0.0 }
        }
    }
    
    //Prevádza zrýchlenie v jednotkách G na ms^-2
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
    
    func getPriority() ->double3{
        return queue.sync {
            return self.priority
        }
    }
    
    func getDelta(for element: CMAccelerometerData) -> Double {
        
       return queue.sync {
            if(!fifo.isEmpty){
                let sumX = abs(average.x - convert_g_to_ms2(from: element.acceleration.x)) * self.priority.x
                let sumY = abs(average.y - convert_g_to_ms2(from: element.acceleration.y)) * self.priority.y
                let sumZ = abs(average.z - convert_g_to_ms2(from: element.acceleration.z)) * self.priority.z
                
                return sumX + sumY + sumZ
            }
            else { return 0.0 }
        }
        
    }
}
