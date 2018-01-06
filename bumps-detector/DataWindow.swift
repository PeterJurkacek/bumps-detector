//
//  DataWindow.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 4.1.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation

class DataWindow {
    var average: Double
    var sum: Double
    var fifo: [Double]
    var size: Int
    var queue: DispatchQueue
    
    init(size: Int) {
        self.average = 0.0
        self.fifo = Array<Double>()
        self.size = size
        self.sum = 0.0
        self.queue = DispatchQueue(label: "DataWindow queue")
        
    }
    
    func add(element: Double){
        queue.sync {
            self.fifo.append(element)
            sum += element
            
            if(!self.fifo.isEmpty){
                average = sum/Double(self.fifo.count)
            }
            
            if(size != 0 && self.fifo.count >= size){
                sum -= self.fifo[0]
                self.fifo.remove(at: 0)
            }
        }
    }
    
    func getAverage() -> Double{
        return queue.sync {
            self.average
        }
    }
}
