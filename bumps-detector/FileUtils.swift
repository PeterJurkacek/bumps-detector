//
//  FileUtils.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 26.10.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import Foundation
import simd

class FileUtils {
    
    var fileName: String?
    var path: NSURL?
    var csvText: String? 
    
    init(fileName name: String!) {
        self.fileName = name
        self.path = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(self.fileName!)! as NSURL
        self.csvText = "Timestamp,x,y,z\n"
    }
    
    func writeToFile(for tasks: [String:double3]){
        for task in tasks {
            let newLine = "\(task.key),\(task.value.x),\(task.value.y),\(task.value.z)\n"
            if csvText != nil {
                csvText?.append(contentsOf: newLine)
            }
        }
    }
    
    func saveFile(){
        do {
            try print("hello")//csvText!.write(to: path, atomically: true, encoding: NSUTF8StringEncoding)
        } catch {
            print("Failed to create file")
            print("\(error)")
        }
    }
}
