////
////  MapBoxService.swift
////  bumps-detector
////
////  Created by Peter Jurkacek on 3.11.17.
////  Copyright © 2017 Peter Jurkacek. All rights reserved.
////
//
//import Foundation
//import Mapbox
//
//class MapBoxService : MapService {
//    
//    func defaultMapType() -> MapType {
//        return supportedMapTypes()[0]
//    }
//    
//    func supportedMapTypes() -> [MapType] {
//        return MockDataService.supportedMapTypes()
//    }
//    
//    func supportedEntryTypes() -> [EntryType] {
//        return MockDataService.supportedEntryTypes()
//    }
//    
//    func mapEntries() -> [String: [MapEntry]] {
//        return MockDataService.mapEntries()
//    }
//    
//    func mapEntries(forSelectedTypes entryTypes: [EntryType]) -> [MapEntry] {
//        var selected = [MapEntry]()
//        let all = mapEntries()
//        for entryType in entryTypes {
//            let entries = all[entryType.entryTitle]!
//            selected += entries
//        }
//        return selected
//    }
//    
//}

