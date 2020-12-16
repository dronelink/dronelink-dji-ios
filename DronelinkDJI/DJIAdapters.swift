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
    
    public var remoteControllers: [RemoteControllerAdapter]? {
        guard let remoteController = drone.remoteController else {
            return nil
        }
        return [remoteController]
    }
    
    public func remoteController(channel: UInt) -> RemoteControllerAdapter? { remoteControllers?[safeIndex: Int(channel)] }

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

    public func send(velocityCommand: Kernel.VelocityDroneCommand?) {
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
    
    public func send(remoteControllerSticksCommand: Kernel.RemoteControllerSticksDroneCommand?) {
        guard let remoteControllerSticksCommand = remoteControllerSticksCommand else {
            sendResetVelocityCommand()
            return
        }
        
        guard let flightController = drone.flightController else { return }
        
        flightController.rollPitchControlMode = .angle
        flightController.rollPitchCoordinateSystem = .body
        flightController.verticalControlMode = .velocity
        flightController.yawControlMode = remoteControllerSticksCommand.heading == nil ? .angularVelocity : .angle
        
        flightController.send(DJIVirtualStickFlightControlData(
            pitch: Float(-remoteControllerSticksCommand.rightStick.y * 30),
            roll: Float(remoteControllerSticksCommand.rightStick.x * 30),
            yaw: remoteControllerSticksCommand.heading == nil ? Float(remoteControllerSticksCommand.leftStick.x * 100) : Float(remoteControllerSticksCommand.heading!.angleDifferenceSigned(angle: 0).convertRadiansToDegrees),
            verticalThrottle: Float(remoteControllerSticksCommand.leftStick.y * 4.0)), withCompletion: nil)
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

public struct DJICameraFile : CameraFile {
    public let channel: UInt
    public var name: String { mediaFile.fileName }
    public var size: Int64 { mediaFile.fileSizeInBytes }
    public var metadata: String? { mediaFile.customInformation }
    public let created = Date()
    public let coordinate: CLLocationCoordinate2D?
    public let altitude: Double?
    public let orientation: Kernel.Orientation3?
    public let mediaFile: DJIMediaFile
    
    init(channel: UInt, mediaFile: DJIMediaFile, coordinate: CLLocationCoordinate2D?, altitude: Double?, orientation: Kernel.Orientation3?) {
        self.channel = channel
        self.mediaFile = mediaFile
        self.coordinate = coordinate
        self.altitude = altitude
        self.orientation = orientation
    }
}

public struct DJICameraStateAdapter: CameraStateAdapter {
    public let systemState: DJICameraSystemState
    public let storageState: DJICameraStorageState?
    public let exposureSettings: DJICameraExposureSettings?
    public let lensInformation: String?
    public let cameraShotPhotoMode: DJICameraShootPhotoMode?
    public let burstCountValue: DJICameraPhotoBurstCount?
    public let aebCountValue: DJICameraPhotoAEBCount?
    public let photoTimeIntervalSettings: DJICameraPhotoTimeIntervalSettings?
    
    public init(systemState: DJICameraSystemState, storageState: DJICameraStorageState?, exposureSettings: DJICameraExposureSettings?, lensInformation: String?, shotPhotoMode: DJICameraShootPhotoMode?, burstCount: DJICameraPhotoBurstCount?, aebCount: DJICameraPhotoAEBCount?, intervalSettings: DJICameraPhotoTimeIntervalSettings?) {
        self.systemState = systemState
        self.storageState = storageState
        self.exposureSettings = exposureSettings
        self.lensInformation = lensInformation
        self.cameraShotPhotoMode = shotPhotoMode
        self.burstCountValue = burstCount
        self.aebCountValue = aebCount
        photoTimeIntervalSettings = intervalSettings
    }
    
    public var isBusy: Bool { systemState.isBusy || storageState?.isFormatting ?? false || storageState?.isInitializing ?? false }
    public var isCapturing: Bool { systemState.isCapturing }
    public var isCapturingPhotoInterval: Bool { systemState.isCapturingPhotoInterval }
    public var isCapturingVideo: Bool { systemState.isCapturingVideo }
    public var isCapturingContinuous: Bool { systemState.isCapturingContinuous }
    public var isSDCardInserted: Bool { storageState?.isInserted ?? true }
    public var mode: Kernel.CameraMode { systemState.mode.kernelValue }
    public var photoMode: Kernel.CameraPhotoMode? { systemState.flatCameraMode.kernelValuePhoto ?? cameraShotPhotoMode?.kernelValue }
    public var photoInterval: Int? { Int(photoTimeIntervalSettings?.timeIntervalInSeconds ?? UInt16()) }
    public var burstCount: Kernel.CameraBurstCount? { burstCountValue?.kernelValue }
    public var aebCount: Kernel.CameraAEBCount? {aebCountValue?.kernelValue}
    public var currentVideoTime: Double? { systemState.currentVideoTime }
    public var exposureCompensation: Kernel.CameraExposureCompensation { exposureSettings?.exposureCompensation.kernelValue ?? .unknown }
    public var iso: Kernel.CameraISO { .unknown } //FIXME
    public var shutterSpeed: Kernel.CameraShutterSpeed { .unknown } //FIXME
    public var aperture: Kernel.CameraAperture { .unknown } //FIXME
    public var whiteBalancePreset: Kernel.CameraWhiteBalancePreset { .unknown } //FIXME
    public var lensDetails: String? { lensInformation }
}

extension DJICameraSystemState {
    public var isBusy: Bool { isStoringPhoto || isShootingSinglePhoto || isShootingSinglePhotoInRAWFormat || isShootingIntervalPhoto || isShootingBurstPhoto || isShootingRAWBurstPhoto || isShootingShallowFocusPhoto || isShootingPanoramaPhoto || isShootingHyperanalytic }
    public var isCapturing: Bool { isRecording || isShootingSinglePhoto || isShootingSinglePhotoInRAWFormat || isShootingIntervalPhoto || isShootingBurstPhoto || isShootingRAWBurstPhoto || isShootingShallowFocusPhoto || isShootingPanoramaPhoto || isShootingHyperanalytic }
    public var isCapturingPhotoInterval: Bool { isShootingIntervalPhoto }
    public var isCapturingVideo: Bool { isRecording }
    public var isCapturingContinuous: Bool { isCapturingPhotoInterval || isCapturingVideo }
    public var currentVideoTime: Double? { isCapturingVideo ? Double(currentVideoRecordingTimeInSeconds) : nil }
}

public class DJIGimbalAdapter: GimbalAdapter {
    private let serialQueue = DispatchQueue(label: "DJIGimbalAdapter")
    
    public let gimbal: DJIGimbal
    private var _pendingSpeedRotation: DJIGimbalRotation?
    public var pendingSpeedRotation: DJIGimbalRotation? {
        get { serialQueue.sync { self._pendingSpeedRotation } }
        set (pendingSpeedRotationNew) { serialQueue.async { self._pendingSpeedRotation = pendingSpeedRotationNew } }
    }
    
    public init(gimbal: DJIGimbal) {
        self.gimbal = gimbal
    }
    
    public var index: UInt { gimbal.index }

    public func send(velocityCommand: Kernel.VelocityGimbalCommand, mode: Kernel.GimbalMode) {
        pendingSpeedRotation = DJIGimbalRotation(
            pitchValue: gimbal.isAdjustPitchSupported ? max(-90, min(90, velocityCommand.velocity.pitch.convertRadiansToDegrees)) as NSNumber : nil,
            rollValue: gimbal.isAdjustRollSupported ? max(-90, min(90, velocityCommand.velocity.roll.convertRadiansToDegrees)) as NSNumber : nil,
            yawValue: mode == .free || gimbal.isAdjustYaw360Supported ? velocityCommand.velocity.yaw.convertRadiansToDegrees as NSNumber : nil,
            time: DJIGimbalRotation.minTime,
            mode: .speed,
            ignore: false)
    }
    
    public func reset() {
        gimbal.reset(completion: nil)
    }
    
    public func fineTune(roll: Double) {
        gimbal.fineTuneRoll(inDegrees: Float(roll.convertRadiansToDegrees), withCompletion: nil)
    }
}

public class DJIGimbalStateAdapter: GimbalStateAdapter {
    public let gimbalState: DJIGimbalState
    
    public init(gimbalState: DJIGimbalState) {
        self.gimbalState = gimbalState
    }

    public var mode: Kernel.GimbalMode { gimbalState.mode.kernelValue }
    
    public var orientation: Kernel.Orientation3 {
        Kernel.Orientation3(
            x: Double(gimbalState.attitudeInDegrees.pitch.convertDegreesToRadians),
            y: Double(gimbalState.attitudeInDegrees.roll.convertDegreesToRadians),
            z: Double(gimbalState.attitudeInDegrees.yaw.convertDegreesToRadians)
        )
    }
}

extension DJIRemoteController: RemoteControllerAdapter {
}

public class DJIRemoteControllerStateAdapter: RemoteControllerStateAdapter {
    public let rcHardwareState: DJIRCHardwareState
    
    public init(rcHardwareState: DJIRCHardwareState) {
        self.rcHardwareState = rcHardwareState
    }
    
    public var leftStick: Kernel.RemoteControllerStick {
        Kernel.RemoteControllerStick(
            x: Double(rcHardwareState.leftStick.horizontalPosition) / 660,
            y: Double(rcHardwareState.leftStick.verticalPosition) / 660)
    }
    
    public var leftWheel: Kernel.RemoteControllerWheel {
        Kernel.RemoteControllerWheel(present: true, pressed: false, value: Double(rcHardwareState.leftWheel) / 660)
    }
    
    public var rightStick: Kernel.RemoteControllerStick {
        Kernel.RemoteControllerStick(
            x: Double(rcHardwareState.rightStick.horizontalPosition) / 660,
            y: Double(rcHardwareState.rightStick.verticalPosition) / 660)
    }
    
    public var pauseButton: Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(
            present: rcHardwareState.pauseButton.isPresent.boolValue,
            pressed: rcHardwareState.pauseButton.isClicked.boolValue)
    }
    
    public var c1Button: Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(
            present: rcHardwareState.c1Button.isPresent.boolValue,
            pressed: rcHardwareState.c1Button.isClicked.boolValue)
   }
    
    public var c2Button: Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(
            present: rcHardwareState.c2Button.isPresent.boolValue,
            pressed: rcHardwareState.c2Button.isClicked.boolValue)
   }
}
