//
//  DataManager.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 20.8.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//
import Foundation

public class DataManager {
    
    public func postRequest(postString : String){
        var request = URLRequest(url: URL(string: "http://www.thisismylink.com/postName.php")!)
        request.httpMethod = "POST"
        let postString = "id=13&name=Jack"
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
            
            let responseString = String(data: data, encoding: .utf8)
            print("responseString = \(String(describing: responseString))")
        }
        task.resume()
    }

    
    public class func getTopAppsDataFromFileWithSuccess(success: @escaping ((_ data: Data) -> Void)) {
        DispatchQueue.global(qos: .background).async {
            let filePath = Bundle.main.path(forResource: "topapps", ofType:"json")
            let data = try! Data(contentsOf: URL(fileURLWithPath:filePath!), options: .uncached)
            
            success(data)
        }
    }
    
    public class func loadDataFromURL(url: URL, completion: @escaping (_ data: Data?, _ error: Error?) -> Void) {
        let loadDataTask = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let _ = error {
                completion(nil, error)
            } else if let response = response as? HTTPURLResponse {
                if response.statusCode != 200 {
                    let statusError = NSError(domain: "com.raywenderlich",
                                              code: response.statusCode,
                                              userInfo: [NSLocalizedDescriptionKey: "HTTP status code has unexpected value."])
                    completion(nil, statusError)
                } else {
                    completion(data, nil)
                }
            }
        }
        loadDataTask.resume()
    }
}
