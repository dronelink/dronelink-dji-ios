//
//  DJIDroneSession+DroneCommand.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/28/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import CoreLocation

extension DJIDroneSession {
    func execute(droneCommand: KernelDroneCommand, finished: @escaping CommandFinished) -> Error? {
        if let command = droneCommand as? KernelDroneFlightAssistantCommand {
            return execute(flightAssistantCommand: command, finished: finished)
        }
        
        if let command = droneCommand as? KernelDroneLandingGearCommand {
            return execute(landingGearCommand: command, finished: finished)
        }
        
        if let command = droneCommand as? KernelDroneLightbridgeCommand {
            return execute(lightbridgeCommand: command, finished: finished)
        }
        
        if let command = droneCommand as? KernelDroneOcuSyncCommand {
            return execute(ocuSyncCommand: command, finished: finished)
        }
        
        guard let flightController = adapter.drone.flightController else {
            return "MissionDisengageReason.drone.control.unavailable.title".localized
        }
        
        if let command = droneCommand as? Kernel.ConnectionFailSafeBehaviorDroneCommand {
            flightController.getConnectionFailSafeBehavior { (current, error) in
                Command.conditionallyExecute(current != command.connectionFailSafeBehavior.djiValue, error: error, finished: finished) {
                    flightController.setConnectionFailSafeBehavior(command.connectionFailSafeBehavior.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = droneCommand as? Kernel.HomeLocationDroneCommand {
            flightController.setHomeLocation(CLLocation(latitude: command.coordinate.latitude, longitude: command.coordinate.longitude), withCompletion: finished)
            return nil
        }
        
        if let command = droneCommand as? Kernel.LowBatteryWarningThresholdDroneCommand {
            flightController.getLowBatteryWarningThreshold { (current, error) in
                let target = UInt8(command.lowBatteryWarningThreshold * 100)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    flightController.setLowBatteryWarningThreshold(target, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = droneCommand as? Kernel.MaxAltitudeDroneCommand {
            flightController.getMaxFlightHeight { (current, error) in
                let target = UInt(command.maxAltitude)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    flightController.setMaxFlightHeight(target, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = droneCommand as? Kernel.MaxDistanceDroneCommand {
            flightController.getMaxFlightRadius { (current, error) in
                let target = UInt(command.maxDistance)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    flightController.setMaxFlightRadius(target, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = droneCommand as? Kernel.MaxDistanceLimitationDroneCommand {
            flightController.getMaxFlightRadiusLimitationEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightController.setMaxFlightRadiusLimitationEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = droneCommand as? Kernel.SmartReturnHomeDroneCommand {
            flightController.getSmartReturnToHomeEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightController.setSmartReturnToHomeEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = droneCommand as? Kernel.ReturnHomeAltitudeDroneCommand {
            flightController.getGoHomeHeightInMeters { (current, error) in
                let target = UInt(command.returnHomeAltitude)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    flightController.setGoHomeHeightInMeters(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = droneCommand as? Kernel.SeriousLowBatteryWarningThresholdDroneCommand {
            flightController.getSeriousLowBatteryWarningThreshold { (current, error) in
                let target = UInt8(command.seriousLowBatteryWarningThreshold * 100)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    flightController.setSeriousLowBatteryWarningThreshold(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = droneCommand as? Kernel.VisionAssistedPositioningDroneCommand {
            flightController.getVisionAssistedPositioningEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightController.setVisionAssistedPositioningEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(flightAssistantCommand: KernelDroneFlightAssistantCommand, finished: @escaping CommandFinished) -> Error? {
        guard let flightAssistant = adapter.drone.flightController?.flightAssistant else {
            return "MissionDisengageReason.drone.flight.assistant.unavailable.title".localized
        }
        
        if let command = flightAssistantCommand as? Kernel.CollisionAvoidanceDroneCommand {
            flightAssistant.getCollisionAvoidanceEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setCollisionAvoidanceEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = flightAssistantCommand as? Kernel.LandingProtectionDroneCommand {
            flightAssistant.getLandingProtectionEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setLandingProtectionEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = flightAssistantCommand as? Kernel.PrecisionLandingDroneCommand {
            flightAssistant.getPrecisionLandingEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setPrecisionLandingEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = flightAssistantCommand as? Kernel.ReturnHomeObstacleAvoidanceDroneCommand {
            flightAssistant.getRTHObstacleAvoidanceEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setRTHObstacleAvoidanceEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = flightAssistantCommand as? Kernel.ReturnHomeRemoteObstacleAvoidanceDroneCommand {
            flightAssistant.getRTHRemoteObstacleAvoidanceEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setRTHRemoteObstacleAvoidanceEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = flightAssistantCommand as? Kernel.UpwardsAvoidanceDroneCommand {
            flightAssistant.getUpwardVisionObstacleAvoidanceEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    flightAssistant.setUpwardVisionObstacleAvoidanceEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(landingGearCommand: KernelDroneLandingGearCommand, finished: @escaping CommandFinished) -> Error? {
        guard let landingGear = adapter.drone.flightController?.landingGear else {
            return "MissionDisengageReason.drone.landing.gear.unavailable.title".localized
        }
        
        if let command = landingGearCommand as? Kernel.LandingGearAutomaticMovementDroneCommand {
            landingGear.getAutomaticMovementEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    landingGear.setAutomaticMovementEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }

        if landingGearCommand is Kernel.LandingGearDeployDroneCommand {
            Command.conditionallyExecute(!(landingGear.state == .deployed || landingGear.state == .deploying), finished: finished) {
                landingGear.deploy(completion: finished)
            }
            return nil
        }
        
        if landingGearCommand is Kernel.LandingGearRetractDroneCommand {
            Command.conditionallyExecute(!(landingGear.state == .retracted || landingGear.state == .retracting), finished: finished) {
                landingGear.retract(completion: finished)
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(lightbridgeCommand: KernelDroneLightbridgeCommand, finished: @escaping CommandFinished) -> Error? {
        guard let lightbridgeLink = adapter.drone.airLink?.lightbridgeLink else {
            return "MissionDisengageReason.drone.lightbridge.unavailable.title".localized
        }
        
        if let command = lightbridgeCommand as? Kernel.LightbridgeChannelDroneCommand {
            lightbridgeLink.getChannelNumber { (current, error) in
                let target = Int32(command.lightbridgeChannel)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    lightbridgeLink.setChannelNumber(target, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = lightbridgeCommand as? Kernel.LightbridgeChannelSelectionModeDroneCommand {
            lightbridgeLink.getChannelSelectionMode { (current, error) in
                Command.conditionallyExecute(current != command.lightbridgeChannelSelectionMode.djiValue, error: error, finished: finished) {
                    lightbridgeLink.setChannelSelectionMode(command.lightbridgeChannelSelectionMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = lightbridgeCommand as? Kernel.LightbridgeFrequencyBandDroneCommand {
            lightbridgeLink.getFrequencyBand { (current, error) in
                Command.conditionallyExecute(current != command.lightbridgeFrequencyBand.djiValue, error: error, finished: finished) {
                    lightbridgeLink.setFrequencyBand(command.lightbridgeFrequencyBand.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func execute(ocuSyncCommand: KernelDroneOcuSyncCommand, finished: @escaping CommandFinished) -> Error? {
        guard let ocuSyncLink = adapter.drone.airLink?.ocuSyncLink else {
            return "MissionDisengageReason.drone.ocusync.unavailable.title".localized
        }
        
        if let command = ocuSyncCommand as? Kernel.OcuSyncChannelDroneCommand {
            ocuSyncLink.getChannelNumber { (current, error) in
                let target = UInt(command.ocuSyncChannel)
                Command.conditionallyExecute(current != target, error: error, finished: finished) {
                    ocuSyncLink.setChannelNumber(target, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = ocuSyncCommand as? Kernel.OcuSyncChannelSelectionModeDroneCommand {
            ocuSyncLink.getChannelSelectionMode { (current, error) in
                Command.conditionallyExecute(current != command.ocuSyncChannelSelectionMode.djiValue, error: error, finished: finished) {
                    ocuSyncLink.setChannelSelectionMode(command.ocuSyncChannelSelectionMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }

        if let command = ocuSyncCommand as? Kernel.OcuSyncFrequencyBandDroneCommand {
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
