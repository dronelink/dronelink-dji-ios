//
//  DJIFlightControllerStateWrapper.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/26/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import DJISDK

public struct DJIDroneAdapter: DroneAdapter {
    public let drone: DJIAircraft

    public init(drone: DJIAircraft) {
        self.drone = drone
    }

    public var cameras: [CameraAdapter]? { drone.cameras }
    public func camera(channel: UInt) -> CameraAdapter? { cameras?[Int(channel)] }
    public var gimbals: [GimbalAdapter]? { drone.gimbals }
    public func gimbal(channel: UInt) -> GimbalAdapter? { gimbals?[Int(channel)] }

    public func send(velocityCommand: Mission.VelocityDroneCommand?) {
        guard let flightController = drone.flightController else { return }
        guard let velocityCommand = velocityCommand else {
            flightController.sendResetVelocityCommand()
            return
        }
        
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
}

extension DJICamera : CameraAdapter {}

extension DJICameraSystemState: CameraStateAdapter {
    public var isCapturingPhotoInterval: Bool { isShootingIntervalPhoto }
    public var isCapturingVideo: Bool { isRecording }
    public var isCapturing: Bool { isRecording || isShootingSinglePhoto || isShootingSinglePhotoInRAWFormat || isShootingIntervalPhoto || isShootingBurstPhoto || isShootingRAWBurstPhoto || isShootingShallowFocusPhoto || isShootingPanoramaPhoto }
    public var missionMode: Mission.CameraMode { mode.missionValue }
}

extension DJIGimbal : GimbalAdapter {
    public func send(velocityCommand: Mission.VelocityGimbalCommand, mode: Mission.GimbalMode) {
        rotate(with: DJIGimbalRotation(
            pitchValue: isAdjustPitchSupported ? velocityCommand.velocity.pitch.convertRadiansToDegrees as NSNumber : nil,
            rollValue: mode == .free && isAdjustRollSupported ? velocityCommand.velocity.roll.convertRadiansToDegrees as NSNumber : nil,
            yawValue: mode == .free && isAdjustYawSupported ? velocityCommand.velocity.yaw.convertRadiansToDegrees as NSNumber : nil,
            time: DJIGimbalRotation.minTime,
            mode: .speed), completion: nil)
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
