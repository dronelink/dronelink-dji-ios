//
//  DJIVirtualStickSession.swift
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

public class DJIVirtualStickSession: DroneControlSession {
    
    private static let log = OSLog(subsystem: "DronelinkDJI", category: "DJIVirtualStickSession")
    
    private enum State {
        case TakeoffStart
        case TakeoffAttempting
        case TakeoffComplete
        case SoftSwitchJoystickModeStart
        case SoftSwitchJoystickModeAttempting
        case VirtualStickStart
        case VirtualStickAttempting
        case FlightModeJoystickAttempting
        case FlightModeJoystickComplete
        case Deactivated
    }
    
    public let executionEngine = Kernel.ExecutionEngine.dronelinkKernel
    public let reengaging: Bool = false
    private let droneSession: DJIDroneSession
    
    private var state = State.TakeoffStart
    private var virtualStickAttempts = 0
    private var virtualStickAttemptPrevious: Date?
    private var flightModeJoystickAttemptingStarted: Date?
    private var _disengageReason: Kernel.Message?
    
    public init(droneSession: DJIDroneSession) {
        self.droneSession = droneSession
    }
    
    public var disengageReason: Kernel.Message? {
        if let attemptDisengageReason = _disengageReason {
            return attemptDisengageReason
        }
        
        if let flightControllerState = droneSession.flightControllerState {
            if state == .FlightModeJoystickComplete {
                if flightControllerState.value.flightMode != .joystick {
                    return Kernel.Message(title: "MissionDisengageReason.drone.control.override.title".localized, details: "MissionDisengageReason.drone.control.override.details".localized)
                }
            }
        }
        
        return nil
    }
    
    public func activate() -> Bool? {
        guard
            let flightController = droneSession.adapter.drone.flightController,
            let flightControllerState = droneSession.flightControllerState
        else {
            deactivate()
            return false
        }
        
        switch state {
        case .TakeoffStart:
            if flightControllerState.value.isFlying {
                state = .TakeoffComplete
                return activate()
            }

            state = .TakeoffAttempting
            os_log(.info, log: DJIVirtualStickSession.log, "Attempting precision takeoff")
            flightController.startPrecisionTakeoff {[weak self] error in
                if let error = error {
                    os_log(.error, log: DJIVirtualStickSession.log, "Precision takeoff failed: %{public}s", error.localizedDescription)
                    os_log(.info, log: DJIVirtualStickSession.log, "Attempting takeoff")
                    flightController.startTakeoff { error in
                        if let error = error {
                            os_log(.error, log: DJIVirtualStickSession.log, "Takeoff failed: %{public}s", error.localizedDescription)
                           self?._disengageReason = Kernel.Message(title: "MissionDisengageReason.take.off.failed.title".localized, details: error.localizedDescription)
                           self?.deactivate()
                           return
                        }

                        os_log(.info, log: DJIVirtualStickSession.log, "Takeoff succeeded")
                        self?.state = .TakeoffComplete
                    }
                    return
                }
                
                os_log(.info, log: DJIVirtualStickSession.log, "Precision takeoff succeeded")
                self?.state = .TakeoffComplete
            }
            return nil
            
        case .TakeoffAttempting:
            return nil
            
        case .TakeoffComplete:
            if flightControllerState.value.isFlying && flightControllerState.value.flightMode != .autoTakeoff {
                state = .SoftSwitchJoystickModeStart
                return activate()
            }
            return nil
            
        case .SoftSwitchJoystickModeStart:
            guard let remoteController = droneSession.adapter.drone.remoteController else {
                state = .VirtualStickStart
                return activate()
            }
            
            state = .SoftSwitchJoystickModeAttempting
            os_log(.info, log: DJIVirtualStickSession.log, "Verifying soft switch joystick mode")
            remoteController.getSoftSwitchJoyStickMode { [weak self] (mode: DJIRCSoftSwitchJoyStickMode, error: Error?) in
                if error != nil && mode != ._P {
                    os_log(.info, log: DJIVirtualStickSession.log, "Changing soft switch joystick mode to P")
                    remoteController.setSoftSwitchJoyStickMode(._P) { error in
                        //if try to activate virtual stick immediately it can fail, so delay
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                            self?.state = .VirtualStickStart
                        }
                    }
                    return
                }
                
                self?.state = .VirtualStickStart
            }
            return nil
            
        case .SoftSwitchJoystickModeAttempting:
            return nil
            
        case .VirtualStickStart:
            if virtualStickAttemptPrevious == nil || virtualStickAttemptPrevious!.timeIntervalSinceNow < -2.0 {
                state = .VirtualStickAttempting
                virtualStickAttemptPrevious = Date()
                virtualStickAttempts += 1
                os_log(.info, log: DJIVirtualStickSession.log, "Attempting virtual stick mode control: %{public}d", virtualStickAttempts)
                flightController.setVirtualStickModeEnabled(true) { [weak self] error in
                    guard let controlSession = self else {
                        return
                    }
                    
                    if let error = error {
                        if controlSession.virtualStickAttempts >= 5 {
                            controlSession._disengageReason = Kernel.Message(title: "MissionDisengageReason.take.control.failed.title".localized, details: error.localizedDescription)
                            controlSession.deactivate()
                        }
                        else {
                            controlSession.state = .VirtualStickStart
                        }
                        return
                    }
                    
                    os_log(.info, log: DJIVirtualStickSession.log, "Virtual stick mode control enabled")
                    controlSession.flightModeJoystickAttemptingStarted = Date()
                    controlSession.state = .FlightModeJoystickAttempting
                }
            }
            return nil
            
        case .VirtualStickAttempting:
            return nil
            
        case .FlightModeJoystickAttempting:
            if flightControllerState.value.flightMode == .joystick {
                os_log(.info, log: DJIVirtualStickSession.log, "Flight mode joystick achieved")
                DJISDKManager.closeConnection(whenEnteringBackground: false)
                self.state = .FlightModeJoystickComplete
                return activate()
            }
            
            if (flightModeJoystickAttemptingStarted?.timeIntervalSinceNow ?? 0) < -2.0 {
                self._disengageReason = Kernel.Message(title: "MissionDisengageReason.take.control.failed.title".localized)
                self.deactivate()
                return false
            }
            
            droneSession.sendResetVelocityCommand()
            return nil
            
        case .FlightModeJoystickComplete:
            return true
            
        case .Deactivated:
            return false
        }
    }
    
    public func deactivate() {
        droneSession.sendResetVelocityCommand()
        droneSession.adapter.drone.flightController?.setVirtualStickModeEnabled(false, withCompletion: nil)
        state = .Deactivated
        DJISDKManager.closeConnection(whenEnteringBackground: true)
    }
}
