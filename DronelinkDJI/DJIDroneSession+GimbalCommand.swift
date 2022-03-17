//
//  DJIDroneSession+GimbalCommand.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/28/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import DJISDK
import os

extension DJIDroneSession {
    func execute(gimbalCommand: KernelGimbalCommand, finished: @escaping CommandFinished) -> Error? {
        guard
            let gimbal = adapter.drone.gimbal(channel: gimbalCommand.channel),
            let state = gimbalState(channel: gimbalCommand.channel)?.value
        else {
            return "MissionDisengageReason.drone.gimbal.unavailable.title".localized
        }
        
        if let command = gimbalCommand as? Kernel.ModeGimbalCommand {
            Command.conditionallyExecute(command.mode != state.mode, finished: finished) {
                gimbal.setMode(command.mode.djiValue) { error in
                    if let error = error {
                        finished(error)
                        return
                    }

                    //if we don't give it a delay, subsequent gimbal attitude or reset commands that are issued immediately are ignored
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        if command.mode == .yawFollow {
                            gimbal.reset(completion: finished)
                        }
                        else {
                            finished(nil)
                        }
                    }
                }
            }
            return nil
        }
        
        if let command = gimbalCommand as? Kernel.OrientationGimbalCommand {
            if (command.orientation.pitch == nil && command.orientation.roll == nil && command.orientation.yaw == nil) {
                finished(nil)
                return nil
            }
            
            var pitch = command.orientation.pitch?.convertRadiansToDegrees
            if let pitchValid = pitch, abs(pitchValid + 90) < 0.1 {
                pitch = -89.9
            }
            
            let roll = command.orientation.roll?.convertRadiansToDegrees
            
            if let yaw = command.orientation.yaw, state.mode == .free {
                //use relative angle because absolute angle for yaw is not predictable
                gimbal.rotate(with: DJIGimbalRotation(
                    pitchValue: gimbal.isAdjustPitchSupported ? pitch?.convertDegreesToRadians.angleDifferenceSigned(angle: state.orientation.pitch).convertRadiansToDegrees as NSNumber? : nil,
                    rollValue: gimbal.isAdjustRollSupported ? roll?.convertDegreesToRadians.angleDifferenceSigned(angle: state.orientation.roll).convertRadiansToDegrees as NSNumber? : nil,
                    yawValue: yaw.angleDifferenceSigned(angle: state.orientation.yaw).convertRadiansToDegrees as NSNumber,
                    time: DJIGimbalRotation.minTime,
                    mode: .relativeAngle,
                    ignore: false)) { [weak self] error in
                    if error != nil {
                        finished(error)
                        return
                    }
                    
                    self?.gimbalCommandFinishOrientationVerify(gimbalCommand: command, finished: finished)
                }
                return nil
            }
            
            if pitch == nil && roll == nil {
                finished(nil)
                return nil
            }
            
            gimbal.rotate(with: DJIGimbalRotation(
                pitchValue: gimbal.isAdjustPitchSupported ? pitch as NSNumber? : nil,
                rollValue: gimbal.isAdjustRollSupported ? roll as NSNumber? : nil,
                yawValue: nil,
                time: DJIGimbalRotation.minTime,
                mode: .absoluteAngle,
                ignore: false)) { [weak self] error in
                if error != nil {
                    finished(error)
                    return
                }
                
                self?.gimbalCommandFinishOrientationVerify(gimbalCommand: command, finished: finished)
            }
            return nil
        }
        
        if let command = gimbalCommand as? Kernel.YawSimultaneousFollowGimbalCommand {
            gimbal.getYawSimultaneousFollowEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    gimbal.setYawSimultaneousFollowEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func gimbalCommandFinishOrientationVerify(gimbalCommand: Kernel.OrientationGimbalCommand, attempt: Int = 0, maxAttempts: Int = 20, threshold: Double = 2.0.convertDegreesToRadians, finished: @escaping CommandFinished) {
        guard
            let gimbal = adapter.drone.gimbal(channel: gimbalCommand.channel),
            let state = gimbalState(channel: gimbalCommand.channel)?.value as? DJIGimbalStateAdapter
        else {
            finished("MissionDisengageReason.drone.gimbal.unavailable.title".localized)
            return
        }
        
        if attempt >= maxAttempts {
            finished("DJIDroneSession+GimbalCommand.orientation.not.achieved".localized)
            return
        }
        
        var verified = true
        if let pitch = gimbalCommand.orientation.pitch, gimbal.isAdjustPitchSupported {
            verified = verified && abs(state.orientation.pitch.angleDifferenceSigned(angle: pitch)) <= threshold
        }
        
        if let roll = gimbalCommand.orientation.roll, gimbal.isAdjustRollSupported {
            verified = verified && abs(state.orientation.roll.angleDifferenceSigned(angle: roll)) <= threshold
        }
        
        if let yaw = gimbalCommand.orientation.yaw, state.mode == .free {
            verified = verified && abs(state.orientation.yaw.angleDifferenceSigned(angle: yaw)) <= threshold
        }
        
        if verified {
            finished(nil)
            return
        }
        
        os_log(.debug, log: DJIDroneSession.log, "Gimbal command finished and waiting for orientation (%{public}d)... (%{public}s)", attempt, gimbalCommand.id)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.gimbalCommandFinishOrientationVerify(gimbalCommand: gimbalCommand, attempt: attempt + 1, maxAttempts: maxAttempts, threshold: threshold, finished: finished)
        }
    }
}
