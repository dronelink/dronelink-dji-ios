//
//  DJIDroneSession+RemoteControllerCommand.swift.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/25/21.
//  Copyright © 2021 Dronelink. All rights reserved.
//
import DronelinkCore
import DJISDK
import os

extension DJIDroneSession {
    func execute(remoteControllerCommand: KernelRemoteControllerCommand, finished: @escaping CommandFinished) -> Error? {
        guard
            let remoteController = adapter.drone.remoteController(channel: remoteControllerCommand.channel)
        else {
            return "MissionDisengageReason.drone.remote.controller.unavailable.title".localized
        }
        
        if let command = remoteControllerCommand as? Kernel.TargetGimbalChannelRemoteControllerCommand {
            remoteController.getControllingGimbalIndex { (current, error) in
                Command.conditionallyExecute(current != command.targetGimbalChannel, error: error, finished: finished) {
                    remoteController.setControllingGimbalIndex(command.targetGimbalChannel, withCompletion: finished)
                }
            }

            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
