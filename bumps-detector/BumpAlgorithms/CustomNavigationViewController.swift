//
//  CustomRoute.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 11.2.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import UIKit
import Mapbox
import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation

class CustomNavigationViewController : NavigationViewController {
    
    init(for: Route, annotations: [MGLAnnotations]) {
        
        super.init(for: route)
    }
}
