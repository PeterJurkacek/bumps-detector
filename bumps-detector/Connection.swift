//
//  HomeModel.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 21.8.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import UIKit

struct Services {
    static let create_bump = "http://vytlky.fiit.stuba.sk//create_bump.php"
    static let get_image = "http://vytlky.fiit.stuba.sk//get_image.php"
    static let get_image_id = "http://vytlky.fiit.stuba.sk//get_image_id.php"
    static let sync_bump = "http://vytlky.fiit.stuba.sk//sync_bump.php"
    static let update_image = "http://vytlky.fiit.stuba.sk//update_image.php"
}

protocol ConnectionDelegate: class {
    func itemsDownloaded(items: [Bump])
}

class Connection: NSObject {
    
    //properties
    
    weak var delegate: ConnectionDelegate!
    
    func sync_database(){
        // 1
        let queue = DispatchQueue.global()
        // 2
        queue.async {
            var request = URLRequest(url: URL(string: Services.sync_bump)!)
            request.httpMethod = "POST"
            let postString = "date=2017-10-13+14%3A32%3A31&latitude=48.1607117&longitude=17.0958196&net=1"
            request.httpBody = postString.data(using: .utf8)
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
                }catch{
                    print("Chyba pri JSon parsingu: Skontroluj ci parametre struktur zodpovedaju json datam")
                }
            }
            task.resume()
        }
    }

}
