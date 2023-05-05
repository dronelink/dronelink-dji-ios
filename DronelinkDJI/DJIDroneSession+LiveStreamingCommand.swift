//
//  DJIDroneSession+LiveStreamingCommand.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 5/1/23.
//  Copyright © 2023 Dronelink. All rights reserved.
//
import DronelinkCore
import CoreLocation
import DJISDK
import DJIWidget

extension DJIDroneSession {
    func execute(liveStreamingCommand: KernelLiveStreamingCommand, finished: @escaping CommandFinished) -> Error? {
        guard let rtmpMuxer = DJIRtmpMuxer.sharedInstance() else {
            return "MissionDisengageReason.drone.live.streaming.unavailable.title".localized
        }
        
        if let command = liveStreamingCommand as? Kernel.ModuleLiveStreamingCommand {
            if command.enabled {
                DispatchQueue.main.async {
                    rtmpMuxer.setupVideoPreviewer(DJIVideoPreviewer.instance())
                    rtmpMuxer.enableAudio = true
                    rtmpMuxer.muteAudio = true
                    rtmpMuxer.enabled = true
                    rtmpMuxer.retryCount = 3
                    if rtmpMuxer.start() {
                        finished(nil)
                    }
                    else {
                        finished("MissionDisengageReason.drone.live.streaming.failed.title".localized)
                    }
                }
                return nil
            }
            
            rtmpMuxer.stop()
            rtmpMuxer.enabled = false
            finished(nil)
            return nil
        }
        
        if let command = liveStreamingCommand as? KernelRTMPLiveStreamingCommand {
            return execute(rtmpLiveStreamingCommand: command, rtmpMuxer: rtmpMuxer, finished: finished)
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(rtmpLiveStreamingCommand: KernelRTMPLiveStreamingCommand, rtmpMuxer: DJIRtmpMuxer, finished: @escaping CommandFinished) -> Error? {
        if let command = rtmpLiveStreamingCommand as? Kernel.RTMPSettingsLiveStreamingCommand {
            rtmpMuxer.serverURL = command.url
            finished(nil)
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
