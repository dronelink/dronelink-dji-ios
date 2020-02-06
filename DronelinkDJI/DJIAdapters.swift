//
//  DJIFlightControllerStateWrapper.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/26/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import DJISDK

public class DJIDroneAdapter: DroneAdapter {
    public let drone: DJIAircraft
    private var gimbalAdapters: [UInt: DJIGimbalAdapter] = [:]

    public init(drone: DJIAircraft) {
        self.drone = drone
    }

    public var cameras: [CameraAdapter]? { drone.cameras }
    public func camera(channel: UInt) -> CameraAdapter? { cameras?[safeIndex: Int(channel)] }
    public var gimbals: [GimbalAdapter]? {
        if let gimbals = drone.gimbals {
            var gimbalAdapters: [GimbalAdapter] = []
            gimbals.forEach { gimbal in
                if let gimbalAdapter = self.gimbal(channel: gimbal.index) {
                    gimbalAdapters.append(gimbalAdapter)
                }
            }
            return gimbalAdapters
        }
        return nil
    }
    
    public func gimbal(channel: UInt) -> GimbalAdapter? {
        if let gimbalAdapter = gimbalAdapters[channel] {
            return gimbalAdapter
        }
        
        if let gimbal = drone.gimbals?[safeIndex: Int(channel)] {
            let gimbalAdapter = DJIGimbalAdapter(gimbal: gimbal)
            gimbalAdapters[channel] = gimbalAdapter
            return gimbalAdapter
        }
        
        return nil
    }

    public func send(velocityCommand: Mission.VelocityDroneCommand?) {
        guard let velocityCommand = velocityCommand else {
            sendResetVelocityCommand()
            return
        }
        
        guard let flightController = drone.flightController else { return }
        
        flightController.isVirtualStickAdvancedModeEnabled = true
        flightController.rollPitchControlMode = .velocity
        flightController.rollPitchCoordinateSystem = .ground
        flightController.verticalControlMode = .velocity
        flightController.yawControlMode = velocityCommand.heading == nil ? .angularVelocity : .angle
        
        var horizontal = velocityCommand.velocity.horizontal
        horizontal.magnitude = min(DJIAircraft.maxVelocity, horizontal.magnitude)
        flightController.send(DJIVirtualStickFlightControlData(
            pitch: Float(horizontal.y),
            roll: Float(horizontal.x),
            yaw: velocityCommand.heading == nil ? Float(velocityCommand.velocity.rotational.convertRadiansToDegrees) : Float(velocityCommand.heading!.angleDifferenceSigned(angle: 0).convertRadiansToDegrees),
            verticalThrottle: Float(velocityCommand.velocity.vertical)), withCompletion: nil)
    }
    
    public func startGoHome(finished: CommandFinished?) {
        drone.flightController?.startGoHome(completion: finished)
    }
    
    public func startLanding(finished: CommandFinished?) {
        drone.flightController?.startLanding(completion: finished)
    }
    
    public func sendResetVelocityCommand(withCompletion: DJICompletionBlock? = nil) {
        guard let flightController = drone.flightController else {
            return
        }
        
        flightController.isVirtualStickAdvancedModeEnabled = true
        flightController.rollPitchControlMode = .velocity
        flightController.rollPitchCoordinateSystem = .ground
        flightController.verticalControlMode = .velocity
        flightController.yawControlMode = .angularVelocity
        flightController.send(DJIVirtualStickFlightControlData(pitch: 0, roll: 0, yaw: 0, verticalThrottle: 0), withCompletion: withCompletion)
    }
}

extension DJICamera : CameraAdapter {
    public var model: String? { displayName }
}

struct DJICameraFile : CameraFile {
    public let channel: UInt
    public var name: String { mediaFile.fileName }
    public var size: Int64 { mediaFile.fileSizeInBytes }
    public let created = Date()
    private let mediaFile: DJIMediaFile
    
    init(channel: UInt, mediaFile: DJIMediaFile) {
        self.channel = channel
        self.mediaFile = mediaFile
    }
}

extension DJICameraSystemState: CameraStateAdapter {
    public var isCapturingPhotoInterval: Bool { isShootingIntervalPhoto }
    public var isCapturingVideo: Bool { isRecording }
    public var isCapturing: Bool { isRecording || isShootingSinglePhoto || isShootingSinglePhotoInRAWFormat || isShootingIntervalPhoto || isShootingBurstPhoto || isShootingRAWBurstPhoto || isShootingShallowFocusPhoto || isShootingPanoramaPhoto }
    public var missionMode: Mission.CameraMode { mode.missionValue }
}

public class DJIGimbalAdapter: GimbalAdapter {
    public let gimbal: DJIGimbal
    public var pendingSpeedRotation: DJIGimbalRotation?
    
    public init(gimbal: DJIGimbal) {
        self.gimbal = gimbal
    }
    
    public var index: UInt { gimbal.index }

    public func send(velocityCommand: Mission.VelocityGimbalCommand, mode: Mission.GimbalMode) {
        pendingSpeedRotation = DJIGimbalRotation(
            pitchValue: gimbal.isAdjustPitchSupported ? velocityCommand.velocity.pitch.convertRadiansToDegrees as NSNumber : nil,
            rollValue: gimbal.isAdjustRollSupported ? velocityCommand.velocity.roll.convertRadiansToDegrees as NSNumber : nil,
            yawValue: mode == .free && gimbal.isAdjustYawSupported ? velocityCommand.velocity.yaw.convertRadiansToDegrees as NSNumber : nil,
            time: DJIGimbalRotation.minTime,
            mode: .speed)
    }
}

extension DJIGimbalState: GimbalStateAdapter {
    public var missionMode: Mission.GimbalMode { mode.missionValue }
    
    public var missionOrientation: Mission.Orientation3 {
        Mission.Orientation3(
            x: Double(attitudeInDegrees.pitch.convertDegreesToRadians),
            y: Double(attitudeInDegrees.roll.convertDegreesToRadians),
            z: Double(attitudeInDegrees.yaw.convertDegreesToRadians)
        )
    }
}
