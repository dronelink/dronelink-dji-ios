//
//  DJIDroneAdapter.swift
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
    
    public func cameraChannel(videoFeedChannel: UInt?) -> UInt? {
        guard drone.multipleVideoFeedsEnabled, let videoFeeder = drone.videoFeeder else {
            return 0
        }
        
        if let videoFeedChannel = videoFeedChannel {
            return videoFeeder.feed(channel: videoFeedChannel)?.physicalSource.cameraChannel
        }
        
        for videoFeedChannel in UInt(0)..<UInt(3) {
            if let cameraChannel = videoFeeder.feed(channel: videoFeedChannel)?.physicalSource.cameraChannel {
                return cameraChannel
            }
        }
        
        return nil
    }
    
    public func camera(channel: UInt) -> CameraAdapter? { drone.camera(channel: channel) }
    
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
        
        if let gimbal = drone.gimbal(channel: channel) {
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
    
    public func startTakeoff(finished: CommandFinished?) {
        drone.flightController?.startPrecisionTakeoff(completion: { [weak self] error in
            if error == nil {
                finished?(nil)
                return
            }
            
            self?.drone.flightController?.startTakeoff(completion: finished)
        })
    }
    
    public func startReturnHome(finished: CommandFinished?) {
        drone.flightController?.startGoHome(completion: finished)
    }
    
    public func stopReturnHome(finished: CommandFinished?) {
        drone.flightController?.cancelGoHome(completion: finished)
    }
    
    public func startLand(finished: CommandFinished?) {
        drone.flightController?.startLanding(completion: finished)
    }
    
    public func stopLand(finished: CommandFinished?) {
        drone.flightController?.cancelLanding(completion: finished)
    }
    
    public func startCompassCalibration(finished: CommandFinished?) {
        drone.flightController?.compass?.startCalibration(completion: finished)
    }
    
    public func stopCompassCalibration(finished: CommandFinished?) {
        drone.flightController?.compass?.stopCalibration(completion: finished)
    }
    
    public func startRemoteControlLinking(finished: CommandFinished?) {
        drone.remoteController?.startPairing(completion: finished)
    }
    
    public func stopRemoteControlLinking(finished: CommandFinished?) {
        drone.remoteController?.stopPairing(completion: finished)
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
    
    public func enumElements(parameter: String) -> [EnumElement]? {
        guard let enumDefinition = Dronelink.shared.enumDefinition(name: parameter) else {
            return nil
        }
        
        var range: [String?] = []
        
        switch parameter {
        default:
            return nil
        }
        
        var enumElement: [EnumElement] = []
        range.forEach { value in
            if let value = value, let display = enumDefinition[value] {
                enumElement.append(EnumElement(display: display, value: value))
            }
        }
        
        return enumElement.isEmpty ? nil : enumElement
    }
}

extension DJICamera : CameraAdapter {
    public var model: String? { displayName }
    
    public func lensIndex(videoStreamSource: Kernel.CameraVideoStreamSource) -> UInt {
        for lens in lenses.enumerated() {
            if lens.element.lensType == videoStreamSource.djiLensType {
                return UInt(lens.offset)
            }
        }
        
        return 0
    }
    
    public func format(storageLocation: Kernel.CameraStorageLocation, finished: CommandFinished?) {
        formatStorage(storageLocation.djiValue, withCompletion: finished)
    }
    
    public func enumElements(parameter: String) -> [EnumElement]? {
        switch parameter {
        case "CameraPhotoInterval":
            let min = capabilities.photoIntervalRange().first?.intValue ?? 2
            let max = capabilities.photoIntervalRange().last?.intValue ?? 10
            return (min...max).map {
                EnumElement(display: "\($0) s", value: $0)
            }
        default:
            break
        }
        
        guard let enumDefinition = Dronelink.shared.enumDefinition(name: parameter) else {
            return nil
        }
        
        var range: [String?] = []
        
        switch parameter {
        case "CameraAperture":
            range = capabilities.apertureRange().map { DJICameraAperture(rawValue: $0.uintValue)?.kernelValue.rawValue }
            break
        case "CameraExposureCompensation":
            range = capabilities.exposureCompensationRange().map { DJICameraExposureCompensation(rawValue: $0.uintValue)?.kernelValue.rawValue }
            break
        case "CameraExposureMode":
            range = capabilities.exposureModeRange().map { DJICameraExposureMode(rawValue: $0.uintValue)?.kernelValue.rawValue }
            break
        case "CameraISO":
            range = capabilities.isoRange().map { DJICameraISO(rawValue: $0.uintValue)?.kernelValue.rawValue }
            break
        case "CameraMode":
            range = capabilities.modeRange().map { DJICameraMode(rawValue: $0.uintValue)?.kernelValue.rawValue }
            break
        case "CameraPhotoFileFormat":
            range = capabilities.photoFileFormatRange().map { DJICameraPhotoFileFormat(rawValue: $0.uintValue)?.kernelValue.rawValue }
            break
        case "CameraPhotoMode":
            range = capabilities.photoShootModeRange().map { DJICameraShootPhotoMode(rawValue: $0.uintValue)?.kernelValue.rawValue }
            break
        case "CameraShutterSpeed":
            range = capabilities.shutterSpeedRange().map { DJICameraShutterSpeed(rawValue: $0.uintValue)?.kernelValue.rawValue }
            break
        case "CameraStorageLocation":
            range.append(Kernel.CameraStorageLocation.sdCard.rawValue)
            if isInternalStorageSupported() {
                range.append(Kernel.CameraStorageLocation._internal.rawValue)
            }
            break
        case "CameraVideoFileFormat":
            range = capabilities.videoFileFormatRange().map { DJICameraVideoFileFormat(rawValue: $0.uintValue)?.kernelValue.rawValue }
            break
        case "CameraWhiteBalancePreset":
            //filtering out custom for now because we need to use WhiteBalanceCustomCameraCommand from the UI
            range = capabilities.whiteBalancePresetRange().map {
                let value = DJICameraWhiteBalancePreset(rawValue: $0.uintValue)?.kernelValue
                if value == .custom {
                    return nil
                }
                return value?.rawValue
            }
            break
        default:
            return nil
        }
        
        var enumElements: [EnumElement] = []
        range.forEach { value in
            if let value = value, value != "unknown", let display = enumDefinition[value] {
                enumElements.append(EnumElement(display: display, value: value))
            }
        }
        
        return enumElements.isEmpty ? nil : enumElements
    }
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
    public let videoStreamSourceValue: DJICameraVideoStreamSource?
    public let focusState: DJICameraFocusState?
    public let storageState: DJICameraStorageState?
    public let exposureModeValue: DJICameraExposureMode?
    public let exposureSettings: DJICameraExposureSettings?
    public let lensIndex: UInt
    public let lensInformation: String?
    public let storageLocationValue: DJICameraStorageLocation?
    public let photoModeValue: DJICameraShootPhotoMode?
    public let photoTimeIntervalSettings: DJICameraPhotoTimeIntervalSettings?
    public let photoFileFormatValue: DJICameraPhotoFileFormat?
    public let photoAspectRatioValue: DJICameraPhotoAspectRatio?
    public let burstCountValue: DJICameraPhotoBurstCount?
    public let aebCountValue: DJICameraPhotoAEBCount?
    public let videoFileFormatValue: DJICameraVideoFileFormat?
    public let videoFrameRateValue: DJICameraVideoFrameRate?
    public let videoResolutionValue: DJICameraVideoResolution?
    public let whiteBalanceValue: DJICameraWhiteBalance?
    public let isoValue: DJICameraISO?
    public let shutterSpeedValue: DJICameraShutterSpeed?
    public let focusRingValue: Double?
    public let focusRingMax: Double?
    
    public init(
        systemState: DJICameraSystemState,
        videoStreamSource: DJICameraVideoStreamSource?,
        focusState: DJICameraFocusState?,
        storageState: DJICameraStorageState?,
        exposureMode: DJICameraExposureMode?,
        exposureSettings: DJICameraExposureSettings?,
        lensIndex: UInt,
        lensInformation: String?,
        storageLocation: DJICameraStorageLocation?,
        photoMode: DJICameraShootPhotoMode?,
        photoFileFormat: DJICameraPhotoFileFormat?,
        photoAspectRatio: DJICameraPhotoAspectRatio?,
        burstCount: DJICameraPhotoBurstCount?,
        aebCount: DJICameraPhotoAEBCount?,
        intervalSettings: DJICameraPhotoTimeIntervalSettings?,
        videoFileFormat: DJICameraVideoFileFormat?,
        videoFrameRate: DJICameraVideoFrameRate?,
        videoResolution: DJICameraVideoResolution?,
        whiteBalance: DJICameraWhiteBalance?,
        iso: DJICameraISO?,
        shutterSpeed: DJICameraShutterSpeed?,
        focusRingValue: Double?,
        focusRingMax: Double?) {
        self.systemState = systemState
        self.videoStreamSourceValue = videoStreamSource
        self.focusState = focusState
        self.storageState = storageState
        self.exposureModeValue = exposureMode
        self.exposureSettings = exposureSettings
        self.lensIndex = lensIndex
        self.lensInformation = lensInformation
        self.storageLocationValue = storageLocation
        self.photoModeValue = photoMode
        self.photoTimeIntervalSettings = intervalSettings
        self.photoFileFormatValue = photoFileFormat
        self.photoAspectRatioValue = photoAspectRatio
        self.burstCountValue = burstCount
        self.aebCountValue = aebCount
        self.videoFileFormatValue = videoFileFormat
        self.videoFrameRateValue = videoFrameRate
        self.videoResolutionValue = videoResolution
        self.whiteBalanceValue = whiteBalance
        self.isoValue = iso
        self.shutterSpeedValue = shutterSpeed
        self.focusRingValue = focusRingValue
        self.focusRingMax = focusRingMax
    }
    
    public var isBusy: Bool { systemState.isBusy || focusState?.focusStatus.isBusy ?? false || storageState?.isFormatting ?? false || storageState?.isInitializing ?? false }
    public var isCapturing: Bool { systemState.isCapturing }
    public var isCapturingPhotoInterval: Bool { systemState.isCapturingPhotoInterval }
    public var isCapturingVideo: Bool { systemState.isCapturingVideo }
    public var isCapturingContinuous: Bool { systemState.isCapturingContinuous }
    public var isSDCardInserted: Bool { storageState?.isInserted ?? true }
    public var videoStreamSource: Kernel.CameraVideoStreamSource { videoStreamSourceValue?.kernelValue ?? .unknown }
    public var storageLocation: Kernel.CameraStorageLocation { storageLocationValue?.kernelValue ?? .unknown }
    public var storageRemainingSpace: Int? {
        if let remainingSpaceInMegaBytes = storageState?.remainingSpaceInMB {
            return Int(remainingSpaceInMegaBytes) * 1048576
        }
        return nil
    }
    public var storageRemainingPhotos: Int? {
        if let availableCaptureCount = storageState?.availableCaptureCount {
            return Int(availableCaptureCount)
        }
        return nil
    }
    public var mode: Kernel.CameraMode { systemState.mode.kernelValue }
    public var photoMode: Kernel.CameraPhotoMode? { systemState.flatCameraMode.kernelValuePhoto ?? photoModeValue?.kernelValue }
    public var photoFileFormat: Kernel.CameraPhotoFileFormat { photoFileFormatValue?.kernelValue ?? .unknown }
    public var photoInterval: Int? { Int(photoTimeIntervalSettings?.timeIntervalInSeconds ?? UInt16()) }
    public var burstCount: Kernel.CameraBurstCount? { burstCountValue?.kernelValue }
    public var aebCount: Kernel.CameraAEBCount? {aebCountValue?.kernelValue}
    public var videoFileFormat: Kernel.CameraVideoFileFormat { videoFileFormatValue?.kernelValue ?? .unknown }
    public var videoFrameRate: Kernel.CameraVideoFrameRate { videoFrameRateValue?.kernelValue ?? .unknown }
    public var videoResolution: Kernel.CameraVideoResolution { videoResolutionValue?.kernelValue ?? .unknown }
    public var currentVideoTime: Double? { systemState.currentVideoTime }
    public var exposureMode: Kernel.CameraExposureMode { exposureModeValue?.kernelValue ?? .unknown }
    public var exposureCompensation: Kernel.CameraExposureCompensation { exposureSettings?.exposureCompensation.kernelValue ?? .unknown }
    public var iso: Kernel.CameraISO { isoValue?.kernelValue ?? .unknown }
    public var isoActual: Int? {
        guard let exposureSettingsISO = exposureSettings?.ISO else { return nil }
        return Int(exposureSettingsISO)
    }
    public var shutterSpeed: Kernel.CameraShutterSpeed { shutterSpeedValue?.kernelValue ?? .unknown }
    public var shutterSpeedActual: Kernel.CameraShutterSpeed? { exposureSettings?.shutterSpeed.kernelValue ?? .unknown }
    public var aperture: Kernel.CameraAperture { exposureSettings?.aperture.kernelValue ?? .unknown }
    public var whiteBalancePreset: Kernel.CameraWhiteBalancePreset { whiteBalanceValue?.preset.kernelValue ?? .unknown }
    public var whiteBalanceColorTemperature: Int? {
        guard let colorTemperature = whiteBalanceValue?.colorTemperature else { return nil }
        return Int(colorTemperature) * 100
    }
    public var lensDetails: String? { lensInformation }
    public var aspectRatio: Kernel.CameraPhotoAspectRatio { (mode == .photo ? photoAspectRatioValue?.kernelValue : nil) ?? ._16x9 }
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
            yawValue: mode == .free ? velocityCommand.velocity.yaw.convertRadiansToDegrees as NSNumber : nil,
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
    
    public func enumElements(parameter: String) -> [EnumElement]? {
        guard let enumDefinition = Dronelink.shared.enumDefinition(name: parameter) else {
            return nil
        }
        
        var range: [String?] = []
        
        switch parameter {
        case "GimbalMode":
            range.append(Kernel.GimbalMode.yawFollow.rawValue)
            if gimbal.isAdjustYaw360Supported {
                range.append(Kernel.GimbalMode.free.rawValue)
            }
            range.append(Kernel.GimbalMode.fpv.rawValue)
            break
        default:
            return nil
        }
        
        var enumElements: [EnumElement] = []
        range.forEach { value in
            if let value = value, value != "unknown", let display = enumDefinition[value] {
                enumElements.append(EnumElement(display: display, value: value))
            }
        }
        
        return enumElements.isEmpty ? nil : enumElements
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
    public let pairingState: DJIRCPairingState

    public init(rcHardwareState: DJIRCHardwareState, pairingState: DJIRCPairingState?) {
        self.rcHardwareState = rcHardwareState
        self.pairingState = pairingState ?? .stateUnknown
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
    
    public var returnHomeButton: Kernel.RemoteControllerButton {
        Kernel.RemoteControllerButton(
            present: rcHardwareState.goHomeButton.isPresent.boolValue,
            pressed: rcHardwareState.goHomeButton.isClicked.boolValue)
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
    
    public var batteryPercent: Double { 0.0 }
    
    public var pairing: Kernel.RemoteControllerPairingState { pairingState.kernelValue }
}
