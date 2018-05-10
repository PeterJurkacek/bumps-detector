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
    func synchronizationWithServerResult(userMessage: String)
    func itemsUploaded()
}

class NetworkService: NSObject {
    
    //properties
    
    weak var delegate: NetworkServiceDelegate!
    var userMessage: String?
    
    init(delegate: NetworkServiceDelegate) {
        super.init()
        self.delegate = delegate
    }
    
    func param(name: String, value: String){
        
    }
    
    func downloadBumpsFromServer( coordinate: CLLocationCoordinate2D, net: Int ){
        
            var request = URLRequest(url: URL(string: ServerServices.sync_bump)!)
            request.httpMethod = "POST"
        
            let parameters = self.createParams(coordinate: coordinate, net: net)
            request.httpBody = parameters.data(using: .utf8)
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                //Kontrola errorov
                guard let data = data, error == nil else {
                    print("ERROR: error=\(String(describing: error))")
                    return
                }
                
                //Kontrola http errorov
                if let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode != 200 {
                    print("WARNING: statusCode should be 200, but is \(httpStatus.statusCode)")
                    print("WARNING: response = \(String(describing: response))")
                    
                }
                //SWIFT 4.0 JSONparsing
                do {
                    let syncBump = try JSONDecoder().decode(SyncBump.self, from: data)
                    print(syncBump)
                    print("POCET: \(syncBump.bumps.count)")
                    switch(syncBump.success){
                    case 0:
                        //Updatuj internú db
                        let realmService = RealmService()
                        realmService.updateBumpsFromServer(bumps: syncBump.bumps)
                        self.userMessage = "Aktualizoval som databázu"
                        break
                    case 1:
                        //Notifikuj pouzivatela, ze je potrebné updatovat internú db
                        self.userMessage = "Je potrebné aktualizovať dáta"
                        self.downloadBumpsFromServer(coordinate: coordinate, net: 1)
                        break
                    case 2:
                        //Netreba nic updatovat
                        self.userMessage = "Máte aktuálne dáta"
                        break
                    case 4:
                        //Pre tvoju aktualnu polohu v okruhu 11.1km sa nenachadzaju v databaze žiadne nové zaznamy
                        self.userMessage = "Máte aktuálne dáta"
                        break
                    default:
                        //Neznámy succes kód
                        self.userMessage = "Neznámy SUCCESS kód: \(syncBump.success)"
                        break
                    }
                    
                    //Inform main UI
                    DispatchQueue.main.async {
                        if let userMessage = self.userMessage {
                            self.delegate.synchronizationWithServerResult(userMessage: userMessage)
                        }
                    }
                }catch{
                    print("ERROR: JSON PARSING, Skontroluj ci parametre struktur zodpovedaju json datam")
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
                    let realmService = RealmService()
                    do {
                        try realmService.delete(bumpObject: bump_object)
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
    
    func sendPhotoToServer(){
        
    }
    
    func createParams(bump: BumpForServer) -> String {
        
        //Nasetujem format datumu
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        //Nastavím časovú zónu podla aktuálnej polohy
        dateFormatter.timeZone = TimeZone.current
        
        //Zistujeme device ID
        var deviceId = "unknown device ID"
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            deviceId = id
        } else { print("WARNING: Nepodarilo sa zistit device_id") }
        
        //Vytvor body params pre http POST request na odoslanie jedného výtlku na server
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
        
        return parameters
    }
    
    func createParams(coordinate: CLLocationCoordinate2D, net: Int) -> String {
        
        //Nastavím format dátumu
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone.current
        
        //Nastavím si dátum synchronizacie so serverom a aktuálnu geograficku polohu
        let actualDate = dateFormatter.string(from: Date())
        let actualLatitude = coordinate.latitude
        let actualLongitude = coordinate.longitude
        
        var listID = ""
        var listDate = ""
        var listCount = ""
        
        //Oddelovač parametrov
        let innerSeparator = "@"
        
        //Oddelovač  záznamov uložených do ListID, ListData, ListCount
        let outerSeparator = "&"
        
        //Vykonám dopyt na lokálnu databázu, aby mi vrátil výtlky v okruhu 15km od mojej aktuálnej polohy
        let result = BumpFromServer.findNearby(origin: coordinate, radius: 15000, sortAscending: nil)
        
        //Vytvorím si polia podľa výsledku dopytu
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
        
        //Vytvorime body params pre http POST request na odoslanie výtlkov na
        //server kvoli aktualizacii internej databazy
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
        
        return parameters
    }

}
