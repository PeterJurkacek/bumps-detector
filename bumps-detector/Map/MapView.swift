//
//  MapView.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 3.11.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import CoreGraphics
import UIKit
import CoreLocation

protocol MapView : class {
    func map(withFrame frame: CGRect, initialCoordinates: CLLocationCoordinate2D) -> UIView
    func update(withMapType mapType: MapType, entries: [MapEntry])
}
