//
//  Bump.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 20.8.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import Foundation
enum SerializationError: Error {
    case missing(String)
}
public class Bump {
    
    // MARK: - Properties
    public let latitude:    String
    public let longitude:   String
    public let intensity:   String
    public let rank:        String
    
    // MARK: - Initializers
    public init?(latitude: Double, longitude: Double, intensity: Double){
        self.latitude   = String(format:"%f", latitude)
        self.longitude  = String(format:"%f", longitude)
        self.intensity  = String(format:"%f", intensity)
        if intensity < 0.6 {
            self.rank  = "1"
        }
        else{
            self.rank  = "0"
        }
        
    }
    public init?(json: [String: Any]) throws{
        guard let latitude  = json["latitude"]  as? String  else {
            throw SerializationError.missing("latitude")
        }
        guard let longitude = json["longitude"] as? String  else {
            throw SerializationError.missing("longitude")
        }
        guard let intensity = json["intensity"] as? String  else {
            throw SerializationError.missing("intensity")
        }
        guard let rank      = json["rank"]      as? String  else {
            throw SerializationError.missing("rank")
        }
        self.latitude   = latitude
        self.longitude  = longitude
        self.intensity  = intensity
        self.rank       = rank
    }
}
