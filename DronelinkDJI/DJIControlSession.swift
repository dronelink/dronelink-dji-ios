//
//  DJIControlSession.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 2/12/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import Foundation
import os
import DJISDK
import JavaScriptCore

public class DJIControlSession: DroneControlSession {
    private let log = OSLog(subsystem: "DronelinkDJI", category: "DJIDroneControlSession")
    
    private enum State {
        case TakeoffStart
        case TakeoffAttempting
        case TakeoffComplete
        case VirtualStickStart
        case VirtualStickAttempting
        case FlightModeJoystickAttempting
        case FlightModeJoystickComplete
        case Deactivated
    }
    
    private var state = State.TakeoffStart
    private var virtualStickAttempts = 0
    private var virtualStickAttemptPrevious: Date?
    private var flightModeJoystickAttemptingStarted: Date?
    private var attemptDisengageReason: Mission.Message?
    
    private let droneSession: DJIDroneSession
    
    public init(droneSession: DJIDroneSession) {
        self.droneSession = droneSession
    }
    
    public var disengageReason: Mission.Message? {
        if let attemptDisengageReason = attemptDisengageReason {
            return attemptDisengageReason
        }
        
        if state == .FlightModeJoystickComplete, let flightControllerState = droneSession.flightControllerState, flightControllerState.value.flightMode != .joystick {
            return Mission.Message(title: "MissionDisengageReason.drone.control.override.title".localized, details: flightControllerState.value.flightModeString)
        }
        
        return nil
    }
    
    public func activate() -> Bool {
        guard
            let flightController = droneSession.adapter.drone.flightController,
            let flightControllerState = droneSession.flightControllerState
        else {
            return false
        }
        
        switch state {
        case .TakeoffStart:
            if flightControllerState.value.isFlying {
                state = .TakeoffComplete
                return activate()
            }

            state = .TakeoffAttempting
            os_log(.info, log: log, "Attempting takeoff")
            flightController.startTakeoff { error in
                if let error = error {
                    self.attemptDisengageReason = Mission.Message(title: "MissionDisengageReason.take.off.failed.title".localized, details: error.localizedDescription)
                    self.deactivate()
                    return
                }
                
                os_log(.info, log: self.log, "Takeoff succeeded")
                self.state = .TakeoffComplete
            }
            return false
            
        case .TakeoffAttempting:
            return false
            
        case .TakeoffComplete:
            if flightControllerState.value.isFlying && flightControllerState.value.flightMode != .autoTakeoff {
                state = .VirtualStickStart
                return activate()
            }
            return false
            
        case .VirtualStickStart:
            if virtualStickAttemptPrevious == nil || virtualStickAttemptPrevious!.timeIntervalSinceNow < -2.0 {
                state = .VirtualStickAttempting
                virtualStickAttemptPrevious = Date()
                virtualStickAttempts += 1
                os_log(.info, log: log, "Attempting virtual stick mode control: %{public}d", virtualStickAttempts)
                flightController.setVirtualStickModeEnabled(true) { error in
                    if let error = error {
                        if self.virtualStickAttempts >= 5 {
                            self.attemptDisengageReason = Mission.Message(title: "MissionDisengageReason.take.control.failed.title".localized, details: error.localizedDescription)
                            self.deactivate()
                        }
                        else {
                            self.state = .VirtualStickStart
                        }
                        return
                    }
                    
                    os_log(.info, log: self.log, "Virtual stick mode control enabled")
                    self.flightModeJoystickAttemptingStarted = Date()
                    self.state = .FlightModeJoystickAttempting
                }
            }
            return false
            
        case .VirtualStickAttempting:
            return false
            
        case .FlightModeJoystickAttempting:
            if flightControllerState.value.flightMode == .joystick {
                os_log(.info, log: log, "Flight mode joystick achieved")
                DJISDKManager.closeConnection(whenEnteringBackground: false)
                self.state = .FlightModeJoystickComplete
                return activate()
            }
            
            if (flightModeJoystickAttemptingStarted?.timeIntervalSinceNow ?? 0) < -2.0 {
                self.attemptDisengageReason = Mission.Message(title: "MissionDisengageReason.take.control.failed.title".localized)
                self.deactivate()
                return false
            }
            
            droneSession.adapter.drone.flightController?.sendResetVelocityCommand()
            return false
            
        case .FlightModeJoystickComplete:
            return true
            
        case .Deactivated:
            return false
        }
    }
    
    public func deactivate() {
        DJISDKManager.closeConnection(whenEnteringBackground: true)
        droneSession.adapter.drone.flightController?.sendResetVelocityCommand  { error in
            self.droneSession.adapter.drone.flightController?.setVirtualStickModeEnabled(false, withCompletion: nil)
        }
        
        sendResetGimbalCommand()
        sendResetCameraCommand()
        
        state = .Deactivated
    }
    
    private func sendResetGimbalCommand() {
        droneSession.adapter.drone.gimbals?.forEach {
            $0.rotate(with: DJIGimbalRotation(
                pitchValue: $0.isAdjustPitchSupported ? -12.0.convertDegreesToRadians as NSNumber : nil,
                rollValue: $0.isAdjustRollSupported ? 0 : nil,
                yawValue: nil,
                time: DJIGimbalRotation.minTime,
                mode: .absoluteAngle), completion: nil)
        }
    }
    
    private func sendResetCameraCommand() {
        droneSession.adapter.drone.cameras?.forEach {
            if let cameraState = droneSession.cameraState(channel: $0.index)?.value {
                if (cameraState.isCapturingVideo) {
                    $0.stopRecordVideo(completion: nil)
                }
                else if (cameraState.isCapturing) {
                    $0.stopShootPhoto(completion: nil)
                }
            }
        }
    }
}
