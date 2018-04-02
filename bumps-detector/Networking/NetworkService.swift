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
    func itemsUploaded()
}

class NetworkService: NSObject {
    
    //properties
    
    weak var delegate: NetworkServiceDelegate!
    
    init(delegate: NetworkServiceDelegate) {
        super.init()
        self.delegate = delegate
    }
    
    func param(name: String, value: String){
        
    }
    
    func downloadBumpsFromServer( coordinate: CLLocationCoordinate2D, net: Int ){
        
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
                    
                    var bumpsForUpdate = [BumpFromServer]()
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
                        bumpsForUpdate.append(newBump)
                    }
                    BumpFromServer.addOrUpdate(bumpsForUpdate)
                    //BumpsFromServer.updateAll(objects: bumpsForUpdate)
                    
                    //Inform main UI
                    DispatchQueue.main.async {
                        self.delegate.itemsDownloaded()
                    }
                }catch{
                    print("Chyba pri JSon parsingu: Skontroluj ci parametre struktur zodpovedaju json datam")
                }
            }
            task.resume()
    }
    
    func sendAllBumpsToServer(){
        let bumps = BumpForServer.all()
        for bump in bumps {
            self.sendBumpToServer(bump: bump)
        }
    }
    
    func sendBumpToServer( bump: BumpForServer ) {
        
        var request = URLRequest(url: URL(string: ServerServices.create_bump)!)
        request.httpMethod = "POST"

        let parameters = self.createParams(bump: bump)
        
        let bump_object = BumpForServer(value: bump)
        print(parameters)
        request.httpBody = parameters.data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {                                                 // check for fundamental networking error
                print("error=\(String(describing: error))")
                return
            }

            if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {           // check for http errors
                print("ERROR: statusCode should be 200, but is \(httpStatus.statusCode)")
                print("ERROR: response = \(String(describing: response))")

            }
            //SWIFT 4.0 JSONparsing
            do {
                let response = try JSONDecoder().decode(BumpForServerResponse.self, from: data)
                if( response.success == 1 ) {
                    do {
                        try bump_object.deleteSelf()
                    } catch {
                        print("ERROR: Class BumpDetectionAlgorithm, call sendBumpToServer() - Nepodarilo sa vymazat bump z databazy")
                    }
                } else { print("ERROR response: \(response.success)") }
            }catch{
                print("ERROR: Chyba pri JSon parsingu: Skontroluj ci parametre struktur zodpovedaju json datam")
            }
        }
        task.resume()
    }
    
    func createParams(bump: BumpForServer) -> String {
        
        //Nasetujeme format datumu
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var deviceId = "unknown device ID"
        //Zistujeme device ID
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            deviceId = id
        } else { print("INFO: Nepodarilo sa zistit device_id") }
        
        //Vytvorime body params pre http POST request na odoslanie jedného výtlku na server
        let outerSeparator = "&"
        var parameters = ""
        
        parameters.append("latitude=\(bump.latitude)")
        parameters.append("\(outerSeparator)")
        parameters.append("longitude=\(bump.longitude)")
        parameters.append("\(outerSeparator)")
        parameters.append("intensity=\(bump.intensity)")
        parameters.append("\(outerSeparator)")
        parameters.append("rating=\(bump.rating)")
        parameters.append("\(outerSeparator)")
        parameters.append("manual=\(bump.manual)")
        parameters.append("\(outerSeparator)")
        parameters.append("type=\(bump.type)")
        parameters.append("\(outerSeparator)")
        parameters.append("device_id=\(deviceId)")
        parameters.append("\(outerSeparator)")
        parameters.append("date=\(dateFormatter.string(from: bump.created_at))")
        parameters.append("\(outerSeparator)")
        parameters.append("actual_date=\(dateFormatter.string(from: Date()))")
        parameters.append("\(outerSeparator)")
        parameters.append("info=\(bump.text)")
        
        print("INFO: \(parameters)")
        
        return parameters
    }
    
    func createParams(coordinate: CLLocationCoordinate2D, net: Int) -> String {
        
        //Nasetujeme format datumu
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        //Nasetujeme si dátum synchronizacie so serverom a aktuálnu geograficku polohu
        let actualDate = dateFormatter.string(from: Date())
        let actualLatitude = coordinate.latitude
        let actualLongitude = coordinate.longitude
        
//        let dateFormatterStringToDate = DateFormatter()
//        dateFormatterStringToDate.dateFormat = "yyyy-MM-dd"
//        let postString = "date=2017-10-13+14%3A32%3A31&latitude=48.1607117&longitude=17.0958196&net=1"
//        let testDate = dateFormatterStringToDate.date(from: "2017-10-13")
//        let testLocation = CLLocationCoordinate2D(latitude: ("48.1607117" as NSString).doubleValue, longitude: ("17.0958196" as NSString).doubleValue)
//        let actualDate = dateFormatterStringToDate.string(from: testDate!)
//        let actualLatitude = testLocation.latitude
//        let actualLongitude = testLocation.longitude
        
        //
        var listID = ""
        var listDate = ""
        var listCount = ""
        let innerSeparator = "@"
        let outerSeparator = "&"
        
        let result = BumpFromServer.all()
        for bump in result {
            listID          += bump.b_id + innerSeparator
            listDate        += bump.last_modified + innerSeparator
            listCount       += bump.count.description + innerSeparator
        }
        
        //Odstranenie posledneho innerSeparatora z vytvorenych listov
        if(!listID.isEmpty && !listDate.isEmpty && !listCount.isEmpty){
            listID.removeLast()
            listDate.removeLast()
            listCount.removeLast()
        }
        
        //Vytvorime body params pre http POST request na odoslanie výtlkov na server kvoli aktualizacii internej databazy
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
