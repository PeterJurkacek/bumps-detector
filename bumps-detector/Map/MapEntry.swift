//
//  MapView.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 3.11.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import UIKit
import Foundation
import CoreLocation


struct MapType {
    let name: String
    let url: URL
}

struct EntryType: Equatable {
    static func ==(lhs: EntryType, rhs: EntryType) -> Bool {
        return lhs.entryTitle == rhs.entryTitle && lhs.imageName == rhs.imageName
    }
    
    let entryTitle: String
    let imageName: String
}

struct MapState {
    var selectedMapType: MapType
    var selectedEntryTypes: [EntryType]
}

struct MapEntry {
    let entryType: EntryType
    let title: String
    let location: CLLocationCoordinate2D
    let entryId: String
}
