//
//  FlightModeWidget.swift
//  DronelinkCoreUI
//
//  Created by Nicolas Torres on 8/12/20.
//  Copyright © 2020 Dronelink. All rights reserved.
//

import Foundation
import UIKit
import DronelinkCore
import MaterialComponents.MaterialPalettes
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialButtons_Theming
import MarqueeLabel

public class FlightModeWidget: UpdatableWidget {
    public override var updateInterval: TimeInterval { 0.5 }
    
    public var flightModeImageView: UIImageView?
    public var flightModeLabel: UILabel?
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        flightModeImageView = UIImageView(image: DronelinkUI.loadImage(named: "flightModeIcon")?.withRenderingMode(.alwaysOriginal))
        view.addSubview(flightModeImageView!)
        flightModeImageView?.snp.makeConstraints { make in
            make.left.equalToSuperview()
            make.top.equalToSuperview()
            make.width.equalTo(self.view.snp.height)
            make.bottom.equalToSuperview()
        }
        
        flightModeLabel = UILabel()
        flightModeLabel?.textColor = .white
        flightModeLabel?.textAlignment = .left
        flightModeLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        view.addSubview(flightModeLabel!)
        flightModeLabel?.snp.makeConstraints { make in
            make.left.equalTo(flightModeImageView!.snp.right).offset(defaultPadding)
            make.top.equalToSuperview()
            make.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }
    
    @objc public override func update() {
        super.update()
        flightModeLabel?.text = String(session?.state?.value.mode ?? "na".localized)
    }
}
