//
//  DJIWaypointMissionSession.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 8/20/21.
//  Copyright © 2021 Dronelink. All rights reserved.
//
import DronelinkCore
import JavaScriptCore
import DJISDK
import os

public class DJIWaypointMissionSession: DroneControlSession {
    private static let log = OSLog(subsystem: "DronelinkDJI", category: "DJIWaypointMissionSession")
    
    public let executionEngine = Kernel.ExecutionEngine.dji
    
    private enum State {
        case Ready
        case Activating
        case Activated
        case Deactivated
    }
    
    private let djiWaypointMissionOperator: DJIWaypointMissionOperator
    private let droneSession: DJIDroneSession
    private let missionExecutor: MissionExecutor
    private var kernelComponents: [Kernel.DJIWaypointMissionComponent]
    private var djiWaypointMissions: [DJIWaypointMission]
    
    private var state: State = .Ready
    private var _disengageReason: Kernel.Message?
    public var disengageReason: Kernel.Message? {
        get {
            if let disengageReason = _disengageReason {
                return disengageReason
            }
            
            if state == .Activated {
                if let flightControllerState = droneSession.flightControllerState {
                    switch flightControllerState.value.flightMode {
                    case .motorsJustStarted, .autoTakeoff, .assistedTakeoff, .joystick, .gpsAtti, .gpsWaypoint:
                        break
                        
                    case .goHome, .autoLanding:
                        if !terminalFlightModeAllowed {
                            return Kernel.Message(title: "MissionDisengageReason.drone.control.override.title".localized, details: "MissionDisengageReason.drone.control.override.details".localized)
                        }
                        break
                        
                    default:
                        return Kernel.Message(title: "MissionDisengageReason.drone.control.override.title".localized, details: "MissionDisengageReason.drone.control.override.details".localized)
                    }
                }
                
                switch djiWaypointMissionOperator.currentState {
                case .unknown, .recovering, .notSupported, .executionPaused:
                    return Kernel.Message(title: "MissionDisengageReason.drone.control.override.title".localized, details: "MissionDisengageReason.drone.control.override.details".localized)
                    
                case .disconnected:
                    return Kernel.Message(title: "MissionDisengageReason.drone.disconnected.title".localized)
                       
                case .readyToExecute, .readyToUpload, .uploading, .executing:
                    break
                }
            }
            
            return nil
        }
    }
    private var executionState: Kernel.DJIExecutionState? { missionExecutor.externalExecutionState(executionEngine: executionEngine) as? Kernel.DJIExecutionState }
    private var resumeWaypointIndex = 0
    private var resumeWaypointProgress = 0.0
    private var terminalFlightModeAllowed = false
    
    public init?(droneSession: DJIDroneSession, missionExecutor: MissionExecutor) {
        guard
            let djiWaypointMissionOperator = DJISDKManager.missionControl()?.waypointMissionOperator(),
            let kernelComponents = missionExecutor.jsonForExecutionEngine(executionEngine: .dji)?.decodeArray({ (element) -> Kernel.DJIWaypointMissionComponent? in
                guard let object = element.toObject() else {
                    return nil
                }
                return JSValue.decode(object: object, type: Kernel.DJIWaypointMissionComponent.self)
            }),
            kernelComponents.count > 0
        else {
            return nil
        }
        
        self.djiWaypointMissionOperator = djiWaypointMissionOperator
        self.droneSession = droneSession
        self.missionExecutor = missionExecutor
        self.kernelComponents = kernelComponents
        self.djiWaypointMissions = kernelComponents.map { $0.djiValue }
        for mission in djiWaypointMissions {
            if let error = mission.checkValidity() {
                return nil
            }
        }
        
        if executionState?.status.completed ?? false {
            return nil
        }
    }
    
    public var reengaging: Bool {
        guard
            state == .Activated,
            resumeWaypointIndex > 0 || resumeWaypointProgress > 0,
            let targetWaypointIndex = djiWaypointMissionOperator.latestExecutionProgress?.targetWaypointIndex
        else {
            return false
        }
        
        return targetWaypointIndex == 0
    }
    
    public func activate() -> Bool? {
        switch state {
        case .Ready:
            state = .Activating
            DispatchQueue.global().async { [weak self] in
                self?.activating()
            }
            return nil
            
        case .Activating:
            return _disengageReason == nil ? nil : false
            
        case .Activated:
            return true
            
        case .Deactivated:
            return false
        }
    }
    
    private func activating() {
        if state != .Activating {
            return
        }
        
        DJISDKManager.closeConnection(whenEnteringBackground: false)
        
        guard
            let executionState = executionState,
            let currentDJIWaypointMission = djiWaypointMissions[safeIndex: executionState.componentIndex]
        else {
            _disengageReason = Kernel.Message(title: "MissionDisengageReason.execution.state.invalid.title".localized)
            return
        }
        
        if let loadedMission = djiWaypointMissionOperator.loadedMission, currentDJIWaypointMission.missionID == loadedMission.missionID {
            if djiWaypointMissionOperator.currentState == .executing {
                os_log(.info, log: DJIWaypointMissionSession.log, "Mission already executing")
                updateExternalExecutionState(
                    values: [
                        "revertDisengagment": "true",
                    ]
                )
                
                if loadedMission.waypointCount < currentDJIWaypointMission.waypointCount {
                    resumeWaypointIndex = Int(currentDJIWaypointMission.waypointCount - loadedMission.waypointCount)
                    resumeWaypointProgress = executionState.waypointProgress
                }
                
                state = .Activated
                startProgressListeners()
                return
            }
        }
        
        
        if djiWaypointMissionOperator.currentState == .executing || djiWaypointMissionOperator.currentState == .executionPaused {
            os_log(.info, log: DJIWaypointMissionSession.log, "Stopping previous mission")
            djiWaypointMissionOperator.stopMission { [weak self] error in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                    self?.startCurrentMission()
                }
            }
            return
        }
        
        startCurrentMission()
    }
    
    private func startCurrentMission() {
        if state == .Deactivated {
            return
        }
        
        guard
            let executionState = executionState,
            let currentDJIWaypointMission = djiWaypointMissions[safeIndex: executionState.componentIndex],
            let currentKernelComponent = kernelComponents[safeIndex: executionState.componentIndex]
        else {
            _disengageReason = Kernel.Message(title: "MissionDisengageReason.execution.state.invalid.title".localized)
            return
        }
        
        terminalFlightModeAllowed = false
        let mission = currentDJIWaypointMission.mutableCopy()
        if executionState.waypointProgress > 0 {
            mission.removeAllWaypoints()
            resumeWaypointIndex = executionState.waypointIndex
            resumeWaypointProgress = executionState.waypointProgress
            (0..<currentDJIWaypointMission.waypointCount).forEach { index in
                if index >= resumeWaypointIndex, let waypoint = currentDJIWaypointMission.waypoint(at: index) {
                    if mission.waypointCount == 0, resumeWaypointProgress > 0, let nextWaypoint = currentDJIWaypointMission.waypoint(at: index + 1) {
                        if let reengagementSpatial = missionExecutor.reengagementSpatial {
                            waypoint.removeAllActions()
                            waypoint.coordinate = reengagementSpatial.coordinate.coordinate
                            waypoint.altitude = Float(reengagementSpatial.altitude.value)
                            if mission.headingMode == .usingWaypointHeading {
                                waypoint.heading += (Int(Double(nextWaypoint.heading - waypoint.heading) * resumeWaypointProgress))
                            }
                            
                            if mission.rotateGimbalPitch {
                                waypoint.gimbalPitch += ((nextWaypoint.gimbalPitch - waypoint.gimbalPitch) * Float(resumeWaypointProgress))
                            }
                        }
                        
                        if waypoint.distance(to: nextWaypoint) < 0.5 {
                            waypoint.coordinate = waypoint.coordinate.coordinate(bearing: nextWaypoint.coordinate.bearing(to: waypoint.coordinate), distance: 0.5)
                            return
                        }
                        
                        nextWaypoint.cornerRadiusInMeters = max(min((Float(waypoint.coordinate.distance(to: nextWaypoint.coordinate)) - 1) / 2, nextWaypoint.cornerRadiusInMeters), 0.2)
                    }
                    
                    if mission.waypointCount == 0 {
                        waypoint.cornerRadiusInMeters = 0.2
                    }
                    
                    mission.add(waypoint)
                }
            }
            
            os_log(.info, log: DJIWaypointMissionSession.log, "Updating mission to resume at %{public}s between waypoint %{public}s and %{public}s", Dronelink.shared.format(formatter: "percent", value: resumeWaypointProgress), "\(resumeWaypointIndex + 1)", "\(resumeWaypointIndex + 2)")
        }
        
        os_log(.info, log: DJIWaypointMissionSession.log, "Attempting load mission")
        if let error = djiWaypointMissionOperator.load(mission) {
            os_log(.error, log: DJIWaypointMissionSession.log, "Load mission failed: %{public}s", error.localizedDescription)
            _disengageReason = Kernel.Message(title: "MissionDisengageReason.load.mission.failed.title".localized, details: error.localizedDescription)
            return
        }
        
        os_log(.info, log: DJIWaypointMissionSession.log, "Load mission succeeded")
        
        djiWaypointMissionOperator.addListener(toUploadEvent: self, with: DispatchQueue.global()) { [weak self] event in
            guard self?.state != .Deactivated, let session = self else {
                return
            }
            
            switch event.currentState {
            case .uploading:
                if let progress = event.progress {
                    os_log(.info, log: DJIWaypointMissionSession.log, "Uploading mission progress: %{public}s", "\(progress.uploadedWaypointIndex)")
                    if self?.state == .Activated {
                        session.updateExternalExecutionState(
                            messages: [
                                Kernel.Message(title: String(format: "DJIWaypointMissionSession.statusMessage.uploading".localized, "\(progress.uploadedWaypointIndex + 1)", "\(currentDJIWaypointMission.waypointCount)"))
                            ]
                        )
                    }
                }
                break

            case .readyToExecute:
                session.djiWaypointMissionOperator.removeListener(ofUploadEvents: self)
                session.start(cameraCaptureConfigurations: currentKernelComponent.cameraCaptureConfigurations)
                os_log(.info, log: DJIWaypointMissionSession.log, "Attempting start mission")
                session.djiWaypointMissionOperator.startMission { [weak self] error in
                    if self?.state == .Deactivated {
                        return
                    }
                    
                    if let error = error {
                        os_log(.error, log: DJIWaypointMissionSession.log, "Start mission failed: %{public}s", error.localizedDescription)
                        self?._disengageReason = Kernel.Message(title: "MissionDisengageReason.start.mission.failed.title".localized, details: error.localizedDescription)
                        return
                    }
                    
                    os_log(.info, log: DJIWaypointMissionSession.log, "Start mission succeeded")
                    self?.state = .Activated
                    self?.startProgressListeners()
                }
                break
                
            case .unknown, .readyToUpload, .disconnected, .recovering, .notSupported, .executing, .executionPaused:
                self?.uploadFailed(error: event.error ?? "Unknown Error")
                break
            }
        }
        
        os_log(.info, log: DJIWaypointMissionSession.log, "Attempting to start uploading mission")
        djiWaypointMissionOperator.uploadMission { [weak self] error in
            if self?.state == .Deactivated {
                return
            }
            
            if let error = error {
                self?.uploadFailed(error: error)
                return
            }
            
            os_log(.info, log: DJIWaypointMissionSession.log, "Start uploading mission succeeded")
        }
    }
    
    private func updateExternalExecutionState(status: Kernel.ExecutionStatus = .executing, messages: [Kernel.Message]? = nil, values: [String : String]? = nil) {
        missionExecutor.updateExternalExecutionState(executionEngine: executionEngine, status: status, progress: 0, messages: messages, values: values)
    }
    
    private func uploadFailed(error: Error) {
        os_log(.error, log: DJIWaypointMissionSession.log, "Upload mission failed: %{public}s", error.localizedDescription)
        _disengageReason = Kernel.Message(title: "MissionDisengageReason.upload.mission.failed.title".localized, details: error.localizedDescription)
    }
    
    private func startProgressListeners() {
        if state != .Activated {
            return
        }
        
        djiWaypointMissionOperator.addListener(toExecutionEvent: self, with: DispatchQueue.global()) { [weak self] event in
            if self?.state == .Deactivated {
                return
            }
            
            guard
                let session = self,
                let executionState = session.executionState,
                let currentDJIWaypointMission = session.djiWaypointMissions[safeIndex: executionState.componentIndex],
                let currentKernelComponent = session.kernelComponents[safeIndex: executionState.componentIndex]
            else {
                self?._disengageReason = Kernel.Message(title: "MissionDisengageReason.execution.state.invalid.title".localized)
                return
            }
            
            if event.currentState == .executing, let progress = event.progress {
                let waypointIndex = session.resumeWaypointIndex + max(0, progress.targetWaypointIndex - (progress.isWaypointReached ? 0 : 1))
                var messages: [Kernel.Message] = []
                if session.kernelComponents.count > 1 {
                    messages.append(Kernel.Message(title: String(format: "DJIWaypointMissionSession.statusMessage.component".localized, "\(executionState.componentIndex + 1)", "\(session.kernelComponents.count)"), details: currentKernelComponent.descriptors.name))
                }
                
                var waypointProgress = 0.0
                var waypointDistance = 0.0
                var droneDistance = 0.0
                
                if progress.targetWaypointIndex > 0 {
                    if let a = currentDJIWaypointMission.waypoint(at: UInt(waypointIndex)),
                       let b = currentDJIWaypointMission.waypoint(at: UInt(waypointIndex + 1)) {
                        waypointDistance = a.distance(to: b)
                    }
                    
                    if let waypoint = currentDJIWaypointMission.waypoint(at: UInt(waypointIndex)),
                       let state = self?.droneSession.state?.value,
                       let droneLocation = state.location {
                        let x = waypoint.coordinate.distance(to: droneLocation.coordinate)
                        let y = abs(Double(waypoint.altitude) - state.altitude)
                        droneDistance = sqrt(pow(x, 2) + pow(y, 2))
                    }
                    
                    waypointProgress = progress.isWaypointReached ? 1 : waypointDistance == 0 ? 0 : min(1, droneDistance / waypointDistance)
                }
                else {
                    waypointProgress = session.resumeWaypointProgress
                }
                
                if session.resumeWaypointIndex > 0 || session.resumeWaypointProgress > 0, progress.targetWaypointIndex == 0 {
                    messages.append(Kernel.Message(title: String(format: "DJIWaypointMissionSession.statusMessage.reengaging".localized, Dronelink.shared.format(formatter: "percent", value: session.resumeWaypointProgress), "\(waypointIndex + 2)")))
                }
                else if progress.targetWaypointIndex == 0 {
                    messages.append(Kernel.Message(title: String(format: "DJIWaypointMissionSession.statusMessage.waypoint.0".localized, "\(waypointIndex + 1)", "\(currentDJIWaypointMission.waypointCount)")))
                }
                else {
                    messages.append(Kernel.Message(title: String(format: "DJIWaypointMissionSession.statusMessage.waypoint.n".localized, "\(min(waypointIndex + 1, Int(currentDJIWaypointMission.waypointCount) - 1) + 1)", "\(currentDJIWaypointMission.waypointCount)", Dronelink.shared.format(formatter: "percent", value: waypointProgress))))
                }
                
                session.terminalFlightModeAllowed = waypointIndex == currentDJIWaypointMission.waypointCount - 1 && progress.isWaypointReached
    
                session.updateExternalExecutionState(
                    messages: messages,
                    values: [
                        "waypointIndex": "\(waypointIndex)",
                        "waypointProgress": "\(waypointProgress)"
                    ]
                )
            }
        }

        djiWaypointMissionOperator.addListener(toFinished: self, with: DispatchQueue.global()) { [weak self] error in
            self?.checkMissionFinishedCurrent()
        }
    }
    
    private func checkMissionFinishedCurrent(attempt: Int = 0) {
        if attempt > 20 || state == .Deactivated {
            return
        }
        
        guard
            let flightControllerState = droneSession.flightControllerState
        else {
            _disengageReason = Kernel.Message(title: "MissionDisengageReason.execution.state.invalid.title".localized)
            return
        }
        
        switch flightControllerState.value.flightMode {
        case .gpsWaypoint:
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.checkMissionFinishedCurrent(attempt: attempt + 1)
            }
            break
            
        case .joystick, .gpsAtti:
            finishCurrentMission()
            break
            
        case .goHome, .autoLanding:
            if terminalFlightModeAllowed {
                finishCurrentMission()
            }
            break
            
        default:
            break
        }
    }
    
    public func deactivate() {
        djiWaypointMissionOperator.removeListener(self)
        //for some reason we see the flight mode go to joystick after some missions sometimes, so force it out
        switch djiWaypointMissionOperator.currentState {
        case .executing, .executionPaused:
            //TODO would be nice to be able to use pause mission
            djiWaypointMissionOperator.stopMission { [weak self] error in
                self?.droneSession.adapter.drone.flightController?.setVirtualStickModeEnabled(false, withCompletion: nil)
            }
            break
            
        default:
            droneSession.adapter.drone.flightController?.setVirtualStickModeEnabled(false, withCompletion: nil)
            break
        }
        
        if state == .Deactivated {
            return
        }
        
        state = .Deactivated
        if djiWaypointMissionOperator.currentState == .disconnected {
            if !(executionState?.status.completed ?? false) {
                droneSession.manager.add(delegate: self)
            }
        }
        
        DJISDKManager.closeConnection(whenEnteringBackground: true)
    }
    
    private func finishCurrentMission() {
        if state != .Activated {
            return
        }
        
        guard
            let executionState = executionState,
            let currentDJIWaypointMission = djiWaypointMissions[safeIndex: executionState.componentIndex],
            let currentKernelComponent = kernelComponents[safeIndex: executionState.componentIndex]
        else {
            _disengageReason = Kernel.Message(title: "MissionDisengageReason.execution.state.invalid.title".localized)
            return
        }
        
        if let loadedMission = djiWaypointMissionOperator.loadedMission, currentDJIWaypointMission.missionID == loadedMission.missionID {
            stop(cameraCaptureConfigurations: currentKernelComponent.cameraCaptureConfigurations)
            let componentIndex = executionState.componentIndex + 1
            resumeWaypointIndex = 0
            resumeWaypointProgress = 0.0
            if componentIndex == kernelComponents.count {
                updateExternalExecutionState(status: .succeeded)
            }
            else {
                djiWaypointMissionOperator.removeListener(self)
                updateExternalExecutionState(
                    values: [
                        "componentIndex": "\(componentIndex)",
                        "waypointIndex": "0",
                        "waypointProgress": "0.0"
                    ]
                )
                startCurrentMission()
            }
        }
    }
    
    private func start(cameraCaptureConfigurations: [Kernel.CameraCaptureConfiguration]?) {
        cameraCaptureConfigurations?.forEach { config in
            try? droneSession.add(command: Kernel.StopCaptureCameraCommand(channel: config.channel))
            try? droneSession.add(command: Kernel.ModeCameraCommand(channel: config.channel, mode: config.captureType.cameraMode))
            if config.captureType == .photos {
                try? droneSession.add(command: Kernel.PhotoModeCameraCommand(channel: config.channel, photoMode: .interval))
            }
            try? droneSession.add(command: Kernel.StartCaptureCameraCommand(channel: config.channel))
        }
    }
    
    private func stop(cameraCaptureConfigurations: [Kernel.CameraCaptureConfiguration]?) {
        cameraCaptureConfigurations?.forEach { config in
            try? droneSession.add(command: Kernel.StopCaptureCameraCommand(channel: config.channel))
        }
    }
    
    private func checkMissionFinishedOffline(droneSession: DroneSession, attempt: Int = 0) {
        if attempt > 20 {
            return
        }
        
        os_log(.info, log: DJIWaypointMissionSession.log, "Checking if mission finished offline (%{public}s)", "\(attempt)")
        
        guard
            let executionState = executionState,
            !executionState.status.completed,
            let currentDJIWaypointMission = djiWaypointMissions[safeIndex: executionState.componentIndex],
            let loadedMission = djiWaypointMissionOperator.loadedMission,
            currentDJIWaypointMission.missionID == loadedMission.missionID
        else {
            return
        }
        
        switch djiWaypointMissionOperator.currentState {
        case .notSupported, .uploading, .executionPaused:
            break

        case .unknown, .disconnected, .recovering:
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.checkMissionFinishedOffline(droneSession: droneSession, attempt: attempt + 1)
            }
            break

        case .executing:
            os_log(.info, log: DJIWaypointMissionSession.log, "Attempting to engage mission in progress")
            //auto re-engage the mission if it is still executing
            try? missionExecutor.engage(droneSession: droneSession) { message in
                os_log(.info, log: DJIWaypointMissionSession.log, "Mission engage failed: (%{public}s)", message.display)
            }
            break
            
        case .readyToUpload, .readyToExecute:
            let componentIndex = executionState.componentIndex + 1
            if componentIndex == kernelComponents.count {
                updateExternalExecutionState(status: .succeeded)
            }
            else {
                updateExternalExecutionState(
                    values: [
                        "componentIndex": "\(componentIndex)",
                        "waypointIndex": "0",
                        "waypointProgress": "0.0"
                    ]
                )
            }
            break

        default:
            break
        }
    }
}

extension DJIWaypointMissionSession: DroneSessionManagerDelegate {
    public func onOpened(session: DroneSession) {
        //if the current mission is still loaded
        if Dronelink.shared.missionExecutor?.id == missionExecutor.id {
            checkMissionFinishedOffline(droneSession: session)
        }
        
        DispatchQueue.global().async {
            session.manager.remove(delegate: self)
        }
    }
    
    public func onClosed(session: DroneSession) {}
}
