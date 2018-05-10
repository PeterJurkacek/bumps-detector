//
//  FilterViewController.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 8.5.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import UIKit

protocol FilterViewControllerDelegate : class {
    func saved(filter: MyFilter)
}

class FilterViewController: UIViewController {

    weak var delegate: FilterViewControllerDelegate?
    @IBOutlet weak var switchVelkeVytlky: UISwitch!
    @IBOutlet weak var counterLabel: UILabel!
    @IBOutlet weak var switchMaleVytlky: UISwitch!
    @IBOutlet weak var switchKose: UISwitch!
    @IBOutlet weak var switchKanal: UISwitch!
    @IBOutlet weak var switchStredneVytlky: UISwitch!
    @IBOutlet weak var switchOpravene: UISwitch!
    @IBOutlet weak var switchPocet: UISwitch!
    var filter = MyFilter()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Vytiahni uložený filter z disku
        if let data = UserDefaults.standard.object(forKey: "filter") as? NSData {
            let filter = NSKeyedUnarchiver.unarchiveObject(with: data as Data)
            self.filter = filter as! MyFilter
        }
        //Ak nie je žiaden, filter na disku nastav východzí filter
        else {
            self.filter = MyFilter()
        }
        //Nastav UI podľa filtra
        self.setAllSwitches(with: self.filter)
    }

    @IBAction func cancelFilter(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    
    @IBAction func saveFilter(_ sender: UIButton) {
        //Kontrola nil hodnoty
        guard let delegate = self.delegate else { return }
        
        //Zapíš filter na disk tak aby si neblokoval hlavné vlákno
        DispatchQueue.global().async {
            let filter = self.filter
            let data = NSKeyedArchiver.archivedData(withRootObject: filter)
            UserDefaults.standard.set(data, forKey: "filter")
        }
        
        //Informuj Delegáta o zmene nastavení filtra
        delegate.saved(filter: self.filter)
        
        //Zatvor FilterViewController
        dismiss(animated: true, completion: nil)
    }
    
    
    @IBAction func changeVelke(_ sender: UISwitch) {
        self.filter.rating3 = sender.isOn
    }
    @IBAction func changeObycajne(_ sender: UISwitch) {
        self.filter.rating2 = sender.isOn
    }
    @IBAction func changeMale(_ sender: UISwitch) {
        self.filter.rating1 = sender.isOn
    }
    @IBAction func changeKose(_ sender: UISwitch) {
        self.filter.type1 = sender.isOn
    }
    @IBAction func changeKanal(_ sender: UISwitch) {
        self.filter.type2 = sender.isOn
    }
    @IBAction func changePocet(_ sender: UISwitch) {
        self.filter.isCount = sender.isOn
    }
    @IBAction func stepperValueChanged(_ sender: UIStepper) {
        self.counterLabel.text = Int(sender.value).description
        self.filter.count = Int32(sender.value)
    }
    @IBAction func changeOpravene(_ sender: UISwitch) {
        self.filter.fix = sender.isOn
    }
    
    @IBAction func changeVsetko(_ sender: UISwitch) {
        self.changeMale(sender)
        self.changeObycajne(sender)
        self.changeVelke(sender)
        self.changeKose(sender)
        self.changeKanal(sender)
        self.changePocet(sender)
        self.changeOpravene(sender)
        switchVelkeVytlky.setOn(sender.isOn, animated: true)
        switchMaleVytlky.setOn(sender.isOn, animated: true)
        switchKose.setOn(sender.isOn, animated: true)
        switchKanal.setOn(sender.isOn, animated: true)
        switchStredneVytlky.setOn(sender.isOn, animated: true)
        switchOpravene.setOn(sender.isOn, animated: true)
        switchPocet.setOn(sender.isOn, animated: true)
    }
    
    func setAllSwitches(with filter: MyFilter){
        switchMaleVytlky.setOn(filter.rating1, animated: true)
        switchStredneVytlky.setOn(filter.rating2, animated: true)
        switchVelkeVytlky.setOn(filter.rating3, animated: true)
        switchKose.setOn(filter.type1, animated: true)
        switchKanal.setOn(filter.type2, animated: true)
        switchOpravene.setOn(filter.fix, animated: true)
        switchPocet.setOn(filter.isCount, animated: true)
        counterLabel.text = filter.count.description
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
