//
//  DJIDroneSession.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/26/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import Foundation
import os
import DronelinkCore
import DJISDK

public class DJIDroneSession: NSObject {
    internal let log = OSLog(subsystem: "DronelinkDJI", category: "DJIDroneSession")
    
    public let adapter: DJIDroneAdapter
    
    private let _opened = Date()
    private var _closed = false
    private var _id = UUID().uuidString
    private var _serialNumber: String?
    private var _name: String?
    private var _model: String?
    private var _firmwarePackageVersion: String?
    private var _initialized = false
    private var _located = false
    private var _lastKnownGroundLocation: CLLocation?
    private var _lastNonZeroFlyingAltitude: Double?
    
    private let delegates = MulticastDelegate<DroneSessionDelegate>()
    private let droneCommands = CommandQueue()
    private let cameraCommands = MultiChannelCommandQueue()
    private let gimbalCommands = MultiChannelCommandQueue()
    
    private let diagnosticsInformationSerialQueue = DispatchQueue(label: "DroneSession+diagnosticsInformation")
    private var _diagnosticsInformationMessages: DatedValue<[Kernel.Message]>?
    
    private let flightControllerSerialQueue = DispatchQueue(label: "DroneSession+flightControllerState")
    private var _flightControllerState: DatedValue<DJIFlightControllerState>?
    
    private let batterySerialQueue = DispatchQueue(label: "DroneSession+batteryState")
    private var _batterState: DatedValue<DJIBatteryState>?
    
    private let visionDetectionSerialQueue = DispatchQueue(label: "DroneSession+visionDetectionState")
    private var _visionDetectionState: DatedValue<DJIVisionDetectionState>?
    
    private let remoteControllerSerialQueue = DispatchQueue(label: "DroneSession+remoteControllerState")
    private var _remoteControllerState: DatedValue<RemoteControllerStateAdapter>?
    
    private let cameraSerialQueue = DispatchQueue(label: "DroneSession+cameraStates")
    private var _cameraStates: [UInt: DatedValue<DJICameraSystemState>] = [:]
    private var _cameraStorageStates: [UInt: DatedValue<DJICameraStorageState>] = [:]
    private var _cameraExposureSettings: [UInt: DatedValue<DJICameraExposureSettings>] = [:]
    private var _cameraLensInformation: [UInt: DatedValue<String>] = [:]
    
    private let gimbalSerialQueue = DispatchQueue(label: "DroneSession+gimbalStates")
    private var _gimbalStates: [UInt: DatedValue<DJIGimbalState>] = [:]
    
    private var _airLinkSignalQuality: DatedValue<UInt>?
    
    public init(drone: DJIAircraft) {
        adapter = DJIDroneAdapter(drone: drone)
        super.init()
        initDrone()
        Thread.detachNewThread(self.execute)
    }
    
    private func initDrone() {
        os_log(.info, log: log, "Drone session opened")
        
        adapter.drone.delegate = self
        initFlightController()
        adapter.drone.remoteController?.delegate = self
        adapter.cameras?.forEach { initCamera(index: $0.index) }
        adapter.gimbals?.forEach { initGimbal(index: $0.index) }
    }
    
    private func initFlightController() {
        guard let flightController = adapter.drone.flightController else {
            os_log(.error, log: log, "Flight controller unavailable")
            return
        }
        
        os_log(.info, log: log, "Flight controller connected")
        flightController.delegate = self
        adapter.drone.battery?.delegate = self
        flightController.flightAssistant?.delegate = self
        
        _model = adapter.drone.model ?? ""
        if let model = adapter.drone.model {
            os_log(.info, log: log, "Model: %{public}s", model)
        }
        
        adapter.drone.getFirmwarePackageVersion { (firmwarePackageVersion, error) in
            self._firmwarePackageVersion = firmwarePackageVersion ?? ""
            if let firmwarePackageVersion = firmwarePackageVersion {
                os_log(.info, log: self.log, "Firmware package version: %{public}s", firmwarePackageVersion)
            }
        }
        
        adapter.drone.getNameWithCompletion { (name, error) in
            self._name = name ?? ""
            if let name = name {
                os_log(.info, log: self.log, "Name: %{public}s", name)
            }
        }
        
        initSerialNumber()
        
        flightController.setMultipleFlightModeEnabled(true) { error in
            if error == nil {
                os_log(.debug, log: self.log, "Flight controller multiple flight mode enabled")
            }
        }
        
        flightController.setNoviceModeEnabled(false)  { error in
           if error == nil {
               os_log(.debug, log: self.log, "Flight controller novice mode disabled")
           }
        }
        
        flightController.setVirtualStickModeEnabled(false)  { error in
           if error == nil {
               os_log(.debug, log: self.log, "Flight controller virtual stick mode deactivated")
           }
        }
        
        DJISDKManager.keyManager()?.startListeningForChanges(on: DJIAirLinkKey(param: DJIAirLinkParamDownlinkSignalQuality)!, withListener: self) { (oldValue, newValue) in
            if let newValue = newValue?.unsignedIntegerValue {
                self._airLinkSignalQuality = DatedValue(value: newValue)
            }
            else {
                self._airLinkSignalQuality = nil
            }
        }
    }
    
    private func initSerialNumber(attempt: Int = 0) {
        if attempt < 3, let flightController = adapter.drone.flightController {
            flightController.getSerialNumber { serialNumber, error in
                if error != nil {
                    self.initSerialNumber(attempt: attempt + 1)
                    return
                }
                
                self._serialNumber = serialNumber
                if let serialNumber = serialNumber {
                    os_log(.info, log: self.log, "Serial number: %{public}s", serialNumber)
                }
            }
        }
    }
    
    private func initCamera(index: UInt) {
        let index = Int(index)
        if let camera = adapter.drone.cameras?[safeIndex: index] {
            os_log(.info, log: log, "Camera[%{public}d] connected", index)
            camera.delegate = self
            
            let xmp = "dronelink:\(Dronelink.shared.kernelVersion?.display ?? "")"
            camera.setMediaFileCustomInformation(xmp) { error in
                if let error = error {
                    os_log(.info, log: self.log, "Unable to set media file custom information: %{public}s", error.localizedDescription)
                }
                else {
                    os_log(.info, log: self.log, "Set media file custom information: %{public}s", xmp)
                }
            }
            
            camera.getLensInformation { (info, error) in
                if let info = info {
                    self.cameraSerialQueue.async {
                        self._cameraLensInformation[camera.index] = DatedValue<String>(value: info)
                    }
                }
            }
        }
    }
    
    private func initGimbal(index: UInt) {
        let index = Int(index)
        if let gimbal = adapter.drone.gimbals?[safeIndex: index] {
            os_log(.info, log: log, "Gimbal[%{public}d] connected", index)
            gimbal.delegate = self
            
            gimbal.setPitchRangeExtensionEnabled(true) { error in
                if error == nil {
                    os_log(.debug, log: self.log, "Gimbal[%{public}d] pitch range extension enabled", index)
                }
            }
        }
    }
    
    public func componentConnected(withKey key: String?, andIndex index: Int) {
        guard let key = key else { return }
        switch key {
        case DJIFlightControllerComponent:
            initFlightController()
            break
        
        case DJICameraComponent:
            initCamera(index: UInt(index))
            break
            
        case DJIGimbalComponent:
            initGimbal(index: UInt(index))
            break
            
        default:
            break
        }
    }
    
    public func componentDisconnected(withKey key: String?, andIndex index: Int) {
        guard let key = key else { return }
        switch key {
        case DJIFlightControllerComponent:
            os_log(.info, log: log, "Flight controller disconnected")
            flightControllerSerialQueue.async {
                self._flightControllerState = nil
            }
            
            batterySerialQueue.async {
                self._batterState = nil
            }
            
            visionDetectionSerialQueue.async {
                self._visionDetectionState = nil
            }
            break
            
        case DJICameraComponent:
            os_log(.info, log: log, "Camera[%{public}d] disconnected", index)
            cameraSerialQueue.async {
                self._cameraStates[UInt(index)] = nil
                self._cameraStorageStates[UInt(index)] = nil
                self._cameraExposureSettings[UInt(index)] = nil
                self._cameraLensInformation[UInt(index)] = nil
            }
            break
            
        case DJIGimbalComponent:
            os_log(.info, log: log, "Gimbal[%{public}d] disconnected", index)
            gimbalSerialQueue.async {
                self._gimbalStates[UInt(index)] = nil
            }
            break
            
        default:
            break
        }
    }

    public var flightControllerState: DatedValue<DJIFlightControllerState>? {
        flightControllerSerialQueue.sync {
            return self._flightControllerState
        }
    }
    
    public var batteryState: DatedValue<DJIBatteryState>? {
        batterySerialQueue.sync {
            return self._batterState
        }
    }
    
    public var visionDetectionState: DatedValue<DJIVisionDetectionState>? {
        visionDetectionSerialQueue.sync {
            return self._visionDetectionState
        }
    }
    
    private func execute() {
        while !_closed {
            if !_initialized,
                _serialNumber != nil,
                _name != nil,
                _model != nil,
                _firmwarePackageVersion != nil {
                _initialized = true
                DispatchQueue.global().async {
                    self.delegates.invoke { $0.onInitialized(session: self) }
                }
            }
            
            if let location = location {
                if (!_located) {
                    _located = true
                    DispatchQueue.global().async {
                        self.delegates.invoke { $0.onLocated(session: self) }
                    }
                }
                
                if !isFlying {
                    _lastKnownGroundLocation = location
                }
            }
            
            self.droneCommands.process()
            self.cameraCommands.process()
            self.gimbalCommands.process()
            
            if Dronelink.shared.missionExecutor?.engaged ?? false || Dronelink.shared.modeExecutor?.engaged ?? false {
                self.gimbalSerialQueue.async {
                    //work-around for this issue: https://support.dronelink.com/hc/en-us/community/posts/360034749773-Seeming-to-have-a-Heading-error-
                    self.adapter.gimbals?.forEach { gimbalAdapter in
                        if let gimbalAdapter = gimbalAdapter as? DJIGimbalAdapter {
                            var rotation = gimbalAdapter.pendingSpeedRotation
                            gimbalAdapter.pendingSpeedRotation = nil
                            if gimbalAdapter.gimbal.isAdjustYawSupported, let gimbalState = self._gimbalStates[gimbalAdapter.index]?.value, gimbalState.mode == .yawFollow {
                                rotation = DJIGimbalRotation(
                                    pitchValue: rotation?.pitch,
                                    rollValue: rotation?.roll,
                                    yawValue: min(max(-self.gimbalYawRelativeToAircraftHeadingCorrected(gimbalState: gimbalState).convertRadiansToDegrees * 0.25, -25), 25) as NSNumber,
                                    time: DJIGimbalRotation.minTime,
                                    mode: .speed,
                                    ignore: false)
                            }
                            
                            if let rotation = rotation {
                                gimbalAdapter.gimbal.rotate(with: rotation, completion: nil)
                            }
                        }
                    }
                }
            }
            
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        DJISDKManager.keyManager()?.stopListening(on: DJIAirLinkKey(param: DJIAirLinkParamDownlinkSignalQuality)!, ofListener: self)
        os_log(.info, log: log, "Drone session closed")
    }
    
    private func gimbalYawRelativeToAircraftHeadingCorrected(gimbalState: GimbalStateAdapter) -> Double {
        if let model = (drone as? DJIDroneAdapter)?.drone.model {
            switch (model) {
            case DJIAircraftModelNamePhantom4,
                 DJIAircraftModelNamePhantom4Pro,
                 DJIAircraftModelNamePhantom4ProV2,
                 DJIAircraftModelNamePhantom4Advanced,
                 DJIAircraftModelNamePhantom4RTK:
                return gimbalState.kernelOrientation.yaw.angleDifferenceSigned(angle: kernelOrientation.yaw)
            default:
                break
            }
        }
        return (gimbalState as? DJIGimbalState)?.yawRelativeToAircraftHeading.convertDegreesToRadians ?? 0
    }
    
    internal func sendResetVelocityCommand(withCompletion: DJICompletionBlock? = nil) {
        adapter.sendResetVelocityCommand(withCompletion: withCompletion)
    }
    
    internal func sendResetGimbalCommands() {
        adapter.drone.gimbals?.forEach { gimbal in
            let rotation = DJIGimbalRotation(
                pitchValue: gimbal.isAdjustPitchSupported ? -12.0 as NSNumber : nil,
                rollValue: gimbal.isAdjustRollSupported ? 0 : nil,
                yawValue: nil,
                time: DJIGimbalRotation.minTime,
                mode: .absoluteAngle,
                ignore: false)
            
            if gimbal.isAdjustYawSupported, (gimbalState(channel: gimbal.index)?.value.kernelMode ?? .yawFollow) != .yawFollow {
                gimbal.setMode(.yawFollow) { yawFollowError in
                    //if we don't give it a delay, it ignores the next command!
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                        gimbal.reset { resetError in
                            gimbal.rotate(with: rotation, completion: nil)
                        }
                    }
                }
            }
            else {
                gimbal.rotate(with: rotation, completion: nil)
            }
        }
    }
    
    internal func sendResetCameraCommands() {
        adapter.drone.cameras?.forEach {
            if let cameraState = cameraState(channel: $0.index)?.value {
                if (cameraState.isCapturingVideo) {
                    $0.stopRecordVideo(completion: nil)
                }
                else if (cameraState.isCapturing) {
                    $0.stopShootPhoto(completion: nil)
                }
            }
        }
    }
}

extension DJIDroneSession: DroneSession {
    public var drone: DroneAdapter { adapter }
    public var state: DatedValue<DroneStateAdapter>? { DatedValue(value: self, date: flightControllerState?.date ?? Date()) }
    public var opened: Date { _opened }
    public var id: String { _id }
    public var manufacturer: String { "DJI" }
    public var serialNumber: String? { _serialNumber }
    public var name: String? { _name }
    public var model: String? { _model }
    public var firmwarePackageVersion: String? { _firmwarePackageVersion }
    public var initialized: Bool { _initialized }
    public var located: Bool { _located }
    public var telemetryDelayed: Bool { -(flightControllerState?.date.timeIntervalSinceNow ?? 0) > 1.0 }
    public var disengageReason: Kernel.Message? {
        if adapter.drone.flightController == nil {
            return Kernel.Message(title: "MissionDisengageReason.drone.control.unavailable.title".localized)
        }
        
        if flightControllerState == nil {
            return Kernel.Message(title: "MissionDisengageReason.telemetry.unavailable.title".localized)
        }
        
        if telemetryDelayed {
            return Kernel.Message(title: "MissionDisengageReason.telemetry.delayed.title".localized)
        }
        
        if flightControllerState?.value.hasReachedMaxFlightHeight ?? false {
            return Kernel.Message(title: "MissionDisengageReason.drone.max.altitude.title".localized, details: "MissionDisengageReason.drone.max.altitude.details".localized)
        }
        
        if flightControllerState?.value.hasReachedMaxFlightRadius ?? false {
            return Kernel.Message(title: "MissionDisengageReason.drone.max.distance.title".localized, details: "MissionDisengageReason.drone.max.distance.details".localized)
        }
        
        return nil
    }
    
    public func identify(id: String) { _id = id }
    
    public func add(delegate: DroneSessionDelegate) {
        delegates.add(delegate)
        
        if _initialized {
            delegate.onInitialized(session: self)
        }
        
        if _located {
            delegate.onLocated(session: self)
        }
    }
    
    public func remove(delegate: DroneSessionDelegate) {
        delegates.remove(delegate)
    }
    
    public func add(command: KernelCommand) throws {
        if let command = command as? KernelDroneCommand {
            droneCommands.add(command: Command(
                id: command.id,
                name: command.type.rawValue,
                execute: { finished in
                    self.commandExecuted(command: command)
                    return self.execute(droneCommand: command, finished: finished)
                },
                finished: { error in
                    self.commandFinished(command: command, error: error)
                },
                config: command.config
            ))
            return
        }
        
        if let command = command as? KernelCameraCommand {
            cameraCommands.add(channel: command.channel, command: Command(
                id: command.id,
                name: command.type.rawValue,
                execute: {
                    self.commandExecuted(command: command)
                    return self.execute(cameraCommand: command, finished: $0)
                },
                finished: { error in
                    self.commandFinished(command: command, error: error)
                },
                config: command.config
            ))
            return
        }

        if let command = command as? KernelGimbalCommand {
            gimbalCommands.add(channel: command.channel, command: Command(
                id: command.id,
                name: command.type.rawValue,
                execute: {
                    self.commandExecuted(command: command)
                    return self.execute(gimbalCommand: command, finished: $0)
                },
                finished: { error in
                    self.commandFinished(command: command, error: error)
                },
                config: command.config
            ))
            return
        }
        
        throw DroneSessionError.commandTypeUnhandled
    }
    
    private func commandExecuted(command: KernelCommand) {
        delegates.invoke { $0.onCommandExecuted(session: self, command: command) }
    }
    
    private func commandFinished(command: KernelCommand, error: Error?) {
        var errorResolved: Error? = error
        if (error as NSError?)?.code == DJISDKError.productNotSupport.rawValue {
            os_log(.info, log: log, "Ignoring command failure: product not supported (%{public}s)", command.id)
            errorResolved = nil
        }
        delegates.invoke { $0.onCommandFinished(session: self, command: command, error: errorResolved) }
    }
    
    public func removeCommands() {
        droneCommands.removeAll()
        cameraCommands.removeAll()
        gimbalCommands.removeAll()
    }
    
    public func createControlSession() -> DroneControlSession { DJIControlSession(droneSession: self) }
    
    public func cameraState(channel: UInt) -> DatedValue<CameraStateAdapter>? {
        cameraSerialQueue.sync {
            if let systemState = self._cameraStates[channel] {
                return DatedValue(value: DJICameraStateAdapter(
                    systemState: systemState.value,
                    storageState: self._cameraStorageStates[channel]?.value,
                    exposureSettings: self._cameraExposureSettings[channel]?.value,
                    lensInformation: self._cameraLensInformation[channel]?.value), date: systemState.date)
            }
            return nil
        }
    }

    public func gimbalState(channel: UInt) -> DatedValue<GimbalStateAdapter>? {
        gimbalSerialQueue.sync {
            if let gimbalState = _gimbalStates[channel] {
                return DatedValue<GimbalStateAdapter>(value: gimbalState.value, date: gimbalState.date)
            }
            return nil
        }
    }

    public func remoteControllerState(channel: UInt) -> DatedValue<RemoteControllerStateAdapter>? {
        remoteControllerSerialQueue.sync {
            return _remoteControllerState
        }
    }
    
    public func resetPayloads() {
        sendResetGimbalCommands()
        sendResetCameraCommands()
    }
    
    public func close() {
        _closed = true
    }
}

extension DJIDroneSession: DroneStateAdapter {
    public var statusMessages: [Kernel.Message]? {
        var messages = _diagnosticsInformationMessages?.value ?? []
        if location == nil {
            messages.append(Kernel.Message(title: "DJIDroneSession.statusMessage.locationUnavailable.title".localized, level: .warning))
        }
        
        return messages.sorted { (l, r) -> Bool in
            l.level.compare(to: r.level) > 0
        }
    }
    public var mode: String? { flightControllerState?.value.flightModeString }
    public var isFlying: Bool { flightControllerState?.value.isFlying ?? false }
    public var location: CLLocation? { flightControllerState?.value.location }
    public var homeLocation: CLLocation? { flightControllerState?.value.isHomeLocationSet ?? false ? flightControllerState?.value.homeLocation : nil }
    public var lastKnownGroundLocation: CLLocation? { _lastKnownGroundLocation }
    public var takeoffLocation: CLLocation? { isFlying ? (lastKnownGroundLocation ?? homeLocation) : location }
    public var takeoffAltitude: Double? {
        nil
        //DJI reports "MSL" altitude based on barometer...no good
        //takeoffLocation == nil ? nil : flightControllerState?.value.takeoffAltitude
    }
    public var course: Double { flightControllerState?.value.course ?? 0 }
    public var horizontalSpeed: Double { flightControllerState?.value.horizontalSpeed ?? 0 }
    public var verticalSpeed: Double { flightControllerState?.value.verticalSpeed ?? 0 }
    public var altitude: Double { flightControllerState?.value.altitude ?? 0 }
    public var batteryPercent: Double? {
        if let chargeRemainingInPercent = batteryState?.value.chargeRemainingInPercent {
            return Double(chargeRemainingInPercent) / 100
        }
        return nil
    }
    public var obstacleDistance: Double? {
        var minObstacleDistance = 0.0
        visionDetectionState?.value.detectionSectors?.forEach {
            minObstacleDistance = minObstacleDistance == 0 ? $0.obstacleDistanceInMeters : min(minObstacleDistance, $0.obstacleDistanceInMeters)
        }
        return minObstacleDistance > 0 ? minObstacleDistance : nil
    }
    public var kernelOrientation: Kernel.Orientation3 { flightControllerState?.value.kernelOrientation ?? Kernel.Orientation3() }
    public var gpsSatellites: Int? {
        if let satelliteCount = flightControllerState?.value.satelliteCount {
            return Int(satelliteCount)
        }
        return nil
    }
    
    public var downlinkSignalStrength: Double? {
        if let airLinkSignalQuality = _airLinkSignalQuality?.value {
            return Double(airLinkSignalQuality) / 100.0
        }
        return nil
    }
    
    public var uplinkSignalStrength: Double? { nil } //FIXME
}

extension DJIDroneSession: DJIBaseProductDelegate {
    public func product(_ product: DJIBaseProduct, didUpdateDiagnosticsInformation info: [Any]) {
        diagnosticsInformationSerialQueue.async {
            var messages: [Kernel.Message] = []
            info.forEach { (value) in
                if let diagnostics = value as? DJIDiagnostics {
                    messages.append(Kernel.Message(title: diagnostics.reason, details: diagnostics.solution, level: diagnostics.healthInformation.warningLevel.kernelValue))
                }
            }
            
            self._diagnosticsInformationMessages = DatedValue(value: messages)
        }
    }
}

extension DJIDroneSession: DJIFlightControllerDelegate {
    public func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
        flightControllerSerialQueue.async {
            //automatically adjust the drone altitude offset if:
            //1) altitude continuity is enabled
            //2) the drone is going from flying to not flying
            //3) the altitude reference is ground level
            //4) the current drone altitude offset is not zero
            //5) the last non-zero flying altitude is available
            //6) the absolute value of last non-zero flying altitude is more than 1m
            if Dronelink.shared.droneOffsets.droneAltitudeContinuity,
                self._flightControllerState?.value.isFlying ?? false,
                !state.isFlying,
                (Dronelink.shared.droneOffsets.droneAltitudeReference ?? 0) == 0,
                let lastNonZeroFlyingAltitude = self._lastNonZeroFlyingAltitude,
                abs(lastNonZeroFlyingAltitude) > 1 {
                //adjust by the last non-zero flying altitude
                Dronelink.shared.droneOffsets.droneAltitude -= lastNonZeroFlyingAltitude
            }
            
            let motorsOnPrevious = self._flightControllerState?.value.areMotorsOn ?? false
            self._flightControllerState = DatedValue<DJIFlightControllerState>(value: state)
            if (motorsOnPrevious != state.areMotorsOn) {
                self.delegates.invoke { $0.onMotorsChanged(session: self, value: state.areMotorsOn) }
            }
            
            if state.isFlying {
                if state.altitude != 0 {
                    self._lastNonZeroFlyingAltitude = state.altitude
                }
            }
            else {
                self._lastNonZeroFlyingAltitude = nil
            }
        }
    }
}

extension DJIDroneSession: DJIFlightAssistantDelegate {
    public func flightAssistant(_ assistant: DJIFlightAssistant, didUpdate state: DJIVisionDetectionState) {
        if state.position == .nose {
            visionDetectionSerialQueue.async {
                self._visionDetectionState = DatedValue<DJIVisionDetectionState>(value: state)
            }
        }
    }
}

extension DJIDroneSession: DJIBatteryDelegate {
    public func battery(_ battery: DJIBattery, didUpdate state: DJIBatteryState) {
        batterySerialQueue.async {
            self._batterState = DatedValue<DJIBatteryState>(value: state)
        }
    }
}

extension DJIDroneSession: DJIRemoteControllerDelegate {
    public func remoteController(_ rc: DJIRemoteController, didUpdate state: DJIRCHardwareState) {
        remoteControllerSerialQueue.async {
            self._remoteControllerState = DatedValue<RemoteControllerStateAdapter>(value: state)
        }
    }
}

extension DJIDroneSession: DJICameraDelegate {
    public func camera(_ camera: DJICamera, didUpdate systemState: DJICameraSystemState) {
        cameraSerialQueue.async {
            self._cameraStates[camera.index] = DatedValue<DJICameraSystemState>(value: systemState)
        }
    }
    
    public func camera(_ camera: DJICamera, didUpdate storageState: DJICameraStorageState) {
        if storageState.location == .sdCard {
            cameraSerialQueue.async {
                self._cameraStorageStates[camera.index] = DatedValue<DJICameraStorageState>(value: storageState)
            }
        }
    }
    
    public func camera(_ camera: DJICamera, didUpdate settings: DJICameraExposureSettings) {
        cameraSerialQueue.async {
            self._cameraExposureSettings[camera.index] = DatedValue<DJICameraExposureSettings>(value: settings)
        }
    }
    
    public func camera(_ camera: DJICamera, didGenerateNewMediaFile newMedia: DJIMediaFile) {
            var orientation = self.kernelOrientation
            if let gimbalState = self.gimbalState(channel: camera.index)?.value {
                orientation.x = gimbalState.kernelOrientation.x
                orientation.y = gimbalState.kernelOrientation.y
                if gimbalState.kernelMode == .free {
                    orientation.z = gimbalState.kernelOrientation.z
                }
            }
            else {
                orientation.x = 0
                orientation.y = 0
            }
            self.delegates.invoke { $0.onCameraFileGenerated(session: self, file: DJICameraFile(channel: camera.index, mediaFile: newMedia, coordinate: self.location?.coordinate, altitude: self.altitude, orientation: orientation)) }
    }
}

extension DJIDroneSession: DJIGimbalDelegate {
    public func gimbal(_ gimbal: DJIGimbal, didUpdate state: DJIGimbalState) {
        gimbalSerialQueue.async {
            self._gimbalStates[gimbal.index] = DatedValue<DJIGimbalState>(value: state)
        }
    }
}
