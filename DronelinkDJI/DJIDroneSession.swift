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
    public var offsets = DroneSessionOffsets()
    
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
    
    private let delegates = MulticastDelegate<DroneSessionDelegate>()
    private let droneCommands = CommandQueue()
    private let cameraCommands = MultiChannelCommandQueue()
    private let gimbalCommands = MultiChannelCommandQueue()
    
    private let flightControllerSerialQueue = DispatchQueue(label: "DroneSession+flightControllerState")
    private var _flightControllerState: DatedValue<DJIFlightControllerState>?
    
    private let visionDetectionSerialQueue = DispatchQueue(label: "DroneSession+visionDetectionState")
    private var _visionDetectionState: DatedValue<DJIVisionDetectionState>?
    
    private let cameraSerialQueue = DispatchQueue(label: "DroneSession+cameraStates")
    private var _cameraStates: [UInt: DatedValue<DJICameraSystemState>] = [:]
    private var _cameraExposureSettings: [UInt: DatedValue<DJICameraExposureSettings>] = [:]
    
    private let gimbalSerialQueue = DispatchQueue(label: "DroneSession+gimbalStates")
    private var _gimbalStates: [UInt: DatedValue<DJIGimbalState>] = [:]
    
    private let remoteControllerSerialQueue = DispatchQueue(label: "DroneSession+remoteControllerState")
    private var _remoteControllerState: DatedValue<RemoteControllerStateAdapter>?
    
    public init(drone: DJIAircraft) {
        adapter = DJIDroneAdapter(drone: drone)
        super.init()
        initDrone()
        Thread.detachNewThread(self.execute)
    }
    
    private func initDrone() {
        os_log(.info, log: log, "Drone session opened")
        
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
        
        flightController.getSerialNumber { serialNumber, error in
            self._serialNumber = serialNumber
            if let serialNumber = serialNumber {
                os_log(.info, log: self.log, "Serial number: %{public}s", serialNumber)
            }
        }
        flightController.setMultipleFlightModeEnabled(true) { error in
            if error == nil {
                os_log(.debug, log: self.log, "Flight controller multiple flight mode enabled")
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
            
            visionDetectionSerialQueue.async {
                self._visionDetectionState = nil
            }
            break
            
        case DJICameraComponent:
            os_log(.info, log: log, "Camera[%{public}d] disconnected", index)
            cameraSerialQueue.async {
                self._cameraStates[UInt(index)] = nil
                self._cameraExposureSettings[UInt(index)] = nil
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
            
            self.gimbalSerialQueue.sync {
                //work-around for this issue: https://support.dronelink.com/hc/en-us/community/posts/360034749773-Seeming-to-have-a-Heading-error-
                self.adapter.gimbals?.forEach { gimbalAdapter in
                    if let gimbalAdapter = gimbalAdapter as? DJIGimbalAdapter {
                        var rotation = gimbalAdapter.pendingSpeedRotation
                        gimbalAdapter.pendingSpeedRotation = nil
                        if gimbalAdapter.gimbal.isAdjustYawSupported, let gimbalState = self._gimbalStates[gimbalAdapter.index]?.value, gimbalState.mode == .yawFollow {
                            rotation = DJIGimbalRotation(
                                pitchValue: rotation?.pitch,
                                rollValue: rotation?.roll,
                                yawValue: min(max(-gimbalState.yawRelativeToAircraftHeading * 0.1, -5), 5) as NSNumber,
                                time: DJIGimbalRotation.minTime,
                                mode: .speed)
                        }
                        
                        if let rotation = rotation {
                            gimbalAdapter.gimbal.rotate(with: rotation, completion: nil)
                        }
                    }
                }
            }
            
            Thread.sleep(forTimeInterval: 0.1)
        }
        os_log(.info, log: log, "Drone session closed")
    }
    
    internal func sendResetVelocityCommand(withCompletion: DJICompletionBlock? = nil) {
        adapter.sendResetVelocityCommand(withCompletion: withCompletion)
    }
    
    internal func sendResetGimbalCommands() {
        adapter.drone.gimbals?.forEach {
            $0.rotate(with: DJIGimbalRotation(
                pitchValue: $0.isAdjustPitchSupported ? -12.0.convertDegreesToRadians as NSNumber : nil,
                rollValue: $0.isAdjustRollSupported ? 0 : nil,
                yawValue: $0.isAdjustYawSupported ? 0 : nil,
                time: DJIGimbalRotation.minTime,
                mode: .absoluteAngle), completion: nil)
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
    public var disengageReason: Mission.Message? {
        if adapter.drone.flightController == nil {
            return Mission.Message(title: "MissionDisengageReason.drone.control.unavailable.title".localized)
        }
        
        if flightControllerState == nil {
            return Mission.Message(title: "MissionDisengageReason.telemetry.unavailable.title".localized)
        }
        
        if telemetryDelayed {
            return Mission.Message(title: "MissionDisengageReason.telemetry.delayed.title".localized)
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
    
    public func add(command: MissionCommand) throws {
        if let command = command as? MissionDroneCommand {
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
        
        if let command = command as? MissionCameraCommand {
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

        if let command = command as? MissionGimbalCommand {
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
    
    private func commandExecuted(command: MissionCommand) {
        self.delegates.invoke { $0.onCommandExecuted(session: self, command: command) }
    }
    
    private func commandFinished(command: MissionCommand, error: Error?) {
        self.delegates.invoke { $0.onCommandFinished(session: self, command: command, error: error) }
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
                return DatedValue(value: DJICameraStateAdapter(systemState: systemState.value, exposureSettings: self._cameraExposureSettings[channel]?.value), date: systemState.date)
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
    
    public func close() {
        _closed = true
    }
}

extension DJIDroneSession: DroneStateAdapter {
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
    public var obstacleDistance: Double? {visionDetectionState?.value.detectionSectors?[safeIndex: 0]?.obstacleDistanceInMeters }
    public var missionOrientation: Mission.Orientation3 { flightControllerState?.value.missionOrientation ?? Mission.Orientation3() }
}

extension DJIDroneSession: DJIFlightControllerDelegate {
    public func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
        flightControllerSerialQueue.async {
            let motorsOnPrevious = self._flightControllerState?.value.areMotorsOn ?? false
            self._flightControllerState = DatedValue<DJIFlightControllerState>(value: state)
            if (motorsOnPrevious != state.areMotorsOn) {
                DispatchQueue.global().async {
                    self.delegates.invoke { $0.onMotorsChanged(session: self, value: state.areMotorsOn) }
                }
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
    
    public func camera(_ camera: DJICamera, didUpdate settings: DJICameraExposureSettings) {
        cameraSerialQueue.async {
            self._cameraExposureSettings[camera.index] = DatedValue<DJICameraExposureSettings>(value: settings)
        }
    }
    
    public func camera(_ camera: DJICamera, didGenerateNewMediaFile newMedia: DJIMediaFile) {
        DispatchQueue.global().async {
            var orientation = self.missionOrientation
            if let gimbalState = self.gimbalState(channel: camera.index)?.value {
                orientation.x = gimbalState.missionOrientation.x
                orientation.y = gimbalState.missionOrientation.y
                if gimbalState.missionMode == .free {
                    orientation.z = gimbalState.missionOrientation.z
                }
            }
            else {
                orientation.x = 0
                orientation.y = 0
            }
            self.delegates.invoke { $0.onCameraFileGenerated(session: self, file: DJICameraFile(channel: camera.index, mediaFile: newMedia, coordinate: self.location?.coordinate, altitude: self.altitude, orientation: orientation)) }
        }
    }
}

extension DJIDroneSession: DJIGimbalDelegate {
    public func gimbal(_ gimbal: DJIGimbal, didUpdate state: DJIGimbalState) {
        gimbalSerialQueue.async {
            self._gimbalStates[gimbal.index] = DatedValue<DJIGimbalState>(value: state)
        }
    }
}
