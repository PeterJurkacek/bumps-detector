//
//  AnnotationsController.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 3.4.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import UIKit
import Mapbox

class AnnotationsController: NSObject {
    
    override init(){
        super.init()
        //My custom setup
    }
    
    static var routePotholesAnnotations = [MGLPointAnnotation]()
    
    static func updateRouteAnnotations(mapView: MGLMapView, newAnnotations: [MGLPointAnnotation]){
        mapView.removeAnnotations(routePotholesAnnotations)
        routePotholesAnnotations.removeAll()
        routePotholesAnnotations.append(contentsOf: routePotholesAnnotations)
        mapView.addAnnotations(routePotholesAnnotations)
    }
    
}
