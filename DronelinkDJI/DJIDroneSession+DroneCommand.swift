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
        if let command = droneCommand as? MissionDroneFlightAssistantCommand {
            return execute(flightAssistantCommand: command, finished: finished)
        }
        
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
            flightController.getConnectionFailSafeBehavior { (current, error) in
                Command.conditionallyExecute(current != command.connectionFailSafeBehavior.djiValue, error: error, finished: finished) {
                    flightController.setConnectionFailSafeBehavior(command.connectionFailSafeBehavior.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = droneCommand as? Mission.LowBatteryWarningThresholdDroneCommand {
            flightController.getLowBatteryWarningThreshold { (current, error) in
                let target = UInt8(command.lowBatteryWarningThreshold * 100)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    flightController.setLowBatteryWarningThreshold(target, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = droneCommand as? Mission.MaxAltitudeDroneCommand {
            flightController.getMaxFlightHeight { (current, error) in
                let target = UInt(command.maxAltitude)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    flightController.setMaxFlightHeight(target, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = droneCommand as? Mission.MaxDistanceDroneCommand {
            flightController.getMaxFlightRadius { (current, error) in
                let target = UInt(command.maxDistance)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    flightController.setMaxFlightRadius(target, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = droneCommand as? Mission.MaxDistanceLimitationDroneCommand {
            flightController.getMaxFlightRadiusLimitationEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightController.setMaxFlightRadiusLimitationEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = droneCommand as? Mission.SmartReturnHomeDroneCommand {
            flightController.getSmartReturnToHomeEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightController.setSmartReturnToHomeEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = droneCommand as? Mission.ReturnHomeAltitudeDroneCommand {
            flightController.getGoHomeHeightInMeters { (current, error) in
                let target = UInt(command.returnHomeAltitude)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    flightController.setGoHomeHeightInMeters(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = droneCommand as? Mission.SeriousLowBatteryWarningThresholdDroneCommand {
            flightController.getSeriousLowBatteryWarningThreshold { (current, error) in
                let target = UInt8(command.seriousLowBatteryWarningThreshold * 100)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    flightController.setSeriousLowBatteryWarningThreshold(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = droneCommand as? Mission.VisionAssistedPositioningDroneCommand {
            flightController.getVisionAssistedPositioningEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightController.setVisionAssistedPositioningEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(flightAssistantCommand: MissionDroneFlightAssistantCommand, finished: @escaping CommandFinished) -> Error? {
        guard let flightAssistant = adapter.drone.flightController?.flightAssistant else {
            return "MissionDisengageReason.drone.flight.assistant.unavailable.title".localized
        }
        
        if let command = flightAssistantCommand as? Mission.CollisionAvoidanceDroneCommand {
            flightAssistant.getCollisionAvoidanceEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setCollisionAvoidanceEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = flightAssistantCommand as? Mission.LandingProtectionDroneCommand {
            flightAssistant.getLandingProtectionEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setLandingProtectionEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = flightAssistantCommand as? Mission.PrecisionLandingDroneCommand {
            flightAssistant.getPrecisionLandingEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setPrecisionLandingEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = flightAssistantCommand as? Mission.ReturnHomeObstacleAvoidanceDroneCommand {
            flightAssistant.getRTHObstacleAvoidanceEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setRTHObstacleAvoidanceEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = flightAssistantCommand as? Mission.ReturnHomeRemoteObstacleAvoidanceDroneCommand {
            flightAssistant.getRTHRemoteObstacleAvoidanceEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setRTHRemoteObstacleAvoidanceEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = flightAssistantCommand as? Mission.UpwardsAvoidanceDroneCommand {
            flightAssistant.getUpwardsAvoidanceEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setUpwardsAvoidanceEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(landingGearCommand: MissionDroneLandingGearCommand, finished: @escaping CommandFinished) -> Error? {
        guard let landingGear = adapter.drone.flightController?.landingGear else {
            return "MissionDisengageReason.drone.landing.gear.unavailable.title".localized
        }
        
        if let command = landingGearCommand as? Mission.LandingGearAutomaticMovementDroneCommand {
            landingGear.getAutomaticMovementEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    landingGear.setAutomaticMovementEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }

        if landingGearCommand is Mission.LandingGearDeployDroneCommand {
            Command.conditionallyExecute(!(landingGear.state == .deployed || landingGear.state == .deploying), finished: finished) {
                landingGear.deploy(completion: finished)
            }
            return nil
        }
        
        if landingGearCommand is Mission.LandingGearRetractDroneCommand {
            Command.conditionallyExecute(!(landingGear.state == .retracted || landingGear.state == .retracting), finished: finished) {
                landingGear.retract(completion: finished)
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(lightbridgeCommand: MissionDroneLightbridgeCommand, finished: @escaping CommandFinished) -> Error? {
        guard let lightbridgeLink = adapter.drone.airLink?.lightbridgeLink else {
            return "MissionDisengageReason.drone.lightbridge.unavailable.title".localized
        }
        
        if let command = lightbridgeCommand as? Mission.LightbridgeChannelDroneCommand {
            lightbridgeLink.getChannelNumber { (current, error) in
                let target = Int32(command.lightbridgeChannel)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    lightbridgeLink.setChannelNumber(target, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = lightbridgeCommand as? Mission.LightbridgeChannelSelectionModeDroneCommand {
            lightbridgeLink.getChannelSelectionMode { (current, error) in
                Command.conditionallyExecute(current != command.lightbridgeChannelSelectionMode.djiValue, error: error, finished: finished) {
                    lightbridgeLink.setChannelSelectionMode(command.lightbridgeChannelSelectionMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = lightbridgeCommand as? Mission.LightbridgeFrequencyBandDroneCommand {
            lightbridgeLink.getFrequencyBand { (current, error) in
                Command.conditionallyExecute(current != command.lightbridgeFrequencyBand.djiValue, error: error, finished: finished) {
                    lightbridgeLink.setFrequencyBand(command.lightbridgeFrequencyBand.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(ocuSyncCommand: MissionDroneOcuSyncCommand, finished: @escaping CommandFinished) -> Error? {
        guard let ocuSyncLink = adapter.drone.airLink?.ocuSyncLink else {
            return "MissionDisengageReason.drone.ocusync.unavailable.title".localized
        }
        
        if let command = ocuSyncCommand as? Mission.OcuSyncChannelDroneCommand {
            ocuSyncLink.getChannelNumber { (current, error) in
                let target = UInt(command.ocuSyncChannel)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    ocuSyncLink.setChannelNumber(target, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = ocuSyncCommand as? Mission.OcuSyncChannelSelectionModeDroneCommand {
            ocuSyncLink.getChannelSelectionMode { (current, error) in
                Command.conditionallyExecute(current != command.ocuSyncChannelSelectionMode.djiValue, error: error, finished: finished) {
                    ocuSyncLink.setChannelSelectionMode(command.ocuSyncChannelSelectionMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = ocuSyncCommand as? Mission.OcuSyncFrequencyBandDroneCommand {
            ocuSyncLink.getFrequencyBand { (current, error) in
                Command.conditionallyExecute(current != command.ocuSyncFrequencyBand.djiValue, error: error, finished: finished) {
                    ocuSyncLink.setFrequencyBand(command.ocuSyncFrequencyBand.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
