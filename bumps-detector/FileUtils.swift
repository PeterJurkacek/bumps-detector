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
    var dataForExport = [DataForExport]()

    
    func createFile(){
        var str = "DATUM,CAS,ACC_X,ACC_Y,ACC_Z,AVG_X,AVG_Y,AVG_Z,SUM_X,SUM_Y,SUM_Z,AVGW_X,AVGW_Y,AVGW_Z,SUMW_X,SUMW_Y,SUMW_Z,VAR_X,VAR_Y,VAR_Z,ACCW_X,ACCW_Y,ACCW_Z,AVERAGE_DELTA,WEIGTH_AVERAGE_DELTA,\(dataForExport.count)\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .medium
        
        for item in dataForExport {
            
            let date = "\(dateFormatter.string(from: Date(timeIntervalSinceNow: (item.customAccelData!.accelerometerData.timestamp))))"
            let time = "\(timeFormatter.string(from: Date(timeIntervalSinceNow: (item.customAccelData!.accelerometerData.timestamp))))"
            let xyz  = "\(item.customAccelData!.acceleration.x),\(item.customAccelData!.acceleration.y),\(item.customAccelData!.acceleration.z)"
            let average = "\(item.average!.x),\(item.average!.y),\(item.average!.z)"
            let sum = "\(item.sum!.x),\(item.sum!.y),\(item.sum!.z)"
            let weigth_average = "\(item.weigth_average!.x),\(item.weigth_average!.y),\(item.weigth_average!.z)"
            let weigth_sum = "\(item.weigth_sum!.x),\(item.weigth_sum!.y),\(item.weigth_sum!.z)"
            let variance = "\(item.variance!.x),\(item.variance!.y),\(item.variance!.z)"
            let priority = "\(item.priority!.x),\(item.priority!.y),\(item.priority!.z)"
            
            let newLine = "\(date),\(time),\(xyz),\(average),\(sum),\(weigth_average),\(weigth_sum),\(variance),\(priority),\(item.average_delta!),\(item.weigth_average_delta!)\n"
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
//            do {
//                let text2 = try String(contentsOf: fileURL, encoding: .utf8)
//                print(text2)
//            }
//            catch {/* error handling here */}
            print("INFO: All data save to file \(file.description)")
        } else { print("Error: saveToTxtFile")}
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
