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
    internal static let log = OSLog(subsystem: "DronelinkDJI", category: "DJIDroneSession")
    
    public let manager: DroneSessionManager
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
    private var _initVirtualStickDisabled = false
    private var _lastKnownGroundLocation: CLLocation?
    private var _lastNonZeroFlyingAltitude: Double?
    
    private let delegates = MulticastDelegate<DroneSessionDelegate>()
    private let droneCommands = CommandQueue()
    private let remoteControllerCommands = MultiChannelCommandQueue()
    private let cameraCommands = MultiChannelCommandQueue()
    private let gimbalCommands = MultiChannelCommandQueue()
    
    private let flightControllerSerialQueue = DispatchQueue(label: "DJIDroneSession+flightControllerState")
    private var _flightControllerState: DatedValue<DJIFlightControllerState>?
    private var _flightControllerAirSenseState: DatedValue<DJIAirSenseSystemInformation>?
    
    private let batterySerialQueue = DispatchQueue(label: "DJIDroneSession+batteryState")
    private var _batteryState: DatedValue<DJIBatteryState>?
    
    private let visionDetectionSerialQueue = DispatchQueue(label: "DJIDroneSession+visionDetectionState")
    private var _visionDetectionState: DatedValue<DJIVisionDetectionState>?
    
    private let remoteControllerSerialQueue = DispatchQueue(label: "DJIDroneSession+remoteControllerState")
    private var remoteControllerInitialized: Date?
    private var _remoteControllerState: DatedValue<RemoteControllerStateAdapter>?
    
    private let cameraSerialQueue = DispatchQueue(label: "DJIDroneSession+cameraStates")
    private var _cameraStates: [UInt: DatedValue<DJICameraSystemState>] = [:]
    private var _cameraVideoStreamSources: [UInt: DatedValue<DJICameraVideoStreamSource>] = [:]
    private var _cameraFocusStates: [String: DatedValue<DJICameraFocusState>] = [:]
    private var _cameraStorageStates: [UInt: DatedValue<DJICameraStorageState>] = [:]
    private var _cameraExposureSettings: [String: DatedValue<DJICameraExposureSettings>] = [:]
    private var _cameraLensInformation: [UInt: DatedValue<String>] = [:]
    
    private let gimbalSerialQueue = DispatchQueue(label: "DJIDroneSession+gimbalStates")
    private var _gimbalStates: [UInt: DatedValue<GimbalStateAdapter>] = [:]
    
    private var _diagnosticsInformationMessages: DatedValue<[Kernel.Message]>?
    private var _lowBatteryWarningThreshold: DatedValue<UInt>?
    private var _downlinkSignalQuality: DatedValue<UInt>?
    private var _uplinkSignalQuality: DatedValue<UInt>?
    private var _storageLocation: DatedValue<DJICameraStorageLocation>?
    private var _photoMode: DatedValue<DJICameraShootPhotoMode>?
    private var _burstCount: DatedValue<DJICameraPhotoBurstCount>?
    private var _aebCount: DatedValue<DJICameraPhotoAEBCount>?
    private var _timeIntervalSettings: DatedValue<DJICameraPhotoTimeIntervalSettings>?
    private var _mostRecentCameraFile: DatedValue<CameraFile>?
    private var _whiteBalance: DatedValue<DJICameraWhiteBalance>?
    private var _iso: DatedValue<DJICameraISO>?
    private var _focusRingValue: DatedValue<Double>?
    private var _focusRingMax: DatedValue<Double>?
    private var _remoteControllerGimbalChannel: DatedValue<UInt>?
    public var mostRecentCameraFile: DatedValue<CameraFile>? { get { _mostRecentCameraFile } }
    private var listeningDJIKeys: [DJIKey] = []
    
    public init(manager: DroneSessionManager, drone: DJIAircraft) {
        self.manager = manager
        adapter = DJIDroneAdapter(drone: drone)
        super.init()
        initDrone()
        Thread.detachNewThread(self.execute)
    }
    
    private func initDrone() {
        os_log(.info, log: DJIDroneSession.log, "Drone session opened")
        
        adapter.drone.delegate = self
        adapter.drone.videoFeeder?.add(self)
        initFlightController()
        adapter.cameras?.forEach { initCamera(index: $0.index) }
        adapter.gimbals?.forEach { initGimbal(index: $0.index) }
        initRemoteController()
        initListeners()
    }
    
    private func initFlightController() {
        guard let flightController = adapter.drone.flightController else {
            os_log(.error, log: DJIDroneSession.log, "Flight controller unavailable")
            return
        }
        
        os_log(.info, log: DJIDroneSession.log, "Flight controller connected")
        flightController.delegate = self
        adapter.drone.battery?.delegate = self
        flightController.flightAssistant?.delegate = self
        
        _model = adapter.drone.model ?? ""
        if let model = adapter.drone.model {
            os_log(.info, log: DJIDroneSession.log, "Model: %{public}s", model)
        }
        
        adapter.drone.getFirmwarePackageVersion { [weak self] (firmwarePackageVersion, error) in
            self?._firmwarePackageVersion = firmwarePackageVersion ?? ""
            if let firmwarePackageVersion = firmwarePackageVersion {
                os_log(.info, log: DJIDroneSession.log, "Firmware package version: %{public}s", firmwarePackageVersion)
            }
        }
        
        adapter.drone.getNameWithCompletion { [weak self] (name, error) in
            self?._name = name ?? ""
            if let name = name {
                os_log(.info, log: DJIDroneSession.log, "Name: %{public}s", name)
            }
        }
        
        initSerialNumber()
        
        flightController.getMultipleFlightModeEnabled { enabled, error in
            if !enabled {
                flightController.setMultipleFlightModeEnabled(true) { error in
                    if error == nil {
                        os_log(.debug, log: DJIDroneSession.log, "Flight controller multiple flight mode enabled")
                    }
                }
            }
        }
        
        flightController.getNoviceModeEnabled { enabled, error in
            if enabled {
                flightController.setNoviceModeEnabled(false)  { error in
                   if error == nil {
                       os_log(.debug, log: DJIDroneSession.log, "Flight controller novice mode disabled")
                   }
                }
            }
        }
    }
    
    private func initSerialNumber(attempt: Int = 0) {
        if attempt < 3, let flightController = adapter.drone.flightController {
            flightController.getSerialNumber { [weak self] serialNumber, error in
                if error != nil {
                    self?.initSerialNumber(attempt: attempt + 1)
                    return
                }
                
                self?._serialNumber = serialNumber
                if let serialNumber = serialNumber {
                    os_log(.info, log: DJIDroneSession.log, "Serial number: %{public}s", serialNumber)
                }
            }
        }
    }
    
    private func initCamera(index: UInt) {
        if let camera = adapter.drone.camera(channel: index) {
            os_log(.info, log: DJIDroneSession.log, "Camera[%{public}d] connected: %{public}s", index, camera.model ?? "unknown")
            camera.delegate = self
            
            let xmp = "dronelink:\(Dronelink.shared.kernelVersion?.display ?? "")"
            camera.setMediaFileCustomInformation(xmp) { error in
                if let error = error {
                    os_log(.info, log: DJIDroneSession.log, "Unable to set media file custom information: %{public}s", error.localizedDescription)
                }
                else {
                    os_log(.info, log: DJIDroneSession.log, "Set media file custom information: %{public}s", xmp)
                }
            }
            
            //pumping this one time because camera(_ camera: DJICamera, didUpdate source: DJICameraVideoStreamSource) only gets called on changes
            camera.getVideoStreamSource { [weak self] (source, error) in
                if error == nil {
                    self?.cameraSerialQueue.async {
                        self?._cameraVideoStreamSources[camera.index] = DatedValue<DJICameraVideoStreamSource>(value: source)
                    }
                }
            }
            
            camera.getLensInformation { [weak self] (info, error) in
                if let info = info {
                    self?.cameraSerialQueue.async {
                        self?._cameraLensInformation[camera.index] = DatedValue<String>(value: info)
                    }
                }
            }
            
            camera.lenses.forEach { lens in
                lens.delegate = self
                if lens.isHybridZoomSupported() {
                    initLensHybridZoom(camera: camera, lens: lens)
                }
            }
        }
    }
    
    public func initLensHybridZoom(camera: DJICamera, lens: DJILens, attempt: Int = 0) {
        guard attempt < 3 else {
            os_log(.error, log: DJIDroneSession.log, "Unable to set lens hybrid zoom: no specification found!")
            return
        }
        
        lens.getHybridZoomSpec { [weak self] (spec, error) in
            if let error = error {
                DispatchQueue.global().asyncAfter(deadline: .now() + Double(attempt)) {
                    self?.initLensHybridZoom(camera: camera, lens: lens, attempt: attempt + 1)
                }
                return
            }
            
            var focalLength = spec.minHybridFocalLength
            if camera.displayName.contains("H20") {
                focalLength = 470
            }
            
            lens.setHybridZoomFocalLength(focalLength) { error in
                if let error = error {
                    os_log(.error, log: DJIDroneSession.log, "Unable to set lens hybrid zoom: %{public}s", error.localizedDescription)
                    return
                }

                os_log(.info, log: DJIDroneSession.log, "Set lens hybrid zoom: %{public}d", focalLength)
            }
        }
    }
    
    private func initGimbal(index: UInt) {
        if let gimbal = adapter.drone.gimbal(channel: index) {
            os_log(.info, log: DJIDroneSession.log, "Gimbal[%{public}d] connected", index)
            gimbal.delegate = self
            
            gimbal.getPitchRangeExtensionEnabled { enabled, error in
                if !enabled {
                    gimbal.setPitchRangeExtensionEnabled(true) { error in
                        if error == nil {
                            os_log(.debug, log: DJIDroneSession.log, "Gimbal[%{public}d] pitch range extension enabled", index)
                        }
                    }
                }
            }
        }
    }
    
    private func initRemoteController() {
        if let remoteController = adapter.drone.remoteController {
            remoteControllerInitialized = Date()
            remoteController.delegate = self
        }
    }
    
    private func initListeners() {
        startListeningForChanges(on: DJIFlightControllerKey(param: DJIFlightControllerParamLowBatteryWarningThreshold)!) { [weak self] (oldValue, newValue) in
            if let value = newValue?.unsignedIntegerValue ?? oldValue?.unsignedIntegerValue {
                self?._lowBatteryWarningThreshold = DatedValue(value: value)
            }
            else {
                self?._lowBatteryWarningThreshold = nil
            }
        }
        
        startListeningForChanges(on: DJIAirLinkKey(param: DJIAirLinkParamDownlinkSignalQuality)!) { [weak self] (oldValue, newValue) in
            if let newValue = newValue?.unsignedIntegerValue {
                self?._downlinkSignalQuality = DatedValue(value: newValue)
            }
            else {
                self?._downlinkSignalQuality = nil
            }
        }
        
        startListeningForChanges(on: DJIAirLinkKey(param: DJIAirLinkParamUplinkSignalQuality)!) { [weak self] (oldValue, newValue) in
            if let newValue = newValue?.unsignedIntegerValue {
                self?._uplinkSignalQuality = DatedValue(value: newValue)
            }
            else {
                self?._uplinkSignalQuality = nil
            }
        }
        
        startListeningForChanges(on: DJICameraKey(param: DJICameraParamStorageLocation)!) { [weak self] (oldValue, newValue) in
            if let value = newValue?.unsignedIntegerValue {
                self?._storageLocation = DatedValue(value: DJICameraStorageLocation(rawValue: value) ?? .unknown)
            }
            else {
                self?._storageLocation = nil
            }
        }
        
        startListeningForChanges(on: DJICameraKey(param: DJICameraParamShootPhotoMode)!) { [weak self] (oldValue, newValue) in
            if let value = newValue?.unsignedIntegerValue {
                self?._photoMode = DatedValue(value: DJICameraShootPhotoMode(rawValue: value) ?? .unknown)
            }
            else {
                self?._photoMode = nil
            }
        }
        
        startListeningForChanges(on: DJICameraKey(param: DJICameraParamPhotoBurstCount)!) { [weak self] (oldValue, newValue) in
            if let value = newValue?.unsignedIntegerValue {
                self?._burstCount = DatedValue(value: DJICameraPhotoBurstCount(rawValue: value) ?? .countUnknown)
            }
            else {
                self?._burstCount = nil
            }
        }
        
        startListeningForChanges(on: DJICameraKey(param: DJICameraParamPhotoAEBCount)!) { [weak self] (oldValue, newValue) in
            if let value = newValue?.unsignedIntegerValue {
                self?._aebCount = DatedValue(value: DJICameraPhotoAEBCount(rawValue: value) ?? .countUnknown)
            }
            else {
                self?._aebCount = nil
            }
        }
        
        startListeningForChanges(on: DJICameraKey(param: DJICameraParamPhotoTimeIntervalSettings)!) { [weak self] (oldValue, newValue) in
            var value = DJICameraPhotoTimeIntervalSettings()
            let valuePointer = UnsafeMutableRawPointer(&value)
            (newValue?.value as? NSValue)?.getValue(valuePointer)
            self?._timeIntervalSettings = DatedValue(value: value)
        }
        
        startListeningForChanges(on: DJICameraKey(param: DJICameraParamWhiteBalance)!) { [weak self] (oldValue, newValue) in
            if let value = newValue?.value as? DJICameraWhiteBalance {
                self?._whiteBalance = DatedValue(value: value)
            }
            else {
                self?._whiteBalance = nil
            }
        }
        
        startListeningForChanges(on: DJICameraKey(param: DJICameraParamISO)!) { [weak self] (oldValue, newValue) in
            if let value = newValue?.unsignedIntegerValue {
                self?._iso = DatedValue(value: DJICameraISO(rawValue: value) ?? .isoUnknown)
            }
            else {
                self?._iso = nil
            }
        }
        
        startListeningForChanges(on: DJICameraKey(param: DJICameraParamFocusRingValue)!) { [weak self] (oldValue, newValue) in
            if let value = newValue?.doubleValue {
                self?._focusRingValue = DatedValue(value: value)
            }
            else {
                self?._focusRingValue = nil
            }
        }
        
        startListeningForChanges(on: DJICameraKey(param: DJICameraParamFocusRingValueUpperBound)!) { [weak self] (oldValue, newValue) in
            if let value = newValue?.doubleValue {
                self?._focusRingMax = DatedValue(value: value)
            }
            else {
                self?._focusRingMax = nil
            }
        }
        
        startListeningForChanges(on: DJIRemoteControllerKey(param: DJIRemoteControllerParamControllingGimbalIndex)!) { [weak self] (oldValue, newValue) in
            if let value = newValue?.unsignedIntegerValue {
                self?._remoteControllerGimbalChannel = DatedValue(value: value)
            }
            else {
                self?._remoteControllerGimbalChannel = nil
            }
        }
    }
    
    private func startListeningForChanges(on key: DJIKey, andUpdate updateBlock: @escaping DJIKeyedListenerUpdateBlock) {
        listeningDJIKeys.append(key)
        DJISDKManager.keyManager()?.startListeningForChanges(on: key, withListener: self, andUpdate: updateBlock)
        //pump the value (the DJI SDK only fires updates to keys, not the initial value)
        updateBlock(nil, DJISDKManager.keyManager()?.getValueFor(key))
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
            
        case DJIRemoteControllerComponent:
            initRemoteController()
            break
            
        default:
            break
        }
    }
    
    public func componentDisconnected(withKey key: String?, andIndex index: Int) {
        guard let key = key else { return }
        switch key {
        case DJIFlightControllerComponent:
            os_log(.info, log: DJIDroneSession.log, "Flight controller disconnected")
            flightControllerSerialQueue.async { [weak self] in
                self?._flightControllerState = nil
                self?._flightControllerAirSenseState = nil
            }
            
            batterySerialQueue.async { [weak self] in
                self?._batteryState = nil
            }
            
            visionDetectionSerialQueue.async { [weak self] in
                self?._visionDetectionState = nil
            }
            break
            
        case DJICameraComponent:
            os_log(.info, log: DJIDroneSession.log, "Camera[%{public}d] disconnected", index)
            cameraSerialQueue.async { [weak self] in
                self?._cameraStates[UInt(index)] = nil
                self?._cameraVideoStreamSources[UInt(index)] = nil
                self?._cameraFocusStates = self?._cameraFocusStates.filter({ element in
                    return !element.key.starts(with: "\(index).")
                }) ?? [:]
                self?._cameraStorageStates[UInt(index)] = nil
                self?._cameraExposureSettings = self?._cameraExposureSettings.filter({ element in
                    return !element.key.starts(with: "\(index).")
                }) ?? [:]
                self?._cameraLensInformation[UInt(index)] = nil
            }
            break
            
        case DJIGimbalComponent:
            os_log(.info, log: DJIDroneSession.log, "Gimbal[%{public}d] disconnected", index)
            gimbalSerialQueue.async { [weak self] in
                self?._gimbalStates[UInt(index)] = nil
            }
            break
            
        default:
            break
        }
    }

    public var flightControllerState: DatedValue<DJIFlightControllerState>? {
        flightControllerSerialQueue.sync { [weak self] in
            return self?._flightControllerState
        }
    }
    
    public var batteryState: DatedValue<DJIBatteryState>? {
        batterySerialQueue.sync { [weak self] in
            return self?._batteryState
        }
    }
    
    public var visionDetectionState: DatedValue<DJIVisionDetectionState>? {
        visionDetectionSerialQueue.sync { [weak self] in
            return self?._visionDetectionState
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
                DispatchQueue.global().async { [weak self] in
                    guard let session = self else {
                        return
                    }
                    session.delegates.invoke { $0.onInitialized(session: session) }
                }
            }
            
            if let location = location {
                if (!_located) {
                    _located = true
                    DispatchQueue.global().async { [weak self] in
                        guard let session = self else {
                            return
                        }
                        session.delegates.invoke { $0.onLocated(session: session) }
                    }
                }
                
                if !isFlying {
                    _lastKnownGroundLocation = location
                }
            }
            
            if !_initVirtualStickDisabled, let flightMode = _flightControllerState?.value.flightMode {
                _initVirtualStickDisabled = true
                if flightMode != .gpsWaypoint {
                    adapter.drone.flightController?.getVirtualStickModeEnabled { [weak self] enabled, error in
                        if enabled {
                            self?.adapter.drone.flightController?.setVirtualStickModeEnabled(false) { error in
                               if error == nil {
                                   os_log(.debug, log: DJIDroneSession.log, "Flight controller virtual stick mode deactivated")
                               }
                            }
                        }
                    }
                }
            }
            
            if remoteControllerInitialized == nil {
                initRemoteController()
            }
            
            self.droneCommands.process()
            self.remoteControllerCommands.process()
            self.cameraCommands.process()
            self.gimbalCommands.process()
            
            //FIXME: ignoring on Mavic Air 2S due to gimbal attitude bug, ignore when they fix!
            if (model != DJIAircraftModelNameDJIAir2S) {
                if Dronelink.shared.missionExecutor?.engaged ?? false || Dronelink.shared.modeExecutor?.engaged ?? false {
                    self.gimbalSerialQueue.async { [weak self] in
                        guard let session = self else {
                            return
                        }
                        
                        //work-around for this issue: https://support.dronelink.com/hc/en-us/community/posts/360034749773-Seeming-to-have-a-Heading-error-
                        session.adapter.gimbals?.forEach { gimbalAdapter in
                            if let gimbalAdapter = gimbalAdapter as? DJIGimbalAdapter {
                                var rotation = gimbalAdapter.pendingSpeedRotation
                                gimbalAdapter.pendingSpeedRotation = nil
                                if gimbalAdapter.gimbal.isAdjustYawSupported,
                                   !gimbalAdapter.gimbal.isAdjustYaw360Supported,
                                   let gimbalState = session._gimbalStates[gimbalAdapter.index]?.value,
                                   gimbalState.mode == .yawFollow {
                                    rotation = DJIGimbalRotation(
                                        pitchValue: rotation?.pitch,
                                        rollValue: rotation?.roll,
                                        yawValue: min(max(-session.gimbalYawRelativeToAircraftHeadingCorrected(gimbalState: gimbalState).convertRadiansToDegrees * 0.25, -25), 25) as NSNumber,
                                        time: DJIGimbalRotation.minTime,
                                        mode: .speed,
                                        ignore: false)
                                }
                                
                                if Dronelink.shared.missionExecutor?.engaged ?? false,
                                   gimbalAdapter.gimbal.isAdjustPitchSupported,
                                   (self?._remoteControllerGimbalChannel?.value ?? 0) == gimbalAdapter.index,
                                   let leftWheel = self?.remoteControllerState(channel: gimbalAdapter.index)?.value.leftWheel.value,
                                   leftWheel != 0 {
                                    rotation = DJIGimbalRotation(
                                        pitchValue: (leftWheel * 10) as NSNumber,
                                        rollValue: rotation?.roll,
                                        yawValue: rotation?.yaw,
                                        time: rotation?.time ?? DJIGimbalRotation.minTime,
                                        mode: rotation?.mode ?? .speed,
                                        ignore: rotation?.ignore ?? false)
                                }
                                
                                if let rotation = rotation {
                                    gimbalAdapter.gimbal.rotate(with: rotation, completion: nil)
                                }
                            }
                        }
                    }
                }
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        listeningDJIKeys.forEach { DJISDKManager.keyManager()?.stopListening(on: $0, ofListener: self) }
        os_log(.info, log: DJIDroneSession.log, "Drone session closed")
    }
    
    private func gimbalYawRelativeToAircraftHeadingCorrected(gimbalState: GimbalStateAdapter) -> Double {
        if let model = (drone as? DJIDroneAdapter)?.drone.model {
            switch (model) {
            case DJIAircraftModelNamePhantom4,
                 DJIAircraftModelNamePhantom4Pro,
                 DJIAircraftModelNamePhantom4ProV2,
                 DJIAircraftModelNamePhantom4Advanced,
                 DJIAircraftModelNamePhantom4RTK:
                return gimbalState.orientation.yaw.angleDifferenceSigned(angle: orientation.yaw)
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
            
            if gimbal.isAdjustYawSupported, (gimbalState(channel: gimbal.index)?.value.mode ?? .yawFollow) != .yawFollow {
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
    public var closed: Bool { _closed }
    public var id: String { _id }
    public var manufacturer: String { "DJI" }
    public var serialNumber: String? { _serialNumber }
    public var name: String? { _name }
    public var model: String? { _model }
    public var firmwarePackageVersion: String? { _firmwarePackageVersion }
    public var initialized: Bool { _initialized }
    public var located: Bool { _located }
    public var telemetryDelayed: Bool { -(flightControllerState?.date.timeIntervalSinceNow ?? 0) > 2.0 }
    public var disengageReason: Kernel.Message? {
        if _closed {
            return Kernel.Message(title: "MissionDisengageReason.drone.disconnected.title".localized)
        }
        
        if adapter.drone.flightController == nil {
            return Kernel.Message(title: "MissionDisengageReason.drone.control.unavailable.title".localized)
        }
        
        if flightControllerState == nil {
            return Kernel.Message(title: "MissionDisengageReason.telemetry.unavailable.title".localized)
        }
        
        if telemetryDelayed {
            return Kernel.Message(title: "MissionDisengageReason.telemetry.delayed.title".localized)
        }
        
        if let state = flightControllerState?.value {
            if state.hasReachedMaxFlightHeight {
                return Kernel.Message(title: "MissionDisengageReason.drone.max.altitude.title".localized, details: "MissionDisengageReason.drone.max.altitude.details".localized)
            }
            
            if state.hasReachedMaxFlightRadius {
                return Kernel.Message(title: "MissionDisengageReason.drone.max.distance.title".localized, details: "MissionDisengageReason.drone.max.distance.details".localized)
            }
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
        let createCommand = { [weak self] (execute: @escaping (@escaping CommandFinished) -> Error?) -> Command in
            let c = Command(
                kernelCommand: command,
                execute: execute,
                finished: { [weak self] error in
                    self?.commandFinished(command: command, error: error)
                },
                config: command.config
            )
            
            if c.config.retriesEnabled == nil {
                //disable retries when the DJI SDK reports that the product does not support the feature
                c.config.retriesEnabled = { error in
                    if (error as NSError?)?.code == DJISDKError.productNotSupport.rawValue {
                        return false
                    }
                    return true
                }
            }
            
            if c.config.finishDelay == nil {
                //adding a 1.5 second delay after camera and gimbal mode commands
                if command is Kernel.ModeCameraCommand || command is Kernel.ModeGimbalCommand {
                    c.config.finishDelay = 1.5
                }
            }
            
            return c
        }
        
        if let command = command as? KernelDroneCommand {
            try droneCommands.add(command: createCommand({ [weak self] in
                self?.commandExecuted(command: command)
                return self?.execute(droneCommand: command, finished: $0)
            }))
            return
        }
        
        if let command = command as? KernelRemoteControllerCommand {
            try remoteControllerCommands.add(channel: command.channel, command: createCommand({ [weak self] in
                self?.commandExecuted(command: command)
                return self?.execute(remoteControllerCommand: command, finished: $0)
            }))
            return
        }
        
        if let command = command as? KernelCameraCommand {
            try cameraCommands.add(channel: command.channel, command: createCommand({ [weak self] in
                self?.commandExecuted(command: command)
                return self?.execute(cameraCommand: command, finished: $0)
            }))
            return
        }

        if let command = command as? KernelGimbalCommand {
            try gimbalCommands.add(channel: command.channel, command: createCommand({ [weak self] in
                self?.commandExecuted(command: command)
                return self?.execute(gimbalCommand: command, finished: $0)
            }))
            return
        }
        
        throw DroneSessionError.commandTypeUnhandled
    }
    
    private func commandExecuted(command: KernelCommand) {
        delegates.invoke { $0.onCommandExecuted(session: self, command: command) }
    }
    
    private func commandFinished(command: KernelCommand, error: Error?) {
        delegates.invoke { $0.onCommandFinished(session: self, command: command, error: error) }
    }
    
    public func removeCommands() {
        droneCommands.removeAll()
        remoteControllerCommands.removeAll()
        cameraCommands.removeAll()
        gimbalCommands.removeAll()
    }
    
    public func createControlSession(executionEngine: Kernel.ExecutionEngine, executor: Executor) -> DroneControlSession? {
        switch executionEngine {
        case .dronelinkKernel:
            return DJIVirtualStickSession(droneSession: self)
            
        case .dji:
            if let missionExecutor = executor as? MissionExecutor {
                 return DJIWaypointMissionSession(droneSession: self, missionExecutor: missionExecutor)
            }
            break
        }
        
        return nil
    }
    
    public func cameraState(channel: UInt) -> DatedValue<CameraStateAdapter>? {
        cameraState(channel: channel, lensIndex: nil)
    }
    
    public func cameraState(channel: UInt, lensIndex: UInt?) -> DatedValue<CameraStateAdapter>? {
        cameraSerialQueue.sync { [weak self] in
            guard let session = self, let camera = drone.camera(channel: channel) else {
                return nil
            }
            
            if let systemState = session._cameraStates[channel] {
                var lensIndexResolved: UInt = 0
                if let lensIndexValid = lensIndex {
                    lensIndexResolved = lensIndexValid
                }
                else if let videoStreamSource = session._cameraVideoStreamSources[channel]?.value {
                    lensIndexResolved = camera.lensIndex(videoStreamSource: videoStreamSource.kernelValue)
                }
                    
                return DatedValue(value: DJICameraStateAdapter(
                    systemState: systemState.value,
                    videoStreamSource: session._cameraVideoStreamSources[channel]?.value,
                    focusState: session._cameraFocusStates["\(channel).\(lensIndexResolved)"]?.value,
                    storageState: session._cameraStorageStates[channel]?.value,
                    exposureSettings: session._cameraExposureSettings["\(channel).\(lensIndexResolved)"]?.value,
                    lensIndex: lensIndexResolved,
                    lensInformation: session._cameraLensInformation[channel]?.value,
                    storageLocation: session._storageLocation?.value,
                    photoMode: session._photoMode?.value,
                    burstCount: session._burstCount?.value,
                    aebCount: session._aebCount?.value,
                    intervalSettings: session._timeIntervalSettings?.value,
                    whiteBalance: session._whiteBalance?.value,
                    iso: session._iso?.value,
                    focusRingValue: _focusRingValue?.value,
                    focusRingMax: _focusRingMax?.value),
                    date: systemState.date)
            }
            return nil
        }
    }

    public func gimbalState(channel: UInt) -> DatedValue<GimbalStateAdapter>? {
        gimbalSerialQueue.sync { [weak self] in
            if let gimbalState = self?._gimbalStates[channel] {
                return DatedValue<GimbalStateAdapter>(value: gimbalState.value, date: gimbalState.date)
            }
            return nil
        }
    }

    public func remoteControllerState(channel: UInt) -> DatedValue<RemoteControllerStateAdapter>? {
        remoteControllerSerialQueue.sync { [weak self] in
            return self?._remoteControllerState
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
        var messages: [Kernel.Message] = []
        
        if let state = flightControllerState?.value {
            messages.append(contentsOf: state.statusMessages)
        }
        else {
            messages.append(Kernel.Message(title: "DJIDroneSession.telemetry.unavailable".localized, level: .danger))
        }
        
        if let airSenseState = _flightControllerAirSenseState?.value {
            messages.append(contentsOf: airSenseState.statusMessages)
        }
        
        if let diagnosticMessages = _diagnosticsInformationMessages?.value {
            messages.append(contentsOf: diagnosticMessages)
        }
        
        return messages
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
    public var ultrasonicAltitude: Double? { flightControllerState?.value.isUltrasonicBeingUsed ?? false ? flightControllerState?.value.ultrasonicHeightInMeters : nil }
    public var batteryPercent: Double? {
        if let chargeRemainingInPercent = batteryState?.value.chargeRemainingInPercent {
            return Double(chargeRemainingInPercent) / 100
        }
        return nil
    }
    public var lowBatteryThreshold: Double? {
        if let lowBatteryWarningThreshold = _lowBatteryWarningThreshold?.value {
            return Double(lowBatteryWarningThreshold) / 100
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
    public var orientation: Kernel.Orientation3 { flightControllerState?.value.orientation ?? Kernel.Orientation3() }
    public var gpsSatellites: Int? {
        if let satelliteCount = flightControllerState?.value.satelliteCount {
            return Int(satelliteCount)
        }
        return nil
    }
    public var gpsSignalStrength: Double? { flightControllerState?.value.gpsSignalLevel.doubleValue }
    public var downlinkSignalStrength: Double? {
        if let downlinkSignalQuality = _downlinkSignalQuality?.value {
            return Double(downlinkSignalQuality) / 100.0
        }
        return nil
    }
    public var uplinkSignalStrength: Double? {
        if let uplinkSignalQuality = _uplinkSignalQuality?.value {
            return Double(uplinkSignalQuality) / 100.0
        }
        return nil
    }
}

extension DJIDroneSession: DJIBaseProductDelegate {
    public func product(_ product: DJIBaseProduct, didUpdateDiagnosticsInformation info: [Any]) {
        var messages: [Kernel.Message] = []
        info.forEach { (value) in
            if let message = (value as? DJIDiagnostics)?.message {
                messages.append(message)
            }
        }
        
        self._diagnosticsInformationMessages = DatedValue(value: messages)
    }
}

extension DJIDroneSession: DJIFlightControllerDelegate {
    public func flightController(_ fc: DJIFlightController, didUpdate state: DJIFlightControllerState) {
        flightControllerSerialQueue.async { [weak self] in
            guard let session = self else {
                return
            }
            
            if session._flightControllerState?.value.isFlying ?? false, !state.isFlying {
                if Dronelink.shared.droneOffsets.droneAltitudeContinuity {
                    //automatically adjust the drone altitude offset if:
                    //1) altitude continuity is enabled
                    //2) the drone is going from flying to not flying
                    //3) the altitude reference is ground level
                    //4) the current drone altitude offset is not zero
                    //5) the last non-zero flying altitude is available
                    //6) the absolute value of last non-zero flying altitude is more than 1m
                    if (Dronelink.shared.droneOffsets.droneAltitudeReference ?? 0) == 0,
                        let lastNonZeroFlyingAltitude = session._lastNonZeroFlyingAltitude,
                        abs(lastNonZeroFlyingAltitude) > 1 {
                        //adjust by the last non-zero flying altitude
                        Dronelink.shared.droneOffsets.droneAltitude -= lastNonZeroFlyingAltitude
                    }
                }
                else {
                    Dronelink.shared.droneOffsets.droneAltitude = 0
                }
            }
            
            let motorsOnPrevious = session._flightControllerState?.value.areMotorsOn ?? false
            session._flightControllerState = DatedValue<DJIFlightControllerState>(value: state)
            if (motorsOnPrevious != state.areMotorsOn) {
                session.delegates.invoke { $0.onMotorsChanged(session: session, value: state.areMotorsOn) }
            }
            
            if state.isFlying {
                if state.altitude != 0 {
                    session._lastNonZeroFlyingAltitude = state.altitude
                }
            }
            else {
                session._lastNonZeroFlyingAltitude = nil
            }
        }
    }
    
    public func flightController(_ fc: DJIFlightController, didUpdate information: DJIAirSenseSystemInformation) {
        flightControllerSerialQueue.async { [weak self] in
            guard let session = self else {
                return
            }
            
            session._flightControllerAirSenseState = DatedValue(value: information)
        }
    }
}

extension DJIDroneSession: DJIFlightAssistantDelegate {
    public func flightAssistant(_ assistant: DJIFlightAssistant, didUpdate state: DJIVisionDetectionState) {
        if state.position == .nose {
            visionDetectionSerialQueue.async { [weak self] in
                self?._visionDetectionState = DatedValue<DJIVisionDetectionState>(value: state)
            }
        }
    }
}

extension DJIDroneSession: DJIBatteryDelegate {
    public func battery(_ battery: DJIBattery, didUpdate state: DJIBatteryState) {
        batterySerialQueue.async { [weak self] in
            self?._batteryState = DatedValue<DJIBatteryState>(value: state)
        }
    }
}

extension DJIDroneSession: DJIRemoteControllerDelegate {
    public func remoteController(_ rc: DJIRemoteController, didUpdate state: DJIRCHardwareState) {
        remoteControllerSerialQueue.async { [weak self] in
            self?._remoteControllerState = DatedValue<RemoteControllerStateAdapter>(value: DJIRemoteControllerStateAdapter(rcHardwareState: state))
        }
    }
}

extension DJIDroneSession: DJICameraDelegate {
    public func camera(_ camera: DJICamera, didUpdate systemState: DJICameraSystemState) {
        cameraSerialQueue.async { [weak self] in
            self?._cameraStates[camera.index] = DatedValue<DJICameraSystemState>(value: systemState)
        }
    }
    
    public func camera(_ camera: DJICamera, didUpdate source: DJICameraVideoStreamSource) {
        cameraSerialQueue.async { [weak self] in
            self?._cameraVideoStreamSources[camera.index] = DatedValue<DJICameraVideoStreamSource>(value: source)
        }
    }
    
    public func camera(_ camera: DJICamera, didUpdate focusState: DJICameraFocusState) {
        cameraSerialQueue.async { [weak self] in
            self?._cameraFocusStates["\(camera.index).0"] = DatedValue<DJICameraFocusState>(value: focusState)
        }
    }
    
    public func camera(_ camera: DJICamera, didUpdate storageState: DJICameraStorageState) {
        if storageState.location == .sdCard {
            cameraSerialQueue.async { [weak self] in
                self?._cameraStorageStates[camera.index] = DatedValue<DJICameraStorageState>(value: storageState)
            }
        }
    }
    
    public func camera(_ camera: DJICamera, didUpdate settings: DJICameraExposureSettings) {
        cameraSerialQueue.async { [weak self] in
            self?._cameraExposureSettings["\(camera.index).0"] = DatedValue<DJICameraExposureSettings>(value: settings)
        }
    }
    
    public func camera(_ camera: DJICamera, didGenerateNewMediaFile newMedia: DJIMediaFile) {
        var orientation = self.orientation
        if let gimbalState = self.gimbalState(channel: camera.index)?.value {
            orientation.x = gimbalState.orientation.x
            orientation.y = gimbalState.orientation.y
            if gimbalState.mode == .free {
                orientation.z = gimbalState.orientation.z
            }
        }
        else {
            orientation.x = 0
            orientation.y = 0
        }

        let cameraFile = DJICameraFile(channel: camera.index, mediaFile: newMedia, coordinate: self.location?.coordinate, altitude: self.altitude, orientation: orientation)
        _mostRecentCameraFile = DatedValue(value: cameraFile)
        self.delegates.invoke { $0.onCameraFileGenerated(session: self, file: cameraFile) }
    }
}

extension DJIDroneSession: DJILensDelegate {
    public func lens(_ lens: DJILens, didUpdate focusState: DJICameraFocusState) {
        cameraSerialQueue.async { [weak self] in
            self?._cameraFocusStates["\(lens.cameraIndex).\(lens.index)"] = DatedValue<DJICameraFocusState>(value: focusState)
        }
    }
    
    public func lens(_ lens: DJILens, didUpdate settings: DJICameraExposureSettings) {
        cameraSerialQueue.async { [weak self] in
            self?._cameraExposureSettings["\(lens.cameraIndex).\(lens.index)"] = DatedValue<DJICameraExposureSettings>(value: settings)
        }
    }
}

extension DJIDroneSession: DJIGimbalDelegate {
    public func gimbal(_ gimbal: DJIGimbal, didUpdate state: DJIGimbalState) {
        gimbalSerialQueue.async { [weak self] in
            self?._gimbalStates[gimbal.index] = DatedValue<GimbalStateAdapter>(value: DJIGimbalStateAdapter(gimbalState: state))
        }
    }
}

extension DJIDroneSession: DJIVideoFeedSourceListener {
    public func videoFeed(_ videoFeed: DJIVideoFeed, didChange physicalSource: DJIVideoFeedPhysicalSource) {
        DispatchQueue.global().async { [weak self] in
            guard let session = self else {
                return
            }
            session.delegates.invoke { $0.onVideoFeedSourceUpdated(session: session, channel: session.adapter.drone.videoFeeder?.channel(feed: videoFeed)) }
        }
    }
}
