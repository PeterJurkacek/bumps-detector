//
//  FilterDialogViewController.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 27.3.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import UIKit

protocol FilterPopOverViewDelegate {
    func filterBumps(rating: String?)
}

struct TableItem {
    let title: String
    let rating: String
}

class FilterPopOverViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var Popupview: UIView!
    
    @IBOutlet weak var tableView: UITableView!
    
    var delegate: FilterPopOverViewDelegate?
    var tableItems: [TableItem] = [TableItem(title: "Malé", rating: "1"), TableItem(title:"Stredné", rating:"2"), TableItem(title:"Veľké", rating:"3")]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.dataSource = self
        tableView.delegate = self
        
        // Apply radius to Popupview
        Popupview.layer.cornerRadius = 10
        Popupview.layer.masksToBounds = true
        
    }
    
    
    // Returns count of items in tableView
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tableItems.count;
    }
    
    
    // Select item from tableView
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let selectedRating = self.tableItems[indexPath.row].rating
        print("INFO: Rating : " + self.tableItems[indexPath.row].rating)
        self.delegate?.filterBumps(rating: selectedRating)
        
        
        dismiss(animated: true, completion: nil)
    }
    
    //Assign values for tableView
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell_id", for: indexPath)
        
        cell.textLabel?.text = tableItems[indexPath.row].title
        
        return cell
    }
    
    // Close PopUp
    @IBAction func closePopup(_ sender: Any) {
        
        dismiss(animated: true, completion: nil)
    }

}
