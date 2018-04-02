//
//  OptionsLauncher.swift
//  bumps-detector
//
//  Created by Peter Jurkacek on 2.4.18.
//  Copyright © 2018 Peter Jurkacek. All rights reserved.
//

import UIKit

class OptionsLauncher: NSObject {
    
    
    let blackView = UIView()
    
    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = UIColor.white
        return collectionView
    }()
    
    override init() {
        super.init()
        //Whatever
    }
    
    func showOptions(){
        if let window = UIApplication.shared.keyWindow {
            
            //Nastavime ho aby bolo priesvitne
            blackView.backgroundColor = UIColor(white: 0, alpha: 0.5)
            //Nastavime mu klikatelnost
            blackView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(dismissBlackView)))
            window.addSubview(blackView)
            
            window.addSubview(collectionView)
            
            let height: CGFloat = 200
            let y = window.frame.height - height
            collectionView.frame = CGRect(x: 0, y: window.frame.height, width: window.frame.width, height: 200)
            
            blackView.frame = window.frame
            blackView.alpha = 0
            
            //Nastavime animaciu vysunutia bottom-up
            UIView.animate(withDuration: 0.5, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 1, options: .curveEaseOut, animations: {
                self.blackView.alpha = 1
                self.collectionView.frame = CGRect(x: 0, y: y, width: window.frame.width, height: 200)
            }, completion: nil)
        }
    }
    
    @objc func dismissBlackView(){
        
        UIView.animate(withDuration: 0.5) {
            self.blackView.alpha = 0
            if let window = UIApplication.shared.keyWindow{
                self.collectionView.frame = CGRect(x: 0, y: window.frame.height, width: window.frame.width, height: self.collectionView.frame.height)
            }
        }
    }
    
}
