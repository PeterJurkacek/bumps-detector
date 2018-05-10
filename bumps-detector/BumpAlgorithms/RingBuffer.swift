//
//  RingBuffer.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 5.4.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//
// kod inspirovany - https://github.com/raywenderlich/swift-algorithm-club/tree/master/Ring%20Buffer

import UIKit

public class RingBuffer {
    var array: Array<Double>
    private var sum = 0.0
    private var count = 0
    private var writeIndex = 0
    private var size: Int
    
    public init(size: Int) {
        self.size = size
        self.array = [Double](repeating: 0.0, count: size)
    }
    
    public func write(element: Double){
        let index = writeIndex%size
        self.sum += element
        if count == size {
            self.sum -= self.array[index]
            self.writeIndex = 0
        }
        else {
            self.count+=1
        }
        self.array[index] = element
        self.writeIndex+=1
    }
    
    public func mean() -> Double {
        return self.sum/Double(self.count)
    }
    
}
