//
//  HomeModel.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 21.8.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import UIKit
import CoreLocation

struct ServerServices {
    static let create_bump = "http://vytlky.fiit.stuba.sk//create_bump.php"
    static let get_image = "http://vytlky.fiit.stuba.sk//get_image.php"
    static let get_image_id = "http://vytlky.fiit.stuba.sk//get_image_id.php"
    static let sync_bump = "http://vytlky.fiit.stuba.sk//sync_bump.php"
    static let update_image = "http://vytlky.fiit.stuba.sk//update_image.php"
}

protocol NetworkServiceDelegate: class {
    func itemsDownloaded()
}

class NetworkService: NSObject {
    
    //properties
    
    weak var delegate: NetworkServiceDelegate!
    
    func param(name: String, value: String){
        
    }
    
    func downloadBumpsFromServer( coordinate: CLLocationCoordinate2D, net: Int ){
        // 1
        let queue = DispatchQueue.global()
        // 2
        queue.async {
            var request = URLRequest(url: URL(string: ServerServices.sync_bump)!)
            request.httpMethod = "POST"
            
//            let postString = "date=2017-10-13+14%3A32%3A31&latitude=48.1607117&longitude=17.0958196&listID=4&listDate=2015-04-19+14%3A30%3A22&listCount=2&net=1"
//             let postString = "date=2017-10-13+14%3A32%3A31&latitude=48.1607117&longitude=17.0958196&net=1"
//            let postString = "date=2017-10-13 14:32:31&latitude=48.1607117&longitude=17.0958196&net=1"
//
//            let postString = "date=2017-10-13+14%3A32%3A31&latitude=48.1607117&longitude=17.0958196&listID=4@5&listDate=2015-04-19+14%3A30%3A22@2015-04-19 14:30:22&listCount=2@2&net=1"
            
//            request.httpBody = postString.data(using: .utf8)
            let parameters = self.createParams(coordinate: coordinate, net: net)
            request.httpBody = parameters.data(using: .utf8)
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {                                                 // check for fundamental networking error
                    print("error=\(String(describing: error))")
                    return
                }
                
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                    print("response = \(String(describing: response))")
                    
                }
                //SWIFT 4.0 JSONparsing
                do {
                    let syncBump = try JSONDecoder().decode(SyncBump.self, from: data)
                    print(syncBump.bumps)
                    print("POCET: \(syncBump.bumps.count)")
                    let realm = RealmService()
                    for item in syncBump.bumps {
                        let newBump = BumpFromServer(latitude: (item.latitude as NSString).doubleValue,
                                                     longitude: (item.longitude as NSString).doubleValue,
                                                     count: (item.count as NSString).integerValue,
                                                     b_id: item.b_id,
                                                     rating: item.rating,
                                                     manual: item.manual,
                                                     type: item.type,
                                                     fix: item.fix,
                                                     admin_fix: item.admin_fix,
                                                     info: item.info,
                                                     last_modified: item.last_modified)
                        realm.createOrUpdate(newBump)
                    }
                    DispatchQueue.main.async {
                        self.delegate.itemsDownloaded()
                    }
                }catch{
                    print("Chyba pri JSon parsingu: Skontroluj ci parametre struktur zodpovedaju json datam")
                }
            }
            task.resume()
        }
    }
    
    func sendBumpToServer( bump: BumpForServer ){
        // 1
        let queue = DispatchQueue.global()
        // 2
        queue.async {
            var request = URLRequest(url: URL(string: ServerServices.create_bump)!)
            request.httpMethod = "POST"

            let parameters = self.createParamsBumpForServer(bump: bump)
            request.httpBody = parameters.data(using: .utf8)
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {                                                 // check for fundamental networking error
                    print("error=\(String(describing: error))")
                    return
                }
                
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                    print("response = \(String(describing: response))")
                    
                }
                //SWIFT 4.0 JSONparsing
                do {
                    let response = try JSONDecoder().decode(bumpForServerResponse.self, from: data)
                    print(response.success)
                    if(response.success == 1) {
                        let realm = RealmService()
                        realm.delete(bump)
                    }
                    DispatchQueue.main.async {
                        print("Podarilo sa mi odoslat bump a mozno aj vymazat")
                    }
                }catch{
                    print("Chyba pri JSon parsingu: Skontroluj ci parametre struktur zodpovedaju json datam")
                }
            }
            task.resume()
        }
    }
    
    func createParamsBumpForServer(bump: BumpForServer) -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        let outerSeparator = "&"
        var deviceId = "deviceId"
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            deviceId = id
        }
        let rating = "rating"
        let info = "info"
        
        var parameters = ""
        parameters.append("latitude=\(bump.latitude)\(outerSeparator)")
        parameters.append("longitude=\(bump.longitude)\(outerSeparator)")
        parameters.append("intensity=\(bump.intensity)\(outerSeparator)")
        parameters.append("rating=\(rating)\(outerSeparator)")
        parameters.append("manual=\(bump.manual)\(outerSeparator)")
        parameters.append("type=\(bump.type)\(outerSeparator)")
        parameters.append("device_id=\(deviceId)\(outerSeparator)")
        parameters.append("date=\(bump.created_at)\(outerSeparator)")
        parameters.append("actual_date=\(dateFormatter.string(from: Date()))\(outerSeparator)")
        parameters.append("info=\(info)\(outerSeparator)")
        print(parameters)
        
        return parameters
    }
    
    func createParams(coordinate: CLLocationCoordinate2D, net: Int) -> String {
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        //let postString = "date=2017-10-13+14%3A32%3A31&latitude=48.1607117&longitude=17.0958196&net=1"
        let dateFormatterStringToDate = DateFormatter()
        dateFormatterStringToDate.dateFormat = "yyyy-MM-dd"
        let testDate = dateFormatterStringToDate.date(from: "2017-10-13")
        
        let testLocation = CLLocationCoordinate2D(latitude: ("48.1607117" as NSString).doubleValue, longitude: ("17.0958196" as NSString).doubleValue)
        
//        let actualDate = dateFormatter.string(from: Date())
//        let actualLatitude = coordinate.latitude
//        let actualLongitude = coordinate.longitude
        
        let actualDate = dateFormatterStringToDate.string(from: testDate!)
        let actualLatitude = testLocation.latitude
        let actualLongitude = testLocation.longitude
        
        let result = RealmService().realm.objects(BumpFromServer.self)
        
        var listID = ""
        var listDate = ""
        var listCount = ""
        
        let innerSeparator = "@"
        let outerSeparator = "&"
        
        for bump in result {
            listID          += bump.b_id + innerSeparator
            listDate        += bump.last_modified + innerSeparator
            listCount       += bump.count.description + innerSeparator
        }
        
        if(!listID.isEmpty && !listDate.isEmpty && !listCount.isEmpty){
            listID.removeLast()
            listDate.removeLast()
            listCount.removeLast()
        }
        
        
        var parameters = ""
        parameters.append("date=\(actualDate)")
        parameters.append("\(outerSeparator)")
        parameters.append("latitude=\(actualLatitude.description)")
        parameters.append("\(outerSeparator)")
        parameters.append("longitude=\(actualLongitude.description)")
        parameters.append("\(outerSeparator)")
        parameters.append("listID=\(listID.description)")
        parameters.append("\(outerSeparator)")
        parameters.append("listDate=\(listDate.description)")
        parameters.append("\(outerSeparator)")
        parameters.append("listCount=\(listCount.description)")
        parameters.append("\(outerSeparator)")
        parameters.append("net=\(net.description)")
        
        print(parameters)
        
        return parameters
    }

}
