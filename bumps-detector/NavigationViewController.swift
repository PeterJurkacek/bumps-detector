//
//  NavigationViewController.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 28.9.17.
//  Copyright © 2017 Peter Jurkacek. All rights reserved.
//

import UIKit
import MapboxCoreNavigation
import MapboxDirections
import MapboxNavigation

class NavigationViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        let origin = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 30.284, longitude: -97.735), name: "University of Texas at Austin")
        let destination = Waypoint(coordinate: CLLocationCoordinate2D(latitude: 30.26, longitude: -97.79), name: "Tacodeli")
        
        let options = NavigationRouteOptions(waypoints: [origin, destination], profileIdentifier: .automobileAvoidingTraffic)
        
        _ = Directions.shared.calculate(options) { (waypoints, routes, error) in
            guard let route = routes?.first else { return }
            let viewController = NavigationViewController(for: route)
            self.present(viewController, animated: true, completion: nil)
        }
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
