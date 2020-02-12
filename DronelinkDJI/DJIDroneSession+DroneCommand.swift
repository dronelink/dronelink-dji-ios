//
//  DJIDroneSession+DroneCommand.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/28/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore

extension DJIDroneSession {
    func execute(droneCommand: MissionDroneCommand, finished: @escaping CommandFinished) -> Error? {
        if let command = droneCommand as? MissionDroneLandingGearCommand {
            return execute(landingGearCommand: command, finished: finished)
        }
        
        if let command = droneCommand as? MissionDroneLightbridgeCommand {
            return execute(lightbridgeCommand: command, finished: finished)
        }
        
        if let command = droneCommand as? MissionDroneOcuSyncCommand {
            return execute(ocuSyncCommand: command, finished: finished)
        }
        
        guard let flightController = adapter.drone.flightController else {
            return "MissionDisengageReason.drone.control.unavailable.title".localized
        }
        
        if let command = droneCommand as? Mission.ConnectionFailSafeBehaviorDroneCommand {
            flightController.setConnectionFailSafeBehavior(command.connectionFailSafeBehavior.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = droneCommand as? Mission.LowBatteryWarningThresholdDroneCommand {
            flightController.setLowBatteryWarningThreshold(UInt8(command.lowBatteryWarningThreshold * 100), withCompletion: finished)
            return nil
        }

        if let command = droneCommand as? Mission.MaxAltitudeDroneCommand {
            flightController.setMaxFlightHeight(UInt(command.maxAltitude), withCompletion: finished)
            return nil
        }

        if let command = droneCommand as? Mission.MaxDistanceDroneCommand {
            flightController.setMaxFlightRadiusLimitationEnabled(true, withCompletion: { error in
                if let error = error {
                    finished(error)
                    return
                }
                flightController.setMaxFlightRadius(UInt(command.maxDistance), withCompletion: finished)
            })
            return nil
        }

        if let command = droneCommand as? Mission.ReturnHomeAltitudeDroneCommand {
            flightController.setGoHomeHeightInMeters(UInt(command.returnHomeAltitude), withCompletion: finished)
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(landingGearCommand: MissionDroneLandingGearCommand, finished: @escaping CommandFinished) -> Error? {
        guard let landingGear = adapter.drone.flightController?.landingGear else {
            return "MissionDisengageReason.drone.landing.gear.unavailable.title".localized
        }
        
        if let command = landingGearCommand as? Mission.LandingGearAutomaticMovementDroneCommand {
            landingGear.setAutomaticMovementEnabled(command.enabled, withCompletion: finished)
            return nil
        }

        if let command = landingGearCommand as? Mission.LandingGearDeployDroneCommand {
            landingGear.deploy(completion: finished)
            return nil
        }
        
        if let command = landingGearCommand as? Mission.LandingGearRetractDroneCommand {
            landingGear.retract(completion: finished)
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(lightbridgeCommand: MissionDroneLightbridgeCommand, finished: @escaping CommandFinished) -> Error? {
        guard let lightbridgeLink = adapter.drone.airLink?.lightbridgeLink else {
            return "MissionDisengageReason.drone.lightbridge.unavailable.title".localized
        }
        
        if let command = lightbridgeCommand as? Mission.LightbridgeChannelDroneCommand {
            lightbridgeLink.setChannelNumber(Int32(command.lightbridgeChannel), withCompletion: finished)
            return nil
        }

        if let command = lightbridgeCommand as? Mission.LightbridgeChannelSelectionModeDroneCommand {
            lightbridgeLink.setChannelSelectionMode(command.lightbridgeChannelSelectionMode.djiValue, withCompletion: finished)
            return nil
        }

        if let command = lightbridgeCommand as? Mission.LightbridgeFrequencyBandDroneCommand {
            lightbridgeLink.setFrequencyBand(command.lightbridgeFrequencyBand.djiValue, withCompletion: finished)
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(ocuSyncCommand: MissionDroneOcuSyncCommand, finished: @escaping CommandFinished) -> Error? {
        guard let ocuSyncLink = adapter.drone.airLink?.ocuSyncLink else {
            return "MissionDisengageReason.drone.ocusync.unavailable.title".localized
        }
        
        if let command = ocuSyncCommand as? Mission.OcuSyncChannelDroneCommand {
            ocuSyncLink.setChannelNumber(UInt(command.ocuSyncChannel), withCompletion: finished)
            return nil
        }

        if let command = ocuSyncCommand as? Mission.OcuSyncChannelSelectionModeDroneCommand {
            ocuSyncLink.setChannelSelectionMode(command.ocuSyncChannelSelectionMode.djiValue, withCompletion: finished)
            return nil
        }

        if let command = ocuSyncCommand as? Mission.OcuSyncFrequencyBandDroneCommand {
            ocuSyncLink.setFrequencyBand(command.ocuSyncFrequencyBand.djiValue, withCompletion: finished)
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
