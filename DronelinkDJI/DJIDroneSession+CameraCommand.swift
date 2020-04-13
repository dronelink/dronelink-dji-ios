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
    func execute(cameraCommand: MissionCameraCommand, finished: @escaping CommandFinished) -> Error? {
        guard
            let camera = adapter.drone.camera(channel: cameraCommand.channel),
            let state = cameraState(channel: cameraCommand.channel)?.value as? DJICameraStateAdapter
        else {
            return "MissionDisengageReason.drone.camera.unavailable.title".localized
        }
        
        if let command = cameraCommand as? Mission.AEBCountCameraCommand {
            camera.getPhotoAEBCount { (current, error) in
                Command.conditionallyExecute(current != command.aebCount.djiValue, error: error, finished: finished) {
                    camera.setPhotoAEBCount(command.aebCount.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.ApertureCameraCommand {
            Command.conditionallyExecute(state.exposureSettings?.aperture != command.aperture.djiValue, finished: finished) {
                camera.setAperture(command.aperture.djiValue, withCompletion: finished)
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.AutoExposureLockCameraCommand {
            camera.getAELock { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    camera.setAELock(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.AutoLockGimbalCameraCommand {
            camera.getAutoLockGimbalEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    camera.setAutoLockGimbalEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.ColorCameraCommand {
            camera.getColorWithCompletion { (current, error) in
                Command.conditionallyExecute(current != command.color.djiValue, error: error, finished: finished) {
                    camera.setColor(command.color.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.ContrastCameraCommand {
            camera.getContrastWithCompletion { (current, error) in
                Command.conditionallyExecute(current != command.contrast, error: error, finished: finished) {
                    camera.setContrast(command.contrast, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.ExposureCompensationCameraCommand {
            Command.conditionallyExecute(state.exposureSettings?.exposureCompensation != command.exposureCompensation.djiValue, finished: finished) {
                camera.setExposureCompensation(command.exposureCompensation.djiValue, withCompletion: finished)
            }
            return nil
        }
        
        
        if let command = cameraCommand as? Mission.ExposureCompensationStepCameraCommand {
            let exposureCompensation = state.missionExposureCompensation.offset(steps: command.exposureCompensationSteps).djiValue
            Command.conditionallyExecute(state.exposureSettings?.exposureCompensation != exposureCompensation, finished: finished) {
                camera.setExposureCompensation(exposureCompensation, withCompletion: finished)
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.ExposureModeCameraCommand {
            camera.getExposureMode { (current, error) in
                Command.conditionallyExecute(current != command.exposureMode.djiValue, error: error, finished: finished) {
                    camera.setExposureMode(command.exposureMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.FileIndexModeCameraCommand {
            camera.getFileIndexMode { (current, error) in
                Command.conditionallyExecute(current != command.fileIndexMode.djiValue, error: error, finished: finished) {
                    camera.setFileIndexMode(command.fileIndexMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.FocusCameraCommand {
            camera.setFocusTarget(command.focusTarget.cgPoint, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.FocusModeCameraCommand {
            camera.getFocusMode { (current, error) in
                Command.conditionallyExecute(current != command.focusMode.djiValue, error: error, finished: finished) {
                    camera.setFocusMode(command.focusMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.ISOCameraCommand {
            Command.conditionallyExecute(state.exposureSettings?.ISO != command.iso.djiValue.rawValue, finished: finished) {
                camera.setISO(command.iso.djiValue, withCompletion: finished)
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.MechanicalShutterCameraCommand {
            camera.getMechanicalShutterEnabled { (current, error) in
                Command.conditionallyExecute(current != command.enabled, error: error, finished: finished) {
                    camera.setMechanicalShutterEnabled(command.enabled, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.MeteringModeCameraCommand {
            camera.getMeteringMode { (current, error) in
                Command.conditionallyExecute(current != command.meteringMode.djiValue, error: error, finished: finished) {
                    camera.setMeteringMode(command.meteringMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.ModeCameraCommand {
            Command.conditionallyExecute(command.mode != state.missionMode, finished: finished) {
                camera.setMode(command.mode.djiValue, withCompletion: finished)
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.PhotoAspectRatioCameraCommand {
            camera.getPhotoAspectRatio { (current, error) in
                Command.conditionallyExecute(current != command.photoAspectRatio.djiValue, error: error, finished: finished) {
                    camera.setPhotoAspectRatio(command.photoAspectRatio.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.PhotoFileFormatCameraCommand {
            camera.getPhotoFileFormat { (current, error) in
                Command.conditionallyExecute(current != command.photoFileFormat.djiValue, error: error, finished: finished) {
                    camera.setPhotoFileFormat(command.photoFileFormat.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.PhotoIntervalCameraCommand {
            camera.getPhotoTimeIntervalSettings { (current, error) in
                let target = DJICameraPhotoTimeIntervalSettings(captureCount: 255, timeIntervalInSeconds: UInt16(command.photoInterval))
                Command.conditionallyExecute(current.captureCount != target.captureCount || current.timeIntervalInSeconds != target.timeIntervalInSeconds, error: error, finished: finished) {
                    camera.setPhotoTimeIntervalSettings(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.PhotoModeCameraCommand {
            camera.getShootPhotoMode { (current, error) in
                Command.conditionallyExecute(current != command.photoMode.djiValue, error: error, finished: finished) {
                    camera.setShootPhotoMode(command.photoMode.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.SaturationCameraCommand {
            camera.getSaturationWithCompletion { (current, error) in
                Command.conditionallyExecute(current != command.saturation, error: error, finished: finished) {
                    camera.setSaturation(command.saturation, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.SharpnessCameraCommand {
            camera.getSharpnessWithCompletion { (current, error) in
                Command.conditionallyExecute(current != command.sharpness, error: error, finished: finished) {
                    camera.setSharpness(command.sharpness, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.ShutterSpeedCameraCommand {
            Command.conditionallyExecute(state.exposureSettings?.shutterSpeed != command.shutterSpeed.djiValue, finished: finished) {
                camera.setShutterSpeed(command.shutterSpeed.djiValue, withCompletion: finished)
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.SpotMeteringTargetCameraCommand {
            let rowIndex = UInt8(round(command.spotMeteringTarget.y * 7))
            let columnIndex = UInt8(round(command.spotMeteringTarget.x * 11))
            camera.setSpotMeteringTargetRowIndex(rowIndex, columnIndex: columnIndex, withCompletion: finished)
            return nil
        }
        
        if cameraCommand is Mission.StartCaptureCameraCommand {
            switch state.missionMode {
            case .photo:
                if state.isCapturingPhotoInterval {
                    os_log(.debug, log: log, "Camera start capture skipped, already shooting interval photos")
                    finished(nil)
                }
                else {
                    os_log(.debug, log: log, "Camera start capture photo")
                    camera.startShootPhoto { error in
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                            finished(error)
                        }
                    }
                }
                break
                
            case .video:
                if state.isCapturingVideo {
                    os_log(.debug, log: log, "Camera start capture skipped, already recording video")
                    finished(nil)
                }
                else {
                    os_log(.debug, log: log, "Camera start capture video")
                    camera.startRecordVideo { error in
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                            finished(error)
                        }
                    }
                }
                break
                
            default:
                os_log(.info, log: log, "Camera start capture invalid mode: %d", state.missionMode.djiValue.rawValue)
                return "MissionDisengageReason.drone.camera.mode.invalid.title".localized
            }
            return nil
        }
        
        if cameraCommand is Mission.StopCaptureCameraCommand {
            switch state.missionMode {
            case .photo:
                if state.isCapturingPhotoInterval {
                    os_log(.debug, log: log, "Camera stop capture interval photo")
                    camera.stopShootPhoto(completion: finished)
                }
                else {
                    os_log(.debug, log: log, "Camera stop capture skipped, not shooting interval photos")
                    finished(nil)
                }
                break
                
            case .video:
                if state.isCapturingVideo {
                    os_log(.debug, log: log, "Camera stop capture video")
                    camera.stopRecordVideo(completion: finished)
                }
                else {
                    os_log(.debug, log: log, "Camera stop capture skipped, not recording video")
                    finished(nil)
                }
                break
                
            default:
                os_log(.info, log: log, "Camera stop capture skipped, invalid mode: %d", state.missionMode.djiValue.rawValue)
                finished(nil)
                break
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.StorageLocationCameraCommand {
            camera.getStorageLocation { (current, error) in
                Command.conditionallyExecute(current != command.storageLocation.djiValue, error: error, finished: finished) {
                    camera.setStorageLocation(command.storageLocation.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.VideoFileCompressionStandardCameraCommand {
            camera.getVideoFileCompressionStandard { (current, error) in
                Command.conditionallyExecute(current != command.videoFileCompressionStandard.djiValue, error: error, finished: finished) {
                    camera.setVideoFileCompressionStandard(command.videoFileCompressionStandard.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.VideoFileFormatCameraCommand {
            camera.getVideoFileFormat { (current, error) in
                Command.conditionallyExecute(current != command.videoFileFormat.djiValue, error: error, finished: finished) {
                    camera.setVideoFileFormat(command.videoFileFormat.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.VideoResolutionFrameRateCameraCommand {
            camera.getVideoResolutionAndFrameRate { (current, error) in
                let target = DJICameraVideoResolutionAndFrameRate(resolution: command.videoResolution.djiValue, frameRate: command.videoFrameRate.djiValue, fov: command.videoFieldOfView.djiValue)
                Command.conditionallyExecute(current?.resolution != target.resolution || current?.frameRate != target.frameRate || current?.fov != target.fov, error: error, finished: finished) {
                    camera.setVideoResolutionAndFrameRate(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.VideoStandardCameraCommand {
            camera.getVideoStandard { (current, error) in
                Command.conditionallyExecute(current != command.videoStandard.djiValue, error: error, finished: finished) {
                    camera.setVideoStandard(command.videoStandard.djiValue, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.WhiteBalanceCustomCameraCommand {
            camera.getWhiteBalance { (current, error) in
                let target = DJICameraWhiteBalance(customColorTemperature: UInt8(floor(Float(command.whiteBalanceCustom) / 100)))!
                Command.conditionallyExecute(current?.preset != target.preset || current?.colorTemperature != target.colorTemperature, error: error, finished: finished) {
                    camera.setWhiteBalance(target, withCompletion: finished)
                }
            }
            return nil
        }
        
        if let command = cameraCommand as? Mission.WhiteBalancePresetCameraCommand {
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
}
