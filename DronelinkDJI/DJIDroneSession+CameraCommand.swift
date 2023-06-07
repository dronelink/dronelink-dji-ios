//
//  DJIDroneSession+CameraCommand.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/28/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import DronelinkCore
import DJISDK
import os

extension DJIDroneSession {
    func execute(cameraCommand: KernelCameraCommand, finished: @escaping CommandFinished) -> Error? {
        guard
            let camera = adapter.drone.camera(channel: cameraCommand.channel),
            let state = cameraState(channel: cameraCommand.channel)?.value as? DJICameraStateAdapter
        else {
            return "MissionDisengageReason.drone.camera.unavailable.title".localized
        }
        
        if let command = cameraCommand as? Kernel.AEBCountCameraCommand {
            camera.getPhotoAEBCount { (current, error) in
                Command.conditionallyExecute(current != command.aebCount.djiValue, error: error, finished: finished) {
                    camera.setPhotoAEBCount(command.aebCount.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.ApertureCameraCommand {
            Command.conditionallyExecute(state.exposureSettings?.aperture != command.aperture.djiValue, finished: finished) {
                camera.setAperture(command.aperture.djiValue, withCompletion: finished)
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.AutoExposureLockCameraCommand {
            camera.getAELock { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    camera.setAELock(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.AutoLockGimbalCameraCommand {
            camera.getAutoLockGimbalEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    camera.setAutoLockGimbalEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.ColorCameraCommand {
            camera.getColorWithCompletion { (current, error) in
                Command.conditionallyExecute(current != command.color.djiValue, error: error, finished: finished) {
                    camera.setColor(command.color.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.ContrastCameraCommand {
            camera.getContrastWithCompletion { (current, error) in
                Command.conditionallyExecute(current != command.contrast, error: error, finished: finished) {
                    camera.setContrast(command.contrast, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.DisplayModeCameraCommand {
            if adapter.drone.model == DJIAircraftModelNameMavic2EnterpriseDual || camera.model == DJICameraDisplayNameXT2Thermal {
                camera.getDisplayMode { (current, error) in
                    Command.conditionallyExecute(current != command.displayMode.djiValue, error: error, finished: finished) {
                        camera.setDisplayMode(command.displayMode.djiValue, withCompletion: finished)
                    }
                }
                return nil
            }
            
            guard let lens = camera.lenses[safeIndex: command.lensIndex] else {
                return "MissionDisengageReason.drone.lens.unavailable.title".localized
            }
            
            lens.getDisplayMode { (current, error) in
                Command.conditionallyExecute(current != command.displayMode.djiValue, error: error, finished: finished) {
                    lens.setDisplayMode(command.displayMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.ExposureCompensationCameraCommand {
            Command.conditionallyExecute(state.exposureSettings?.exposureCompensation != command.exposureCompensation.djiValue, finished: finished) {
                if let lens = camera.lenses[safeIndex: Int(state.lensIndex)] {
                    lens.setExposureCompensation(command.exposureCompensation.djiValue, withCompletion: finished)
                }
                else {
                    camera.setExposureCompensation(command.exposureCompensation.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        
        if let command = cameraCommand as? Kernel.ExposureCompensationStepCameraCommand {
            let exposureCompensation = state.exposureCompensation.offset(steps: command.exposureCompensationSteps).djiValue
            Command.conditionallyExecute(state.exposureSettings?.exposureCompensation != exposureCompensation, finished: finished) {
                if let lens = camera.lenses[safeIndex: Int(state.lensIndex)] {
                    lens.setExposureCompensation(exposureCompensation, withCompletion: finished)
                }
                else {
                    camera.setExposureCompensation(exposureCompensation, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.ExposureModeCameraCommand {
            camera.getExposureMode { (current, error) in
                Command.conditionallyExecute(current != command.exposureMode.djiValue, error: error, finished: finished) {
                    camera.setExposureMode(command.exposureMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.FileIndexModeCameraCommand {
            camera.getFileIndexMode { (current, error) in
                Command.conditionallyExecute(current != command.fileIndexMode.djiValue, error: error, finished: finished) {
                    camera.setFileIndexMode(command.fileIndexMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.FocusCameraCommand {
            camera.setFocusTarget(command.focusTarget.cgPoint) { error in
                if error != nil {
                    finished(error)
                    return
                }
                
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.cameraCommandFinishFocusTargetVerifyRing(cameraCommand: command, finished: finished)
                }
            }
            
            return nil
        }
        
        if let command = cameraCommand as? Kernel.FocusDistanceCameraCommand {
            if let ringValue = Dronelink.shared.get(cameraFocusCalibration: command.focusCalibration.with(droneSerialNumber: serialNumber))?.ringValue {
                let targetFocusRingValue = UInt(ringValue)
                Command.conditionallyExecute(UInt(state.focusRingValue ?? 0) != targetFocusRingValue, finished: finished) {
                    camera.setFocusRingValue(targetFocusRingValue) { error in
                        if error != nil {
                            finished(error)
                            return
                        }
                        
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { [weak self] in
                            self?.cameraCommandFinishFocusRingVerifyValue(cameraCommand: command, targetFocusRingValue: targetFocusRingValue, finished: finished)
                        }
                    }
                }
                return nil
            }
            
            return "DJIDroneSession+CameraCommand.focus.distance.error".localized
        }
        
        if let command = cameraCommand as? Kernel.FocusModeCameraCommand {
            camera.getFocusMode { (current, error) in
                Command.conditionallyExecute(current != command.focusMode.djiValue, error: error, finished: finished) {
                    camera.setFocusMode(command.focusMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.FocusRingCameraCommand {
            let targetFocusRingValue = UInt(command.focusRingPercent * Double(state.focusRingMax ?? 0))
            Command.conditionallyExecute(UInt(state.focusRingValue ?? 0) != targetFocusRingValue, finished: finished) {
                camera.setFocusRingValue(targetFocusRingValue) { error in
                    if error != nil {
                        finished(error)
                        return
                    }
                    
                    DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.cameraCommandFinishFocusRingVerifyValue(cameraCommand: command, targetFocusRingValue: targetFocusRingValue, finished: finished)
                    }
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.ZoomCameraCommand {
            Command.conditionallyExecute(state.zoomSpec != nil, finished: finished) {
                guard let zoomSpec = state.zoomSpec else {
                    return
                }
                let zoomMax = Double(zoomSpec.max)
                let zoomMin = Double(zoomSpec.min)
                let zoomStep = Double(zoomSpec.step == 0 ? 1 : zoomSpec.step)
                camera.setHybridZoomFocalLength(UInt(round((command.zoomPercent * (zoomMax - zoomMin) + zoomMin) / zoomStep) * zoomStep), withCompletion: finished)
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.ISOCameraCommand {
            Command.conditionallyExecute(state.exposureSettings?.ISO != command.iso.djiValue.rawValue, finished: finished) {
                camera.setISO(command.iso.djiValue, withCompletion: finished)
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.MechanicalShutterCameraCommand {
            camera.getMechanicalShutterEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    camera.setMechanicalShutterEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.MeteringModeCameraCommand {
            camera.getMeteringMode { (current, error) in
                Command.conditionallyExecute(current != command.meteringMode.djiValue, error: error, finished: finished) {
                    camera.setMeteringMode(command.meteringMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.ModeCameraCommand {
            if camera.isFlatCameraModeSupported() {
                camera.getFlatMode { (current, error) in
                    Command.conditionallyExecute(current != command.mode.djiValueFlat, error: error, finished: finished) {
                        camera.setFlatMode(command.mode.djiValueFlat, withCompletion: finished)
                    }
                }
            }
            else {
                Command.conditionallyExecute(command.mode != state.mode, finished: finished) {
                    camera.setMode(command.mode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.PhotoAspectRatioCameraCommand {
            camera.getPhotoAspectRatio { (current, error) in
                Command.conditionallyExecute(current != command.photoAspectRatio.djiValue, error: error, finished: finished) {
                    camera.setPhotoAspectRatio(command.photoAspectRatio.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.PhotoFileFormatCameraCommand {
            camera.getPhotoFileFormat { (current, error) in
                Command.conditionallyExecute(current != command.photoFileFormat.djiValue, error: error, finished: finished) {
                    camera.setPhotoFileFormat(command.photoFileFormat.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.PhotoIntervalCameraCommand {
            camera.getPhotoTimeIntervalSettings { (current, error) in
                let target = DJICameraPhotoTimeIntervalSettings(captureCount: 255, timeIntervalInSeconds: UInt16(command.photoInterval))
                Command.conditionallyExecute(current.captureCount != target.captureCount || current.timeIntervalInSeconds != target.timeIntervalInSeconds, error: error, finished: finished) {
                    camera.setPhotoTimeIntervalSettings(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.PhotoModeCameraCommand {
            if camera.isFlatCameraModeSupported() {
                camera.getFlatMode { (current, error) in
                    Command.conditionallyExecute(current != command.photoMode.djiValueFlat, error: error, finished: finished) {
                        camera.setFlatMode(command.photoMode.djiValueFlat, withCompletion: finished)
                    }
                }
            }
            else {
                camera.getShootPhotoMode { (current, error) in
                    Command.conditionallyExecute(current != command.photoMode.djiValue, error: error, finished: finished) {
                        camera.setShootPhotoMode(command.photoMode.djiValue, withCompletion: finished)
                    }
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.SaturationCameraCommand {
            camera.getSaturationWithCompletion { (current, error) in
                Command.conditionallyExecute(current != command.saturation, error: error, finished: finished) {
                    camera.setSaturation(command.saturation, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.SharpnessCameraCommand {
            camera.getSharpnessWithCompletion { (current, error) in
                Command.conditionallyExecute(current != command.sharpness, error: error, finished: finished) {
                    camera.setSharpness(command.sharpness, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.ShutterSpeedCameraCommand {
            Command.conditionallyExecute(state.exposureSettings?.shutterSpeed != command.shutterSpeed.djiValue, finished: finished) {
                camera.setShutterSpeed(command.shutterSpeed.djiValue, withCompletion: finished)
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.SpotMeteringTargetCameraCommand {
            let rowIndex = UInt8(round(command.spotMeteringTarget.y * 7))
            let columnIndex = UInt8(round(command.spotMeteringTarget.x * 11))
            camera.setSpotMeteringTargetRowIndex(rowIndex, columnIndex: columnIndex, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Kernel.StartCaptureCameraCommand {
            switch state.mode {
            case .photo:
                if state.isCapturingPhotoInterval {
                    os_log(.debug, log: DJIDroneSession.log, "Camera start capture skipped, already shooting interval photos")
                    finished(nil)
                }
                else {
                    os_log(.debug, log: DJIDroneSession.log, "Camera start capture photo")
                    let started = Date()
                    camera.startShootPhoto { error in
                        if error != nil {
                            finished(error)
                            return
                        }
                        
                        //waiting since isBusy will still be false for a bit
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            if command.verifyFileCreated {
                                self?.cameraCommandFinishStartShootPhotoVerifyFile(cameraCommand: command, started: started, finished: finished)
                            }
                            else {
                                self?.cameraCommandFinishNotBusy(cameraCommand: cameraCommand, finished: finished)
                            }
                        }
                    }
                }
                break
                
            case .video:
                if state.isCapturingVideo {
                    os_log(.debug, log: DJIDroneSession.log, "Camera start capture skipped, already recording video")
                    finished(nil)
                }
                else {
                    os_log(.debug, log: DJIDroneSession.log, "Camera start capture video")
                    camera.startRecordVideo { error in
                        if error != nil {
                            finished(error)
                            return
                        }
                        
                        //waiting since isBusy will still be false for a bit
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.cameraCommandFinishNotBusy(cameraCommand: cameraCommand, finished: finished)
                        }
                    }
                }
                break
                
            default:
                os_log(.info, log: DJIDroneSession.log, "Camera start capture invalid mode: %d", state.mode.djiValue.rawValue)
                return "MissionDisengageReason.drone.camera.mode.invalid.title".localized
            }
            return nil
        }
        
        if cameraCommand is Kernel.StopCaptureCameraCommand {
            switch state.mode {
            case .photo:
                if state.isCapturingPhotoInterval {
                    os_log(.debug, log: DJIDroneSession.log, "Camera stop capture interval photo")
                    camera.stopShootPhoto { [weak self] error in
                        if error != nil {
                            finished(error)
                        }
                        
                        self?.cameraCommandFinishStopCapture(cameraCommand: cameraCommand, finished: finished)
                    }
                }
                else {
                    os_log(.debug, log: DJIDroneSession.log, "Camera stop capture skipped, not shooting interval photos")
                    finished(nil)
                }
                break
                
            case .video:
                if state.isCapturingVideo {
                    os_log(.debug, log: DJIDroneSession.log, "Camera stop capture video")
                    camera.stopRecordVideo { [weak self] error in
                        if error != nil {
                            finished(error)
                        }
                        
                        self?.cameraCommandFinishStopCapture(cameraCommand: cameraCommand, finished: finished)
                    }
                }
                else {
                    os_log(.debug, log: DJIDroneSession.log, "Camera stop capture skipped, not recording video")
                    finished(nil)
                }
                break
                
            default:
                os_log(.info, log: DJIDroneSession.log, "Camera stop capture skipped, invalid mode: %d", state.mode.djiValue.rawValue)
                finished(nil)
                break
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.StorageLocationCameraCommand {
            camera.getStorageLocation { (current, error) in
                Command.conditionallyExecute(current != command.storageLocation.djiValue, error: error, finished: finished) {
                    camera.setStorageLocation(command.storageLocation.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.VideoCaptionCameraCommand {
            camera.getVideoCaptionEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    camera.setVideoCaptionEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.VideoFileCompressionStandardCameraCommand {
            camera.getVideoFileCompressionStandard { (current, error) in
                Command.conditionallyExecute(current != command.videoFileCompressionStandard.djiValue, error: error, finished: finished) {
                    camera.setVideoFileCompressionStandard(command.videoFileCompressionStandard.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.VideoFileFormatCameraCommand {
            camera.getVideoFileFormat { (current, error) in
                Command.conditionallyExecute(current != command.videoFileFormat.djiValue, error: error, finished: finished) {
                    camera.setVideoFileFormat(command.videoFileFormat.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        
        if let command = cameraCommand as? Kernel.VideoModeCameraCommand {
            if camera.isFlatCameraModeSupported() {
                camera.getFlatMode { (current, error) in
                    Command.conditionallyExecute(current != command.videoMode.djiValueFlat, error: error, finished: finished) {
                        camera.setFlatMode(command.videoMode.djiValueFlat, withCompletion: finished)
                    }
                }
            }
            else {
                Command.conditionallyExecute(state.mode != .video, finished: finished) {
                    camera.setMode(.recordVideo, withCompletion: finished)
                }
            }
            
            return nil
        }
        
        if let command = cameraCommand as? Kernel.VideoResolutionFrameRateCameraCommand {
            camera.getVideoResolutionAndFrameRate { (current, error) in
                let target = DJICameraVideoResolutionAndFrameRate(resolution: command.videoResolution.djiValue, frameRate: command.videoFrameRate.djiValue, fov: command.videoFieldOfView.djiValue)
                Command.conditionallyExecute(current?.resolution != target.resolution || current?.frameRate != target.frameRate || current?.fov != target.fov, error: error, finished: finished) {
                    camera.setVideoResolutionAndFrameRate(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.VideoStandardCameraCommand {
            camera.getVideoStandard { (current, error) in
                Command.conditionallyExecute(current != command.videoStandard.djiValue, error: error, finished: finished) {
                    camera.setVideoStandard(command.videoStandard.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.VideoStreamSourceCameraCommand {
            camera.getVideoStreamSource { (current, error) in
                Command.conditionallyExecute(current != command.videoStreamSource.djiValue, error: error, finished: finished) {
                    camera.setCameraVideoStreamSource(command.videoStreamSource.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.WhiteBalanceCustomCameraCommand {
            camera.getWhiteBalance { (current, error) in
                let target = DJICameraWhiteBalance(customColorTemperature: UInt8(floor(Float(command.whiteBalanceCustom) / 100)))!
                Command.conditionallyExecute(current?.preset != target.preset || current?.colorTemperature != target.colorTemperature, error: error, finished: finished) {
                    camera.setWhiteBalance(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Kernel.WhiteBalancePresetCameraCommand {
            camera.getWhiteBalance { (current, error) in
                let target = DJICameraWhiteBalance(preset: command.whiteBalancePreset.djiValue)!
                Command.conditionallyExecute(current?.preset != target.preset, error: error, finished: finished) {
                    camera.setWhiteBalance(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
    
    func cameraCommandFinishStopCapture(cameraCommand: KernelCameraCommand, attempt: Int = 0, maxAttempts: Int = 20, finished: @escaping CommandFinished) {
        if attempt >= maxAttempts {
            finished("DJIDroneSession+CameraCommand.stop.capture.error".localized)
            return
        }
        
        guard let state = cameraState(channel: cameraCommand.channel)?.value as? DJICameraStateAdapter else {
            finished("MissionDisengageReason.drone.camera.unavailable.title".localized)
            return
        }
        
        if !state.isCapturing {
            finished(nil)
            return
        }
        
        let wait = 0.25
        os_log(.debug, log: DJIDroneSession.log, "Camera command finished and waiting for camera to stop capturing (%{public}ss)... (%{public}s)", String(format: "%.02f", Double(attempt + 1) * wait), cameraCommand.id)
        DispatchQueue.global().asyncAfter(deadline: .now() + wait) { [weak self] in
            self?.cameraCommandFinishStopCapture(cameraCommand: cameraCommand, attempt: attempt + 1, maxAttempts: maxAttempts, finished: finished)
        }
    }
    
    func cameraCommandFinishStartShootPhotoVerifyFile(cameraCommand: Kernel.StartCaptureCameraCommand, attempt: Int = 0, maxAttempts: Int = 20, started: Date, finished: @escaping CommandFinished) {
        if attempt >= maxAttempts {
            finished("DJIDroneSession+CameraCommand.start.shoot.photo.no.file".localized)
            return
        }
        
        if let mostRecentCameraFile = mostRecentCameraFile {
            let timeSinceMostRecentCameraFile = mostRecentCameraFile.date.timeIntervalSince(started)
            if timeSinceMostRecentCameraFile > 0 {
                os_log(.debug, log: DJIDroneSession.log, "Camera start shoot photo found camera file (%{public}s) after %{public}ss (%{public}s)", mostRecentCameraFile.value.name, String(format: "%.02f", timeSinceMostRecentCameraFile), cameraCommand.id)
                cameraCommandFinishNotBusy(cameraCommand: cameraCommand, finished: finished)
                return
            }
        }
        
        let wait = 0.25
        os_log(.debug, log: DJIDroneSession.log, "Camera start shoot photo finished and waiting for camera file (%{public}ss)... (%{public}s)", String(format: "%.02f", Double(attempt + 1) * wait), cameraCommand.id)
        DispatchQueue.global().asyncAfter(deadline: .now() + wait) { [weak self] in
            self?.cameraCommandFinishStartShootPhotoVerifyFile(cameraCommand: cameraCommand, attempt: attempt + 1, maxAttempts: maxAttempts, started: started, finished: finished)
        }
    }
    
    func cameraCommandFinishNotBusy(cameraCommand: KernelCameraCommand, attempt: Int = 0, maxAttempts: Int = 10, finished: @escaping CommandFinished) {
        guard let state = cameraState(channel: cameraCommand.channel)?.value as? DJICameraStateAdapter else {
            finished("MissionDisengageReason.drone.camera.unavailable.title".localized)
            return
        }
        
        if attempt >= maxAttempts || !state.isBusy {
            finished(nil)
            return
        }
        
        os_log(.debug, log: DJIDroneSession.log, "Camera command finished and waiting for camera to not be busy (%{public}d)... (%{public}s)", attempt, cameraCommand.id)
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.cameraCommandFinishNotBusy(cameraCommand: cameraCommand, attempt: attempt + 1, maxAttempts: maxAttempts, finished: finished)
        }
    }
    
    func cameraCommandFinishFocusTargetVerifyRing(cameraCommand: Kernel.FocusCameraCommand, attempt: Int = 0, maxAttempts: Int = 10, finished: @escaping CommandFinished) {
        guard let focusRingPercentLimits = cameraCommand.focusRingPercentLimits else {
            finished(nil)
            return
        }
        
        guard let state = cameraState(channel: cameraCommand.channel)?.value as? DJICameraStateAdapter else {
            finished("MissionDisengageReason.drone.camera.unavailable.title".localized)
            return
        }
        
        if attempt >= maxAttempts {
            finished("DJIDroneSession+CameraCommand.focus.target.error".localized)
            return
        }
        
        if !state.isBusy {
            if let focusRingValue = state.focusRingValue, let focusRingMax = state.focusRingMax, focusRingMax > 0 {
                let focusRingPercent = focusRingValue / focusRingMax
                if focusRingPercent < focusRingPercentLimits.min || focusRingPercent > focusRingPercentLimits.max {
                    finished(String(format: "DJIDroneSession+CameraCommand.focus.target.ring.invalid".localized,
                                    Dronelink.shared.format(formatter: "percent", value: focusRingPercentLimits.min),
                                    Dronelink.shared.format(formatter: "percent", value: focusRingPercent),
                                    Dronelink.shared.format(formatter: "percent", value: focusRingPercentLimits.max)))
                    return
                }
            }
            
            finished(nil)
            return
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.cameraCommandFinishFocusTargetVerifyRing(cameraCommand: cameraCommand, attempt: attempt + 1, maxAttempts: maxAttempts, finished: finished)
        }
    }
    
    func cameraCommandFinishFocusRingVerifyValue(cameraCommand: KernelCameraCommand, attempt: Int = 0, maxAttempts: Int = 10, targetFocusRingValue: UInt, finished: @escaping CommandFinished) {
        guard
            let camera = adapter.drone.camera(channel: cameraCommand.channel),
            let state = cameraState(channel: cameraCommand.channel)?.value as? DJICameraStateAdapter else {
            finished("MissionDisengageReason.drone.camera.unavailable.title".localized)
            return
        }
        
        if !state.isBusy {
            if let focusRingValue = state.focusRingValue, let focusRingMax = state.focusRingMax, focusRingMax > 0 {
                let diff = Int(targetFocusRingValue) - Int(focusRingValue)
                if diff != 0 {
                    let adjustedFocusRingValue = min(Int(targetFocusRingValue) + diff, Int(focusRingMax))
                    os_log(.debug, log: DJIDroneSession.log, "Adjusting camera focus ring value by %{public}d... (%{public}s)", diff, cameraCommand.id)
                    camera.setFocusRingValue(adjustedFocusRingValue < 0 ? 0 : UInt(adjustedFocusRingValue)) { [weak self] error in
                        if error != nil {
                            finished(error)
                            return
                        }
                        
                        self?.cameraCommandFinishNotBusy(cameraCommand: cameraCommand, finished: finished)
                    }
                    return
                }
            }
            
            finished(nil)
            return
        }
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.cameraCommandFinishFocusRingVerifyValue(cameraCommand: cameraCommand, attempt: attempt + 1, maxAttempts: maxAttempts, targetFocusRingValue: targetFocusRingValue, finished: finished)
        }
    }
}
