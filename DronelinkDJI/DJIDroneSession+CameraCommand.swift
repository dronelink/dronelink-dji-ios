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
            let state = cameraState(channel: cameraCommand.channel)?.value
        else {
            return "MissionDisengageReason.drone.camera.unavailable.title".localized
        }
        
        if let command = cameraCommand as? Mission.AEBCountCameraCommand {
            camera.setPhotoAEBCount(command.aebCount.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.ApertureCameraCommand {
            camera.setAperture(command.aperture.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.AutoExposureLockCameraCommand {
            camera.setAELock(command.enabled, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.ColorCameraCommand {
            camera.setColor(command.color.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.ContrastCameraCommand {
            camera.setContrast(command.contrast, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.ExposureCompensationCameraCommand {
            camera.setExposureCompensation(command.exposureCompensation.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.ExposureModeCameraCommand {
            camera.setExposureMode(command.exposureMode.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.FileIndexModeCameraCommand {
            camera.setFileIndexMode(command.fileIndexMode.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.FocusModeCameraCommand {
            camera.setFocusMode(command.focusMode.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.ISOCameraCommand {
            camera.setISO(command.iso.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.ModeCameraCommand {
            camera.setMode(command.mode.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.PhotoAspectRatioCameraCommand {
            camera.setPhotoAspectRatio(command.photoAspectRatio.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.PhotoFileFormatCameraCommand {
            camera.setPhotoFileFormat(command.photoFileFormat.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.PhotoIntervalCameraCommand {
            camera.setPhotoTimeIntervalSettings(DJICameraPhotoTimeIntervalSettings(captureCount: 255, timeIntervalInSeconds: UInt16(command.photoInterval)), withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.PhotoModeCameraCommand {
            camera.setShootPhotoMode(command.photoMode.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.SaturationCameraCommand {
            camera.setSaturation(command.saturation, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.SharpnessCameraCommand {
            camera.setSharpness(command.sharpness, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.ShutterSpeedCameraCommand {
            camera.setShutterSpeed(command.shutterSpeed.djiValue, withCompletion: finished)
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
            camera.setStorageLocation(command.storageLocation.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.VideoFileCompressionStandardCameraCommand {
            camera.setVideoFileCompressionStandard(command.videoFileCompressionStandard.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.VideoFileFormatCameraCommand {
            camera.setVideoFileFormat(command.videoFileFormat.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.VideoResolutionFrameRateCameraCommand {
            camera.setVideoResolutionAndFrameRate(DJICameraVideoResolutionAndFrameRate(resolution: command.videoResolution.djiValue, frameRate: command.videoFrameRate.djiValue, fov: command.videoFieldOfView.djiValue), withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.VideoStandardCameraCommand {
            camera.setVideoStandard(command.videoStandard.djiValue, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.WhiteBalanceCustomCameraCommand {
            camera.setWhiteBalance(DJICameraWhiteBalance(customColorTemperature: UInt8(floor(Float(command.whiteBalanceCustom) / 100)))!, withCompletion: finished)
            return nil
        }
        
        if let command = cameraCommand as? Mission.WhiteBalancePresetCameraCommand {
            camera.setWhiteBalance(DJICameraWhiteBalance(preset: command.whiteBalancePreset.djiValue)!, withCompletion: finished)
            return nil
        }
        
        return "MissionDisengageReason.command.type.unhandled".localized
    }
}
