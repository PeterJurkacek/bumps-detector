//
//  FileUtils.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 26.10.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import Foundation
import simd
import CoreMotion

class FileUtils {
    
    var fileName: String?
    var path: NSURL?
    var csvText: String?
    
    func createFileContent(allData: [(data: CMAccelerometerData, average: double3, sum: double3, variance: double3, priority: double3, delta: Double )]){
        var str = "DATUM,CAS,X,Y,Z,AVERAGE,X,Y,Z,SUM,X,Y,Z,VARIANCE,X,Y,Z,PRIORITY,X,Y,Z,,DELTA,\(allData.count)\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium
        
        for item in allData {
            
            let date = "\(dateFormatter.string(from: Date(timeIntervalSinceNow: item.data.timestamp)))"
            let time = "\(timeFormatter.string(from: Date(timeIntervalSinceNow: item.data.timestamp)))"
            let xyz  = "\(item.data.acceleration.x),\(item.data.acceleration.y),\(item.data.acceleration.z)"
            let average = "\(item.average.x),\(item.average.y),\(item.average.z)"
            let sum = "\(item.sum.x),\(item.sum.y),\(item.sum.z)"
            let variance = "\(item.variance.x),\(item.variance.y),\(item.variance.z)"
            let priority = "\(item.priority.x),\(item.priority.y),\(item.priority.z)"
            
            let newLine = "\(date),\(time),\(xyz),,\(average),,\(sum),,\(variance),,\(priority),,\(item.delta)\n"
            str.append(newLine)
        }
        let currentDate = Date()
        let fileName = "\(dateFormatter.string(from: currentDate))_\(timeFormatter.string(from: currentDate)).csv"
        
        saveToTxtFile(fileName: fileName,content: str)
    }
    
    func saveToTxtFile( fileName: String, content: String ) {
        let file = fileName //this is the file. we will write to and read from it
        
        let text = content //just a text
        
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let fileURL = dir.appendingPathComponent(file)
            
            //writing
            do {
                try text.write(to: fileURL, atomically: false, encoding: .utf8)
            }
            catch {/* error handling here */}
            
            //reading
            do {
                let text2 = try String(contentsOf: fileURL, encoding: .utf8)
                print(text2)
            }
            catch {/* error handling here */}
        }
    }
    
    func saveToJsonFile() {
        // Get the url of Persons.json in document directory
        guard let documentDirectoryUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let fileUrl = documentDirectoryUrl.appendingPathComponent("Persons.json")
        
        let personArray =  [["person": ["name": "Dani", "age": "24"]], ["person": ["name": "ray", "age": "70"]]]
        
        // Transform array into data and save it into file
        do {
            let data = try JSONSerialization.data(withJSONObject: personArray, options: [])
            try data.write(to: fileUrl, options: [])
        } catch {
            print(error)
        }
    }
    
    func clearTempFolder() {
        let fileManager = FileManager.default
        let tempFolderPath = NSTemporaryDirectory()
        do {
            let filePaths = try fileManager.contentsOfDirectory(atPath: tempFolderPath)
            for filePath in filePaths {
                try fileManager.removeItem(atPath: tempFolderPath + filePath)
            }
        } catch {
            print("Could not clear temp folder: \(error)")
        }
    }
}
