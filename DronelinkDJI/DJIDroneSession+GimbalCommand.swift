//
//  DJIDroneSession+GimbalCommand.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/28/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import DJISDK

extension DJIDroneSession {
    func execute(gimbalCommand: KernelGimbalCommand, finished: @escaping CommandFinished) -> Error? {
        guard
            let gimbal = adapter.drone.gimbal(channel: gimbalCommand.channel),
            let state = gimbalState(channel: gimbalCommand.channel)?.value
        else {
            return "MissionDisengageReason.drone.gimbal.unavailable.title".localized
        }
        
        if let command = gimbalCommand as? Kernel.ModeGimbalCommand {
            Command.conditionallyExecute(command.mode != state.kernelMode, finished: finished) {
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
            
            //KLUGE: unable to check the gimbal mode right now because of a DJI SDK bug (it always reports yawFollow for certain cameras like the X7)
            if /*state.kernelMode == .free,*/ let yaw = command.orientation.yaw {
                //use relative angle because absolute angle for yaw is not predictable
                gimbal.rotate(with: DJIGimbalRotation(
                    pitchValue: gimbal.isAdjustPitchSupported ? pitch?.convertDegreesToRadians.angleDifferenceSigned(angle: state.kernelOrientation.pitch).convertRadiansToDegrees as NSNumber? : nil,
                    rollValue: gimbal.isAdjustRollSupported ? roll?.convertDegreesToRadians.angleDifferenceSigned(angle: state.kernelOrientation.roll).convertRadiansToDegrees as NSNumber? : nil,
                    yawValue: yaw.angleDifferenceSigned(angle: state.kernelOrientation.yaw).convertRadiansToDegrees as NSNumber,
                    time: DJIGimbalRotation.minTime,
                    mode: .relativeAngle,
                    ignore: false), completion: finished)
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
                ignore: false), completion: finished)
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
}
