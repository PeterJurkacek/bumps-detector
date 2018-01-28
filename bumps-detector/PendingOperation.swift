//
//  PendingOperation.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 9.1.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import Foundation

class PendingOperation {
    
    private init() {}
    
    static let shared = PendingOperation()
    
    lazy var downloadsInProgress = [NSIndexPath:Operation]()
    lazy var downloadQueue:OperationQueue = {
        var queue = OperationQueue()
        queue.name = "Download queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    lazy var databaseInProgress = [NSIndexPath:Operation]()
    lazy var databaseQueue:OperationQueue = {
        var queue = OperationQueue()
        queue.qualityOfService = .background
        queue.name = "Image Database queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    lazy var accelerometerInProgress = [NSIndexPath:Operation]()
    lazy var accelerometerQueue:OperationQueue = {
        var queue = OperationQueue()
        queue.qualityOfService = .background
        queue.name = "Accelerometer data queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
}
