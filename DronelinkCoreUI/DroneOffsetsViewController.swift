//
//  DroneOffsetsViewController.swift
//  DronelinkCoreUI
//
//  Created by Jim McAndrew on 2/6/20.
//  Copyright © 2020 Dronelink. All rights reserved.
//

import Foundation
import DronelinkCore
import MaterialComponents.MaterialPalettes
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialProgressView

public class DroneOffsetsViewController: UIViewController {
    public enum Style: Int, CaseIterable {
        case altYawEv = 0
        case position
        
        var display: String {
            switch self {
            case .altYawEv: return "DroneOffsetsViewController.altitudeYaw".localized
            case .position: return "DroneOffsetsViewController.position".localized
            }
        }
    }
    
    public static func create(droneSessionManager: DroneSessionManager, styles: [Style] = Style.allCases) -> DroneOffsetsViewController {
        let droneOffsetsViewController = DroneOffsetsViewController()
        droneOffsetsViewController.styles = styles
        droneOffsetsViewController.droneSessionManager = droneSessionManager
        return droneOffsetsViewController
    }
    
    private var styles: [Style] = Style.allCases
    private var droneSessionManager: DroneSessionManager!
    private var session: DroneSession?
    
    private var styleSegmentedControl: UISegmentedControl!
    private let detailsLabel = UILabel()
    private let moreButton = UIButton(type: .custom)
    private let clearButton = UIButton(type: .custom)
    private let leftButton = MDCFloatingButton()
    private let rightButton = MDCFloatingButton()
    private let upButton = MDCFloatingButton()
    private let downButton = MDCFloatingButton()
    private let c1Button = MDCFloatingButton()
    private let c2Button = MDCFloatingButton()
    private let cLabel = UILabel()
    
    private let updateInterval: TimeInterval = 0.25
    private var updateTimer: Timer?
    private var exposureCommand: Mission.ExposureCompensationStepCameraCommand?
    private var style: Style { styles[styleSegmentedControl!.selectedSegmentIndex] }
    private var offsets: DroneOffsets {
        get { Dronelink.shared.droneOffsets }
        set (newOffsets) { Dronelink.shared.droneOffsets = newOffsets }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        if #available(iOS 13.0, *) {
            overrideUserInterfaceStyle = .dark
        }
        
        view.addShadow()
        view.layer.cornerRadius = DronelinkUI.Constants.cornerRadius
        view.backgroundColor = DronelinkUI.Constants.overlayColor
        
        styleSegmentedControl = UISegmentedControl(items: styles.map({ $0.display }))
        styleSegmentedControl.selectedSegmentIndex = 0
        styleSegmentedControl.addTarget(self, action:  #selector(onStyleChanged(sender:)), for: .valueChanged)
        view.addSubview(styleSegmentedControl)
        
        detailsLabel.textAlignment = .center
        detailsLabel.font = UIFont.boldSystemFont(ofSize: 14)
        detailsLabel.textColor = UIColor.white
        view.addSubview(detailsLabel)
        
        moreButton.tintColor = UIColor.white.withAlphaComponent(0.85)
        moreButton.setImage(DronelinkUI.loadImage(named: "baseline_more_white_36pt"), for: .normal)
        moreButton.addTarget(self, action: #selector(onMore), for: .touchUpInside)
        view.addSubview(moreButton)
        
        clearButton.tintColor = UIColor.white.withAlphaComponent(0.85)
        clearButton.setImage(DronelinkUI.loadImage(named: "baseline_cancel_white_36pt"), for: .normal)
        clearButton.addTarget(self, action: #selector(onClear), for: .touchUpInside)
        view.addSubview(clearButton)
        
        configureButton(button: leftButton, image: "baseline_arrow_left_white_36pt", action: #selector(onLeft(sender:)))
        configureButton(button: rightButton, image: "baseline_arrow_right_white_36pt", action: #selector(onRight(sender:)))
        configureButton(button: upButton, image: "baseline_arrow_drop_up_white_36pt", action: #selector(onUp(sender:)))
        configureButton(button: downButton, image: "baseline_arrow_drop_down_white_36pt", action: #selector(onDown(sender:)))
        
        switch style {
        case .altYawEv:
            configureButton(button: c1Button, image: "baseline_remove_white_36pt", action: #selector(onC1(sender:)))
            configureButton(button: c2Button, image: "baseline_add_white_36pt", action: #selector(onC2(sender:)))
            break
        
        case .position:
            configureButton(button: c1Button, image: "map-marker-radius-outline", action: #selector(onC1(sender:)))
            configureButton(button: c2Button, image: "map-marker-distance", action: #selector(onC2(sender:)))
            break
        }
        
        cLabel.textAlignment = .center
        cLabel.font = UIFont.boldSystemFont(ofSize: 12)
        cLabel.textColor = detailsLabel.textColor
        view.addSubview(cLabel)
        
        update()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        droneSessionManager.add(delegate: self)
        updateTimer = Timer.scheduledTimer(timeInterval: updateInterval, target: self, selector: #selector(update), userInfo: nil, repeats: true)
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        updateTimer?.invalidate()
        updateTimer = nil
        droneSessionManager.remove(delegate: self)
    }
    
    private func configureButton(button: MDCFloatingButton, image: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setBackgroundColor(UIColor.darkGray.withAlphaComponent(0.85))
        button.setImage(DronelinkUI.loadImage(named: image), for: .normal)
        button.tintColor = UIColor.white
        button.addTarget(self, action: action, for: .touchUpInside)
        if button.superview == nil {
            view.addSubview(button)
        }
    }
    
    public override func updateViewConstraints() {
        super.updateViewConstraints()
        
        let defaultPadding = 10
        let buttonSize = 42
        
        styleSegmentedControl.snp.remakeConstraints { make in
            make.height.equalTo(25)
            make.left.equalToSuperview().offset(8)
            make.right.equalToSuperview().offset(-8)
            make.top.equalToSuperview().offset(8)
        }
        
        moreButton.snp.remakeConstraints { make in
            make.height.equalTo(styleSegmentedControl)
            make.width.equalTo(moreButton.snp.height)
            make.left.equalTo(styleSegmentedControl)
            make.top.equalTo(styleSegmentedControl.snp.bottom).offset(defaultPadding)
        }
        
        clearButton.snp.remakeConstraints { make in
            make.height.equalTo(styleSegmentedControl)
            make.width.equalTo(clearButton.snp.height)
            make.right.equalTo(styleSegmentedControl)
            make.top.equalTo(styleSegmentedControl.snp.bottom).offset(defaultPadding)
        }
        
        detailsLabel.snp.remakeConstraints { make in
            make.height.equalTo(styleSegmentedControl)
            make.left.equalTo(moreButton.snp.right).offset(5)
            make.right.equalTo(clearButton.snp.left).offset(-5)
            make.top.equalTo(styleSegmentedControl.snp.bottom).offset(defaultPadding)
        }
        
        upButton.snp.remakeConstraints { make in
            make.height.equalTo(buttonSize)
            make.width.equalTo(buttonSize)
            make.top.equalTo(detailsLabel.snp.bottom).offset(defaultPadding)
            make.centerX.equalToSuperview()
        }
        
        downButton.snp.remakeConstraints { make in
            make.height.equalTo(buttonSize)
            make.width.equalTo(buttonSize)
            make.top.equalTo(upButton.snp.bottom).offset(20)
            make.centerX.equalTo(upButton)
        }
        
        leftButton.snp.remakeConstraints { make in
            make.height.equalTo(buttonSize)
            make.width.equalTo(buttonSize)
            make.top.equalTo(upButton).offset(33)
            make.right.equalTo(upButton.snp.left).offset(-defaultPadding)
        }
        
        rightButton.snp.remakeConstraints { make in
            make.height.equalTo(buttonSize)
            make.width.equalTo(buttonSize)
            make.centerY.equalTo(leftButton)
            make.left.equalTo(upButton.snp.right).offset(defaultPadding)
        }

        c1Button.snp.remakeConstraints { make in
            make.height.equalTo(buttonSize)
            make.width.equalTo(buttonSize)
            make.bottom.equalToSuperview().offset(-defaultPadding)
            make.left.equalToSuperview().offset(defaultPadding)
        }
        
        c2Button.snp.remakeConstraints { make in
            make.height.equalTo(buttonSize)
            make.width.equalTo(buttonSize)
            make.bottom.equalToSuperview().offset(-defaultPadding)
            make.right.equalToSuperview().offset(-defaultPadding)
        }
        
        cLabel.snp.remakeConstraints { make in
            make.height.equalTo(buttonSize)
            make.left.equalTo(c1Button.snp.right).offset(defaultPadding)
            make.right.equalTo(c2Button.snp.left).offset(-defaultPadding)
            make.centerY.equalTo(c2Button)
        }
        
        update()
    }
        
    @objc func onStyleChanged(sender: Any) {
        switch style {
        case .altYawEv:
            configureButton(button: c1Button, image: "baseline_remove_white_36pt", action: #selector(onC1(sender:)))
            configureButton(button: c2Button, image: "baseline_add_white_36pt", action: #selector(onC2(sender:)))
            break
        
        case .position:
            configureButton(button: c1Button, image: "map-marker-radius-outline", action: #selector(onC1(sender:)))
            configureButton(button: c2Button, image: "map-marker-distance", action: #selector(onC2(sender:)))
            break
        }
        update()
    }
    
    @objc func onMore(sender: Any) {
        let alert = UIAlertController(title: "DroneOffsetsViewController.more".localized, message: nil, preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = sender as? UIView

        alert.addAction(UIAlertAction(title: "DroneOffsetsViewController.resetGimbal".localized, style: .default , handler:{ _ in
            self.session?.drone.gimbal(channel: 0)?.reset()
        }))
        
        alert.addAction(UIAlertAction(title: "DroneOffsetsViewController.levelGimbal".localized, style: .default , handler:{ _ in
            var command = Mission.OrientationGimbalCommand()
            command.orientation.x = 0
            try? self.session?.add(command: command)
        }))
        
        alert.addAction(UIAlertAction(title: "DroneOffsetsViewController.nadirGimbal".localized, style: .default , handler:{ _ in
            var command = Mission.OrientationGimbalCommand()
            command.orientation.x = -90.convertDegreesToRadians
            try? self.session?.add(command: command)
        }))

        alert.addAction(UIAlertAction(title: "dismiss".localized, style: .cancel, handler: { _ in
            
        }))

        present(alert, animated: true)
    }
    
    @objc func onClear(sender: Any) {
        switch style {
        case .altYawEv:
            offsets.droneAltitude = 0
            offsets.droneYaw = 0
            break
        
        case .position:
            offsets.droneCoordinate = Mission.Vector2()
            break
        }

        update()
    }
    
    @objc func onLeft(sender: Any) {
        guard let session = session else {
            return
        }
        
        switch style {
        case .altYawEv:
            offsets.droneYaw += -3.0.convertDegreesToRadians
            break
        
        case .position:
            guard let state = session.state?.value else {
                return
            }
            
            offsets.droneCoordinate = offsets.droneCoordinate.add(
                vector: Mission.Vector2(
                    direction: state.missionOrientation.yaw - (Double.pi / 2),
                    magnitude: 1.0.convertFeetToMeters))
            break
        }
        
        update()
    }
    
    @objc func onRight(sender: Any) {
        guard let session = session else {
            return
        }
        
        switch style {
        case .altYawEv:
            offsets.droneYaw += 3.0.convertDegreesToRadians
            break
        
        case .position:
            guard let state = session.state?.value else {
                return
            }
            
            offsets.droneCoordinate = offsets.droneCoordinate.add(
                vector: Mission.Vector2(
                    direction: state.missionOrientation.yaw + (Double.pi / 2),
                    magnitude: 1.0.convertFeetToMeters))
            break
        }
        
        update()
    }
    
    @objc func onUp(sender: Any) {
        guard let session = session else {
            return
        }
        
        switch style {
        case .altYawEv:
            offsets.droneAltitude += 1.0.convertFeetToMeters
            break
        
        case .position:
            guard let state = session.state?.value else {
                return
            }
            
            offsets.droneCoordinate = offsets.droneCoordinate.add(
                vector: Mission.Vector2(
                    direction: state.missionOrientation.yaw,
                    magnitude: 1.0.convertFeetToMeters))
            break
        }
        
        update()
    }
    
    @objc func onDown(sender: Any) {
        guard let session = session else {
            return
        }
        
        switch style {
        case .altYawEv:
            offsets.droneAltitude += -1.0.convertFeetToMeters
            break
        
        case .position:
            guard let state = session.state?.value else {
                return
            }
            
            offsets.droneCoordinate = offsets.droneCoordinate.add(
                vector: Mission.Vector2(
                    direction: state.missionOrientation.yaw + Double.pi,
                    magnitude: 1.0.convertFeetToMeters))
            break
        }
        
        update()
    }
    
    @objc func onC1(sender: Any) {
        switch style {
        case .altYawEv:
            guard exposureCommand == nil else {
                return
            }
            
            onEV(steps: -1)
            break
        
        case .position:
            guard let coordinate = session?.state?.value.location?.coordinate else {
                return
            }
            
            offsets.droneCoordinateReference = coordinate
            update()
            break
        }
    }
    
    @objc func onC2(sender: Any) {
        switch style {
        case .altYawEv:
            guard exposureCommand == nil else {
                return
            }
            
            onEV(steps: 1)
            break
        
        case .position:
            guard
                let session = session,
                let reference = offsets.droneCoordinateReference,
                let current = session.state?.value.location?.coordinate
            else {
                return
            }
            
            offsets.droneCoordinate = Mission.Vector2(
                direction: reference.bearing(to: current),
                magnitude: reference.distance(to: current)
            )
            update()
            break
        }
    }
    
    private func onEV(steps: Int) {
        guard let session = session else {
            return
        }
        
        do {
            let exposureCommand = Mission.ExposureCompensationStepCameraCommand(exposureCompensationSteps: steps)
            try? session.add(command: exposureCommand)
            offsets.cameraExposureCompensationSteps += steps
            self.exposureCommand = exposureCommand
            update()
        }
    }
    
    @objc func update() {
        switch style {
        case .altYawEv:
            var details: [String] = []
            if offsets.droneYaw != 0 {
                details.append(Dronelink.shared.format(formatter: "angle", value: offsets.droneYaw, extraParams: [false]))
            }
            
            if offsets.droneAltitude != 0 {
                details.append(Dronelink.shared.format(formatter: "altitude", value: offsets.droneAltitude))
            }
            
            moreButton.isHidden = session == nil
            clearButton.isHidden = details.count == 0
            detailsLabel.text = details.joined(separator: " / ")
            
            let exposureCompensation = session?.cameraState(channel: 0)?.value.missionExposureCompensation
            c1Button.tintColor = exposureCommand == nil ? UIColor.white : MDCPalette.pink.accent400
            c1Button.isEnabled = exposureCompensation != nil
            c2Button.tintColor = c1Button.tintColor
            c2Button.isEnabled = c1Button.isEnabled
            
            cLabel.text = exposureCompensation == nil ? "" : Dronelink.shared.formatEnum(name: "CameraExposureCompensation", value: exposureCompensation!.rawValue)
            break
        
        case .position:
            moreButton.isHidden = true
            clearButton.isHidden = offsets.droneCoordinate.magnitude == 0
            detailsLabel.text = clearButton.isHidden ? "" : display(vector: offsets.droneCoordinate)
            
            if let session = session,
                let reference = offsets.droneCoordinateReference,
                let current = session.state?.value.location?.coordinate {
                cLabel.text = display(vector: Mission.Vector2(
                    direction: reference.bearing(to: current),
                    magnitude: reference.distance(to: current)))
            }
            else {
                cLabel.text = nil
            }
            
            c1Button.isEnabled = session?.state?.value.location != nil
            c2Button.isEnabled = c1Button.isEnabled && cLabel.text != nil
            break
        }
    }
    
    func display(vector: Mission.Vector2) -> String {
        return "\(Dronelink.shared.format(formatter: "angle", value: vector.direction)) → \(Dronelink.shared.format(formatter: "distance", value: vector.magnitude))"
    }
}

extension DroneOffsetsViewController: DroneSessionManagerDelegate {
    public func onOpened(session: DroneSession) {
        self.session = session
        session.add(delegate: self)
    }
    
    public func onClosed(session: DroneSession) {
        self.session = nil
        session.remove(delegate: self)
    }
}

extension DroneOffsetsViewController: DroneSessionDelegate {
    public func onInitialized(session: DroneSession) {}
    
    public func onLocated(session: DroneSession) {}
    
    public func onMotorsChanged(session: DroneSession, value: Bool) {}
    
    public func onCommandExecuted(session: DroneSession, command: MissionCommand) {}
    
    public func onCommandFinished(session: DroneSession, command: MissionCommand, error: Error?) {
        guard let exposureCommand = self.exposureCommand else {
            return
        }
        
        if command.id == exposureCommand.id {
            self.exposureCommand = nil
            DispatchQueue.main.async {
                self.view.setNeedsUpdateConstraints()
            }
        }
    }
    
    public func onCameraFileGenerated(session: DroneSession, file: CameraFile) {}
}
