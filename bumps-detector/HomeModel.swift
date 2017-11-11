//
//  HomeModel.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 21.8.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import UIKit

protocol HomeModelProtocol: class {
    func itemsDownloaded(items: [Bump])
}

class HomeModel: NSObject, URLSessionDataDelegate{
    
    //properties
    
    weak var delegate: HomeModelProtocol!
    
    var data = Data()
    
    let urlPath: String = "http://localhost//sync_bump.php" //this will be changed to the path where service.php lives
    func downloadItems() {
        
        let url: URL = URL(string: urlPath)!
        let defaultSession = Foundation.URLSession(configuration: URLSessionConfiguration.default)
        
        let task = defaultSession.dataTask(with: url) { (data, response, error) in
            
            if error != nil {
                print("Failed to download data")
            }else {
                print("Data downloaded")
                self.parseJSON(data!)
            }
            
        }
        
        task.resume()
    }
    
    func parseJSON(_ data:Data) {
        
        var jsonResult = NSArray()
        
        do{
            jsonResult = try JSONSerialization.jsonObject(with: data, options:JSONSerialization.ReadingOptions.allowFragments) as! NSArray
            
        } catch let error as NSError {
            print(error)
            
        }
        
        var jsonElement = NSDictionary()
        var bumps = [Bump]()
        
        for i in 0 ..< jsonResult.count
        {
            
            jsonElement = jsonResult[i] as! NSDictionary
            
            //let bump = Bump()
            
            //the following insures none of the JsonElement values are nil through optional binding
//            if let intensity = jsonElement["intensity"] as? String,
//                let latitude = jsonElement["Latitude"] as? String,
//                let longitude = jsonElement["Longitude"] as? String
//            {
//                
//                bump.intensity = intensity
//                bump.latitude = latitude
//                bump.longitude = longitude
//                
//            }
            
           // bumps.append(bump)
            
        }
        
        DispatchQueue.main.async(execute: { () -> Void in
            
            self.delegate.itemsDownloaded(items: bumps)
        })
    }

}
