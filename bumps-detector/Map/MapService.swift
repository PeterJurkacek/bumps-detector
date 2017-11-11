//
//  MapService.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 3.11.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

//Providing data source of map
protocol MapService: class {
    func defaultMapTypes() -> MapType
    func supportedMapTypes() -> [MapType]
    func supportedEntryTypes() -> [EntryType]
    func mapEntries() -> [String: [MapEntry]]
    func mapEntries(forSelectedTypes entryTypes: [EntryType]) -> [MapEntry]
}

