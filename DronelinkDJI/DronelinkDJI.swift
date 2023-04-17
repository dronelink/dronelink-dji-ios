//
//  DronelinkDJI.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/29/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import Foundation
import DronelinkCore
import DJISDK

extension DronelinkDJI {
    internal static let bundle = Bundle(for: DronelinkDJI.self)
}

public class DronelinkDJI {}

extension DJIAircraft {
    public static var maxVelocity: Double { 15.0 }
    
    public func remoteController(channel: UInt) -> DJIRemoteController? { remoteController }
    public func camera(channel: UInt) -> DJICamera? { cameras?.first { $0.index == channel } }
    public func gimbal(channel: UInt) -> DJIGimbal? { gimbals?.first { $0.index == channel } }
    
    public var multipleVideoFeedsEnabled: Bool {
        //TODO is there a better way to do this?
        switch model {
        case
//            DJIAircraftModelNameMatrice210,
//            DJIAircraftModelNameMatrice210V2,
//            DJIAircraftModelNameMatrice210RTK,
//            DJIAircraftModelNameMatrice210RTKV2,
//            DJIAircraftModelNameMatrice200,
//            DJIAircraftModelNameMatrice200V2,
            DJIAircraftModelNameMatrice300RTK:
            return true
        
        default:
            return false
        }
    }
}

extension DJIVideoFeeder {
    public func feed(channel: UInt) -> DJIVideoFeed? {
        switch channel {
        case 0: return primaryVideoFeed
        case 1: return secondaryVideoFeed
        default: return nil
        }
    }
    
    public func channel(feed: DJIVideoFeed) -> UInt? {
        if feed == primaryVideoFeed {
            return 0
        }
        
        if feed == secondaryVideoFeed {
            return 1
        }
        
        return nil
    }
}

extension DJIFlightControllerState {
    public var location: CLLocation? {
        if let location = aircraftLocation, satelliteCount > 0 {
            if abs(location.coordinate.latitude) < 0.000001 && abs(location.coordinate.longitude) < 0.000001 {
                return nil
            }
            
            return location
        }
        return nil
    }
    
    public var takeoffAltitude: Double? { takeoffLocationAltitude == 0 ? nil : Double(takeoffLocationAltitude) }
    
    public var horizontalSpeed: Double { Double(sqrt(pow(velocityX, 2) + pow(velocityY, 2))) }
    public var verticalSpeed: Double { velocityZ == 0 ? 0 : Double(-velocityZ) }
    public var course: Double { Double(atan2(velocityY, velocityX)) }
    
    public var orientation: Kernel.Orientation3 {
        Kernel.Orientation3(
            x: attitude.pitch.convertDegreesToRadians,
            y: attitude.roll.convertDegreesToRadians,
            z: attitude.yaw.convertDegreesToRadians
        )
    }
}

extension DJIGimbal {
    public var isAdjustPitchSupported: Bool {
        return (capabilities[DJIGimbalParamAdjustPitch] as? DJIParamCapability)?.isSupported ?? false
    }
    
    public var isAdjustRollSupported: Bool {
        return (capabilities[DJIGimbalParamAdjustRoll] as? DJIParamCapability)?.isSupported ?? false
    }
    
    public var isAdjustYawSupported: Bool {
        return (capabilities[DJIGimbalParamAdjustYaw] as? DJIParamCapability)?.isSupported ?? false
    }
    
    public var isAdjustYaw360Supported: Bool {
        if let capability = capabilities[DJIGimbalParamAdjustYaw] as? DJIParamCapabilityMinMax {
            return capability.isSupported && capability.min.intValue <= -180 && capability.max.intValue >= 180
        }
        return false
    }
}

extension DJIGimbalRotation {
    public static var minTime: TimeInterval { 0.1 }
}

extension Kernel.DroneConnectionFailSafeBehavior {
    var djiValue: DJIConnectionFailSafeBehavior {
        switch self {
        case .hover: return .hover
        case .returnHome: return .goHome
        case .autoLand: return .landing
        case .unknown: return .unknown
        }
    }
}

extension DJIGPSSignalLevel {
    var doubleValue: Double? {
        switch self {
        case .level0: return 0
        case .level1: return 0.2
        case .level2: return 0.4
        case .level3: return 0.6
        case .level4: return 0.8
        case .level5: return 1
        case .levelNone: return nil
        @unknown default: return nil
        }
    }
}


extension DJICameraSystemState {
    public var isBusy: Bool { isStoringPhoto || isShootingSinglePhoto || isShootingSinglePhotoInRAWFormat || isShootingIntervalPhoto || isShootingBurstPhoto || isShootingRAWBurstPhoto || isShootingShallowFocusPhoto || isShootingPanoramaPhoto || isShootingHyperanalytic }
    public var isCapturing: Bool { isRecording || isShootingSinglePhoto || isShootingSinglePhotoInRAWFormat || isShootingIntervalPhoto || isShootingBurstPhoto || isShootingRAWBurstPhoto || isShootingShallowFocusPhoto || isShootingPanoramaPhoto || isShootingHyperanalytic }
    public var isCapturingPhotoInterval: Bool { isShootingIntervalPhoto }
    public var isCapturingVideo: Bool { isRecording }
    public var isCapturingContinuous: Bool { isCapturingPhotoInterval || isCapturingVideo }
    public var currentVideoTime: Double? { isCapturingVideo ? Double(currentVideoRecordingTimeInSeconds) : nil }
}

extension DJICameraFocusStatus {
    public var isBusy: Bool {
        switch self {
        case .idle: return false
        case .focusing: return true
        case .successful: return false
        case .failed: return false
        case .unknown: return false
        @unknown default: return false
        }
    }
}

extension Kernel.CameraAEBCount {
    var djiValue: DJICameraPhotoAEBCount {
        switch self {
        case ._3: return .count3
        case ._5: return .count5
        case ._7: return .count7
        case .unknown: return .countUnknown
        }
    }
}

extension DJICameraPhotoAEBCount {
    var kernelValue: Kernel.CameraAEBCount {
        switch self {
        case .count3: return ._3
        case .count5: return ._5
        case .count7: return ._7
        case .countUnknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension DJICameraPhotoFileFormat {
    var kernelValue: Kernel.CameraPhotoFileFormat {
        switch self {
        case .RAW: return .raw
        case .JPEG: return .jpeg
        case .rawAndJPEG: return .rawAndJpeg
        case .tiff14Bit: return .tiff14bit
        case .tiff14BitLinearLowTempResolution: return .tiff14bitLinearLowTempResolution
        case .tiff14BitLinearHighTempResolution: return .tiff14bitLinearHighTempResolution
        case .radiometricJPEG: return .radiometricJpeg
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension DJICameraAperture {
    var kernelValue: Kernel.CameraAperture {
        switch self {
        case .F1: return .unknown
        case .f1Dot2: return .f1dot2
        case .f1Dot3: return .f1dot3
        case .f1Dot4: return .f1dot4
        case .f1Dot6: return .f1dot6
        case .f1Dot7: return .f1dot7
        case .f1Dot8: return .f1dot8
        case .F2: return .f2
        case .f2Dot2: return .f2dot2
        case .f2Dot4: return .f2dot4
        case .f2Dot5: return .f2dot5
        case .f2Dot6: return .f2dot6
        case .f2Dot8: return .f2dot8
        case .f3Dot2: return .f3dot2
        case .f3Dot4: return .f3dot4
        case .f3Dot5: return .f3dot5
        case .F4: return .f4
        case .f4Dot5: return .f4dot5
        case .f4Dot8: return .f4dot8
        case .F5: return .f5
        case .f5Dot6: return .f5dot6
        case .f6Dot3: return .f6dot3
        case .f6Dot8: return .f6dot8
        case .f7Dot1: return .f7dot1
        case .F8: return .f8
        case .F9: return .f9
        case .f9Dot5: return .f9dot5
        case .f9Dot6: return .f9dot6
        case .F10: return .f10
        case .F11: return .f11
        case .F13: return .f13
        case .F14: return .f14
        case .F16: return .f16
        case .F18: return .f18
        case .F19: return .f19
        case .F20: return .f20
        case .F22: return .f22
        case .F25: return .f25
        case .F28: return .f28
        case .F32: return .f32
        case .F37: return .f37
        case .F41: return .f41
        case .F45: return .f45
        case .F52: return .f52
        case .F58: return .f58
        case .F64: return .f64
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraAperture {
    var djiValue: DJICameraAperture {
        switch self {
        case .auto: return .unknown
        case .f0dot95: return .unknown
        case .f1dot0: return .F1
        case .f1dot2: return .f1Dot2
        case .f1dot3: return .f1Dot3
        case .f1dot4: return .f1Dot4
        case .f1dot6: return .f1Dot6
        case .f1dot7: return .f1Dot7
        case .f1dot8: return .f1Dot8
        case .f2: return .F2
        case .f2dot2: return .f2Dot2
        case .f2dot4: return .f2Dot4
        case .f2dot5: return .f2Dot5
        case .f2dot6: return .f2Dot6
        case .f2dot8: return .f2Dot8
        case .f3dot2: return .f3Dot2
        case .f3dot4: return .f3Dot4
        case .f3dot5: return .f3Dot5
        case .f4: return .F4
        case .f4dot4: return .unknown
        case .f4dot5: return .f4Dot5
        case .f4dot8: return .f4Dot8
        case .f5: return .F5
        case .f6: return .unknown
        case .f5dot6: return .f5Dot6
        case .f6dot3: return .f6Dot3
        case .f6dot8: return .f6Dot8
        case .f7dot1: return .f7Dot1
        case .f8: return .F8
        case .f9: return .F9
        case .f9dot5: return .f9Dot5
        case .f9dot6: return .f9Dot6
        case .f10: return .F10
        case .f11: return .F11
        case .f13: return .F13
        case .f14: return .F14
        case .f16: return .F16
        case .f18: return .F18
        case .f19: return .F19
        case .f20: return .F20
        case .f22: return .F22
        case .f25: return .F25
        case .f27: return .unknown
        case .f28: return .F28
        case .f32: return .F32
        case .f37: return .F37
        case .f41: return .F41
        case .f45: return .F45
        case .f52: return .F52
        case .f58: return .F58
        case .f64: return .F64
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraColor {
    var djiValue: DJICameraColor {
        switch self {
        case .none: return .colorNone
        case .art: return .colorArt
        case .blackAndWhite: return .colorBlackAndWhite
        case .bright: return .colorBright
        case .dCinelike: return .colorDCinelike
        case .portrait: return .colorPortrait
        case .m31: return .colorM31
        case .kDX: return .colorkDX
        case .prismo: return .colorPrismo
        case .jugo: return .colorJugo
        case .dLog: return .colorDLog
        case .trueColor: return .colorTrueColor
        case .inverse: return .colorInverse
        case .reminiscence: return .colorReminiscence
        case .solarize: return .colorSolarize
        case .posterize: return .colorPosterize
        case .whiteboard: return .colorWhiteboard
        case .blackboard: return .colorBlackboard
        case .aqua: return .colorAqua
        case .delta: return .colorDelta
        case .dk79: return .colorDK79
        case .vision4: return .colorVision4
        case .vision6: return .colorVision6
        case .trueColorExt: return .colorTrueColorExt
        case .film: return .colorUnknown
        case .filmA: return .colorFilmA
        case .filmB: return .colorFilmB
        case .filmC: return .colorFilmC
        case .filmD: return .colorFilmD
        case .filmE: return .colorFilmE
        case .filmF: return .colorFilmF
        case .filmG: return .colorFilmG
        case .filmH: return .colorFilmH
        case .filmI: return .colorFilmI
        case .hlg: return .colorHLG
        case .rec709: return .colorUnknown
        case .cinelike: return .colorUnknown
        case .unknown: return .colorUnknown
        }
    }
}

extension Kernel.CameraDisplayMode {
    var djiValue: DJICameraDisplayMode {
        switch self {
        case .visual: return .visualOnly
        case .thermal: return .thermalOnly
        case .pip: return .PIP
        case .msx: return .MSX
        case .unknown: return .unknown
        }
    }
}

extension DJICameraExposureMode {
    var kernelValue: Kernel.CameraExposureMode {
        switch self {
        case .program: return .program
        case .shutterPriority: return .shutterPriority
        case .aperturePriority: return .aperturePriority
        case .manual: return .manual
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraExposureCompensation {
    var djiValue: DJICameraExposureCompensation {
        switch self {
        case .n50: return .N50
        case .n47: return .N47
        case .n43: return .N43
        case .n40: return .N40
        case .n37: return .N37
        case .n33: return .N33
        case .n30: return .N30
        case .n27: return .N27
        case .n23: return .N23
        case .n20: return .N20
        case .n17: return .N17
        case .n13: return .N13
        case .n10: return .N10
        case .n07: return .N07
        case .n03: return .N03
        case .n00: return .N00
        case .p03: return .P03
        case .p07: return .P07
        case .p10: return .P10
        case .p13: return .P13
        case .p17: return .P17
        case .p20: return .P20
        case .p23: return .P23
        case .p27: return .P27
        case .p30: return .P30
        case .p33: return .P33
        case .p37: return .P37
        case .p40: return .P40
        case .p43: return .P43
        case .p47: return .P47
        case .p50: return .P50
        case .fixed: return .fixed
        case .unknown: return .unknown
        }
    }
}

extension DJICameraExposureCompensation {
    var kernelValue: Kernel.CameraExposureCompensation {
        switch self {
            case .N50: return .n50
            case .N47: return .n47
            case .N43: return .n43
            case .N40: return .n40
            case .N37: return .n37
            case .N33: return .n33
            case .N30: return .n30
            case .N27: return .n27
            case .N23: return .n23
            case .N20: return .n20
            case .N17: return .n17
            case .N13: return .n13
            case .N10: return .n10
            case .N07: return .n07
            case .N03: return .n03
            case .N00: return .n00
            case .P03: return .p03
            case .P07: return .p07
            case .P10: return .p10
            case .P13: return .p13
            case .P17: return .p17
            case .P20: return .p20
            case .P23: return .p23
            case .P27: return .p27
            case .P30: return .p30
            case .P33: return .p33
            case .P37: return .p37
            case .P40: return .p40
            case .P43: return .p43
            case .P47: return .p47
            case .P50: return .p50
            case .fixed: return .fixed
            case .unknown: return .unknown
            default: return .unknown
        }
    }
}

extension Kernel.CameraExposureMode {
    var djiValue: DJICameraExposureMode {
        switch self {
        case .program: return .program
        case .shutterPriority: return .shutterPriority
        case .aperturePriority: return .aperturePriority
        case .manual: return .manual
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraFileIndexMode {
    var djiValue: DJICameraFileIndexMode {
        switch self {
        case .reset: return .reset
        case .sequence: return .sequence
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraFocusMode {
    var djiValue: DJICameraFocusMode {
        switch self {
        case .manual: return .manual
        case .auto: return .auto
        case .autoContinuous: return .AFC
        case .fineTune: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension DJICameraFocusMode {
    var kernelValue: Kernel.CameraFocusMode {
        switch self {
        case .manual: return .manual
        case .auto: return .auto
        case .AFC: return .autoContinuous
        case .unknown: return .unknown
        }
    }
}

extension DJICameraISO {
    var kernelValue: Kernel.CameraISO {
        switch self {
        case .isoAuto: return .auto
        case .ISO50: return ._50
        case .ISO100: return ._100
        case .ISO200: return ._200
        case .ISO400: return ._400
        case .ISO800: return ._800
        case .ISO1600: return ._1600
        case .ISO3200: return ._3200
        case .ISO6400: return ._6400
        case .ISO12800: return ._12800
        case .ISO25600: return ._25600
        case .isoUnknown: return .unknown
        default: return .unknown
        }
    }
}

extension Kernel.CameraISO {
    var djiValue: DJICameraISO {
        switch self {
        case .auto: return .isoAuto
        case ._50: return .ISO50
        case ._100: return .ISO100
        case ._200: return .ISO200
        case ._400: return .ISO400
        case ._800: return .ISO800
        case ._1600: return .ISO1600
        case ._3200: return .ISO3200
        case ._6400: return .ISO6400
        case ._12800: return .ISO12800
        case ._25600: return .ISO25600
        case ._51200: return .isoUnknown
        case ._102400: return .isoUnknown
        case .unknown: return .isoUnknown
        }
    }
}

extension DJICameraMode {
    var kernelValue: Kernel.CameraMode {
        switch self {
        case .shootPhoto: return .photo
        case .recordVideo: return .video
        case .playback: return .playback
        case .mediaDownload: return .download
        case .broadcast: return .broadcast
        case .unknown: return .unknown
        default: return .unknown
        }
    }
}

extension Kernel.CameraMode {
    var djiValue: DJICameraMode {
        switch self {
        case .photo: return .shootPhoto
        case .video: return .recordVideo
        case .playback: return .playback
        case .download: return .mediaDownload
        case .broadcast: return .broadcast
        case .unknown: return .unknown
        }
    }
    
    var djiValueFlat: DJIFlatCameraMode {
        switch self {
        case .photo: return .photoSingle
        case .video: return .videoNormal
        case .playback: return .unknown
        case .download: return .unknown
        case .broadcast: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension DJIFlatCameraMode {
    var kernelValuePhoto: Kernel.CameraPhotoMode? {
        switch self {
        case .videoNormal: return nil
        case .photoTimeLapse: return .timeLapse
        case .photoAEB: return .aeb
        case .videoHDR: return nil
        case .photoSingle: return .single
        case .photoBurst: return .burst
        case .photoHDR: return .hdr
        case .photoInterval: return .interval
        case .photoHyperLight: return .hyperLight
        case .photoPanorama: return .panorama
        case .photoEHDR: return .ehdr
        case .photoHighResolution: return .highResolution
        case .photoSmart: return .smart
        case .slowMotion: return nil
        case .internalAISpotChecking: return .internalAISpotChecking
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraMeteringMode {
    var djiValue: DJICameraMeteringMode {
        switch self {
        case .center: return .center
        case .average: return .average
        case .spot: return .spot
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension DJICameraMeteringMode {
    var kernelValue: Kernel.CameraMeteringMode {
        switch self {
        case .center: return .center
        case .average: return .average
        case .spot: return .spot
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension DJICameraPhotoAspectRatio {
    var kernelValue: Kernel.CameraPhotoAspectRatio {
        switch self {
        case .ratio4_3: return ._4x3
        case .ratio16_9: return ._16x9
        case .ratio3_2: return ._3x2
        case .ratioUnknown: return .unknown
        }
    }
}

extension Kernel.CameraPhotoAspectRatio {
    var djiValue: DJICameraPhotoAspectRatio {
        switch self {
        case ._4x3: return .ratio4_3
        case ._16x9: return .ratio16_9
        case ._3x2: return .ratio3_2
        case ._18x9: return .ratioUnknown
        case ._5x4: return .ratioUnknown
        case ._1x1: return .ratioUnknown
        case .unknown: return .ratioUnknown
        }
    }
}

extension Kernel.CameraPhotoFileFormat {
    var djiValue: DJICameraPhotoFileFormat {
        switch self {
        case .raw: return .RAW  
        case .jpeg: return .JPEG
        case .rawAndJpeg: return .rawAndJPEG
        case .tiff8bit: return .unknown
        case .tiff14bit: return .tiff14Bit
        case .tiff14bitLinearLowTempResolution: return .tiff14BitLinearLowTempResolution
        case .tiff14bitLinearHighTempResolution: return .tiff14BitLinearHighTempResolution
        case .radiometricJpeg: return .radiometricJPEG
        case .radiometricJpegLow: return .unknown
        case .radiometricJpegHigh: return  .unknown
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraBurstCount {
    var djiValue: DJICameraPhotoBurstCount {
        switch self {
        case ._2: return .count2
        case ._3: return .count3
        case ._5: return .count5
        case ._7: return .count7
        case ._10: return .count10
        case ._14: return .count14
        case .unknown: return .countUnknown
        case .continuous: return .countContinuous
        }
    }
}

extension DJICameraPhotoBurstCount {
    var kernelValue: Kernel.CameraBurstCount {
        switch self {
        case .count2: return ._2
        case .count3: return ._3
        case .count5: return ._5
        case .count7: return ._7
        case .count10: return ._10
        case .count14: return ._14
        case .countContinuous: return .continuous
        case .countUnknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraPhotoMode {
    var djiValue: DJICameraShootPhotoMode {
        switch self {
        case .single: return .single
        case .hdr: return .HDR
        case .burst: return .burst
        case .aeb: return .AEB
        case .interval: return .interval
        case .timeLapse: return .timeLapse
        case .rawBurst: return .rawBurst
        case .shallowFocus: return .shallowFocus
        case .panorama: return .panorama
        case .ehdr: return .EHDR
        case .hyperLight: return .hyperLight
        case .highResolution: return .unknown
        case .smart: return .unknown
        case .internalAISpotChecking: return .unknown
        case .hyperLapse: return .unknown
        case .superResolution: return .unknown
        case .regionalSR: return .unknown
        case .vr: return .unknown
        case .unknown: return .unknown
        }
    }
    
    var djiValueFlat: DJIFlatCameraMode {
        switch self {
        case .single: return .photoSingle
        case .hdr: return .photoHDR
        case .burst: return .photoBurst
        case .aeb: return .photoAEB
        case .interval: return .photoInterval
        case .timeLapse: return .photoTimeLapse
        case .rawBurst: return .unknown
        case .shallowFocus: return .unknown
        case .panorama: return .photoPanorama
        case .ehdr: return .photoEHDR
        case .hyperLight: return .photoHyperLight
        case .highResolution: return .photoHighResolution
        case .smart: return .photoSmart
        case .internalAISpotChecking: return .internalAISpotChecking
        case .hyperLapse: return .unknown
        case .superResolution: return .unknown
        case .regionalSR: return .unknown
        case .vr: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension DJICameraShootPhotoMode {
    var kernelValue: Kernel.CameraPhotoMode {
        switch self {
        case .single: return .single
        case .HDR: return .hdr
        case .burst: return .burst
        case .AEB: return .aeb
        case .interval: return .interval
        case .timeLapse: return .timeLapse
        case .rawBurst: return .rawBurst
        case .shallowFocus: return .shallowFocus
        case .panorama: return .panorama
        case .cameraPanorama: return .panorama
        case .EHDR: return .ehdr
        case .hyperLight: return .hyperLight
        case .highResolution: return .highResolution
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension DJICameraVideoFileFormat {
    var kernelValue: Kernel.CameraVideoFileFormat {
        switch self {
        case .MOV: return .mov
        case .MP4: return .mp4
        case .tiffSequence: return .tiffSequence
        case .SEQ: return .seq
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension DJICameraVideoFrameRate {
    var kernelValue: Kernel.CameraVideoFrameRate {
        switch self {
        case .rate23dot976FPS: return ._23dot976
        case .rate24FPS: return ._24
        case .rate25FPS: return ._25
        case .rate29dot970FPS: return ._29dot970
        case .rate30FPS: return ._30
        case .rate47dot950FPS: return ._47dot950
        case .rate48FPS: return ._48
        case .rate50FPS: return ._50
        case .rate59dot940FPS: return ._59dot940
        case .rate60FPS: return ._60
        case .rate90FPS: return ._90
        case .rate96FPS: return ._96
        case .rate100FPS: return ._100
        case .rate120FPS: return ._120
        case .rate240FPS: return ._240
        case .rate8dot7FPS: return ._8dot7
        case .rateUnknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension DJICameraVideoResolution {
    var kernelValue: Kernel.CameraVideoResolution {
        switch self {
        case .resolution336x256: return ._336x256
        case .resolution640x360: return ._640x360
        case .resolution640x480: return ._640x480
        case .resolution640x512: return ._640x512
        case .resolution1280x720: return ._1280x720
        case .resolution1920x1080: return ._1920x1080
        case .resolution2048x1080: return ._2048x1080
        case .resolution2688x1512: return ._2688x1512
        case .resolution2704x1520: return ._2704x1520
        case .resolution2720x1530: return ._2720x1530
        case .resolution3712x2088: return ._3712x2088
        case .resolution3840x1572: return ._3840x1572
        case .resolution3840x2160: return ._3840x2160
        case .resolution3944x2088: return ._3944x2088
        case .resolution4096x2160: return ._4096x2160
        case .resolution4608x2160: return ._4608x2160
        case .resolution4608x2592: return ._4608x2592
        case .resolution5280x2160: return ._5280x2160
        case .resolution5280x2972: return ._5280x2972
        case .resolution5472x3078: return ._5472x3078
        case .resolution5760x3240: return ._5760x3240
        case .resolution6016x3200: return ._6016x3200
        case .resolution7680x4320: return ._7680x4320
        case .resolutionMax: return .max
        case .resolutionNoSSDVideo: return .noSSDVideo
        case .resolutionUnknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraVideoFieldOfView {
    var djiValue: DJICameraVideoFOV {
        switch self {
        case ._default: return .default
        case .narrow: return .narrow
        case .wide: return .wide
        case .unknown: return .unknown
        }
    }
}

extension DJICameraShutterSpeed {
    var kernelValue: Kernel.CameraShutterSpeed {
        switch self {
        case .speed1_8000 : return ._1_8000
        case .speed1_6400 : return ._1_6400
        case .speed1_6000 : return ._1_6000
        case .speed1_5000 : return ._1_5000
        case .speed1_4000 : return ._1_4000
        case .speed1_3200 : return ._1_3200
        case .speed1_3000 : return ._1_3000
        case .speed1_2500 : return ._1_2500
        case .speed1_2000 : return ._1_2000
        case .speed1_1600 : return ._1_1600
        case .speed1_1500 : return ._1_1500
        case .speed1_1250 : return ._1_1250
        case .speed1_1000 : return ._1_1000
        case .speed1_800 : return ._1_800
        case .speed1_750 : return ._1_750
        case .speed1_725 : return ._1_725
        case .speed1_640 : return ._1_640
        case .speed1_500 : return ._1_500
        case .speed1_400 : return ._1_400
        case .speed1_350 : return ._1_350
        case .speed1_320 : return ._1_320
        case .speed1_250 : return ._1_250
        case .speed1_240 : return ._1_240
        case .speed1_200 : return ._1_200
        case .speed1_180 : return ._1_180
        case .speed1_160 : return ._1_160
        case .speed1_125 : return ._1_125
        case .speed1_120 : return ._1_120
        case .speed1_100 : return ._1_100
        case .speed1_90 : return ._1_90
        case .speed1_80 : return ._1_80
        case .speed1_60 : return ._1_60
        case .speed1_50 : return ._1_50
        case .speed1_45 : return ._1_45
        case .speed1_40 : return ._1_40
        case .speed1_30 : return ._1_30
        case .speed1_25 : return ._1_25
        case .speed1_20 : return ._1_20
        case .speed1_15 : return ._1_15
        case .speed1_12Dot5 : return ._1_12dot5
        case .speed1_10 : return ._1_10
        case .speed1_8 : return ._1_8
        case .speed1_6Dot25 : return ._1_6dot25
        case .speed1_6 : return ._1_6
        case .speed1_5 : return ._1_5
        case .speed1_4 : return ._1_4
        case .speed1_3 : return ._1_3
        case .speed1_2Dot5 : return ._1_2dot5
        case .speed0Dot3 : return ._0dot3
        case .speed1_2 : return ._1_2
        case .speed1_1Dot67 : return ._1_1dot67
        case .speed1_1Dot25 : return ._1_1dot25
        case .speed0Dot7 : return ._0dot7
        case .speed1 : return ._1
        case .speed1Dot3 : return ._1dot3
        case .speed1Dot4 : return ._1dot4
        case .speed1Dot6 : return ._1dot6
        case .speed2 : return ._2
        case .speed2Dot5 : return ._2dot5
        case .speed3 : return ._3
        case .speed3Dot2 : return ._3dot2
        case .speed4 : return ._4
        case .speed5 : return ._5
        case .speed6 : return ._6
        case .speed7 : return ._7
        case .speed8 : return ._8
        case .speed9 : return ._9
        case .speed10 : return ._10
        case .speed11 : return ._11
        case .speed13 : return ._13
        case .speed15 : return ._15
        case .speed16 : return ._16
        case .speed20 : return ._20
        case .speed23 : return ._23
        case .speed25 : return ._25
        case .speed30 : return ._30
        case .speedAuto : return .auto
        default: return .unknown
        }
    }
}


extension Kernel.CameraShutterSpeed {
    var djiValue: DJICameraShutterSpeed {
        switch self {
        case .auto: return .speedAuto
        case ._1_20000: return .speedUnknown
        case ._1_16000: return .speedUnknown
        case ._1_12800: return .speedUnknown
        case ._1_10000: return .speedUnknown
        case ._1_8000: return .speed1_8000
        case ._1_6400: return .speed1_6400
        case ._1_6000: return .speed1_6000
        case ._1_5000: return .speed1_5000
        case ._1_4000: return .speed1_4000
        case ._1_3200: return .speed1_3200
        case ._1_3000: return .speed1_3000
        case ._1_2500: return .speed1_2500
        case ._1_2000: return .speed1_2000
        case ._1_1600: return .speed1_1600
        case ._1_1500: return .speed1_1500
        case ._1_1250: return .speed1_1250
        case ._1_1000: return .speed1_1000
        case ._1_800: return .speed1_800
        case ._1_750: return .speed1_750
        case ._1_725: return .speed1_725
        case ._1_640: return .speed1_640
        case ._1_500: return .speed1_500
        case ._1_400: return .speed1_400
        case ._1_350: return .speed1_350
        case ._1_320: return .speed1_320
        case ._1_250: return .speed1_250
        case ._1_240: return .speed1_240
        case ._1_200: return .speed1_200
        case ._1_180: return .speed1_180
        case ._1_160: return .speed1_160
        case ._1_125: return .speed1_125
        case ._1_120: return .speed1_120
        case ._1_100: return .speed1_100
        case ._1_90: return .speed1_90
        case ._1_80: return .speed1_80
        case ._1_60: return .speed1_60
        case ._1_50: return .speed1_50
        case ._1_45: return .speed1_45
        case ._1_40: return .speed1_40
        case ._1_30: return .speed1_30
        case ._1_25: return .speed1_25
        case ._1_20: return .speed1_20
        case ._1_15: return .speed1_15
        case ._1_12dot5: return .speed1_12Dot5
        case ._1_10: return .speed1_10
        case ._1_8: return .speed1_8
        case ._1_6dot25: return .speed1_6Dot25
        case ._1_6: return .speed1_6
        case ._1_5: return .speed1_5
        case ._1_4: return .speed1_4
        case ._1_3: return .speed1_3
        case ._1_2dot5: return .speed1_2Dot5
        case ._0dot3: return .speed0Dot3
        case ._1_2: return .speed1_2
        case ._1_1dot67: return .speed1_1Dot67
        case ._1_1dot25: return .speed1_1Dot25
        case ._0dot7: return .speed0Dot7
        case ._1: return .speed1
        case ._1dot3: return .speed1Dot3
        case ._1dot4: return .speed1Dot4
        case ._1dot6: return .speed1Dot6
        case ._2: return .speed2
        case ._2dot5: return .speed2Dot5
        case ._3: return .speed3
        case ._3dot2: return .speed3Dot2
        case ._4: return .speed4
        case ._5: return .speed5
        case ._6: return .speed6
        case ._7: return .speed7
        case ._8: return .speed8
        case ._9: return .speed9
        case ._10: return .speed10
        case ._11: return .speed11
        case ._13: return .speed13
        case ._15: return .speed15
        case ._16: return .speed16
        case ._20: return .speed20
        case ._23: return .speed23
        case ._25: return .speed25
        case ._30: return .speed30
        case ._40: return .speedUnknown
        case ._50: return .speedUnknown
        case ._60: return .speedUnknown
        case ._80: return .speedUnknown
        case ._100: return .speedUnknown
        case ._120: return .speedUnknown
        case .unknown: return .speedUnknown
        }
    }
}

extension Kernel.CameraStorageLocation {
    var djiValue: DJICameraStorageLocation {
        switch self {
        case .sdCard: return .sdCard
        case ._internal: return .internalStorage
        case .internalSSD: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension DJICameraStorageLocation {
    var kernelValue: Kernel.CameraStorageLocation {
        switch self {
        case .sdCard: return .sdCard
        case .internalStorage: return ._internal
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraVideoFileCompressionStandard {
    var djiValue: DJIVideoFileCompressionStandard {
        switch self {
        case .h264: return .H264
        case .h265: return .H265
        case .proRes: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraVideoFileFormat {
    var djiValue: DJICameraVideoFileFormat {
        switch self {
        case .mov: return .MOV
        case .mp4: return .MP4
        case .tiffSequence: return .tiffSequence
        case .seq: return .SEQ
        case .cdng: return .unknown
        case .mxf: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraVideoFrameRate {
    var djiValue: DJICameraVideoFrameRate {
        switch self {
        case ._23dot976: return .rate23dot976FPS
        case ._24: return .rate24FPS
        case ._25: return .rate25FPS
        case ._29dot970: return .rate29dot970FPS
        case ._30: return .rate30FPS
        case ._47dot950: return .rate47dot950FPS
        case ._48: return .rate48FPS
        case ._50: return .rate50FPS
        case ._59dot940: return .rate59dot940FPS
        case ._60: return .rate60FPS
        case ._90: return .rate90FPS
        case ._96: return .rate96FPS
        case ._100: return .rate100FPS
        case ._120: return .rate120FPS
        case ._240: return .rate240FPS
        case ._8dot7: return .rate8dot7FPS
        case .unknown: return .rateUnknown
        }
    }
}

extension Kernel.CameraVideoMode {
    var djiValueFlat: DJIFlatCameraMode {
        switch self {
        case .normal: return .videoNormal
        case .hdr: return .videoHDR
        case .slowMotion: return .slowMotion
        case .fastMotion: return .unknown
        case .timeLapse: return .unknown
        case .hyperLapse: return .unknown
        case .quickShot: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraVideoResolution {
    var djiValue: DJICameraVideoResolution {
        switch self {
        case ._336x256: return .resolution336x256
        case ._640x360: return .resolution640x360
        case ._640x480: return .resolution640x480
        case ._640x512: return .resolution640x512
        case ._1280x720: return .resolution1280x720
        case ._1920x1080: return .resolution1920x1080
        case ._2048x1080: return .resolution2048x1080
        case ._2688x1512: return .resolution2688x1512
        case ._2704x1520: return .resolution2704x1520
        case ._2720x1530: return .resolution2720x1530
        case ._3712x2088: return .resolution3712x2088
        case ._3840x1572: return .resolution3840x1572
        case ._3840x2160: return .resolution3840x2160
        case ._3944x2088: return .resolution3944x2088
        case ._4096x2160: return .resolution4096x2160
        case ._4608x2160: return .resolution4608x2160
        case ._4608x2592: return .resolution4608x2592
        case ._5280x2160: return .resolution5280x2160
        case ._5280x2972: return .resolution5280x2972
        case ._5472x3078: return .resolution5472x3078
        case ._5760x3240: return .resolution5760x3240
        case ._6016x3200: return .resolution6016x3200
        case ._7680x4320: return .resolution7680x4320
        case ._640x340: return .resolutionUnknown
        case ._720x576: return .resolutionUnknown
        case ._864x480: return .resolutionUnknown
        case ._1080x1920: return .resolutionUnknown
        case ._1280x1024: return .resolutionUnknown
        case ._1512x2688: return .resolutionUnknown
        case ._1920x960: return .resolutionUnknown
        case ._2688x2016: return .resolutionUnknown
        case ._2720x2040: return .resolutionUnknown
        case ._2880x1620: return .resolutionUnknown
        case ._5120x2700: return .resolutionUnknown
        case ._5120x2880: return .resolutionUnknown
        case ._5248x2952: return .resolutionUnknown
        case ._5472x3648: return .resolutionUnknown
        case ._5576x2952: return .resolutionUnknown
        case ._8192x3424: return .resolutionUnknown
        case ._8192x4320: return .resolutionUnknown
        case .max: return .resolutionMax
        case .noSSDVideo: return .resolutionNoSSDVideo
        case .unknown: return .resolutionUnknown
        }
    }
}

extension Kernel.CameraVideoStandard {
    var djiValue: DJICameraVideoStandard {
        switch self {
        case .pal: return .PAL
        case .ntsc: return .NTSC
        case .unknown: return .unknown
        }
    }
}

extension DJICameraVideoStreamSource {
    var kernelValue: Kernel.CameraVideoStreamSource {
        switch self {
        case .zoom: return .zoom
        case .wide: return .wide
        case .infraredThermal: return .thermal
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraVideoStreamSource {
    var djiValue: DJICameraVideoStreamSource {
        switch self {
        case ._default: return .wide
        case .wide: return .wide
        case .zoom: return .zoom
        case .thermal: return .infraredThermal
        case .ndvi: return .unknown
        case .visible: return .unknown
        case .msG: return .unknown
        case .msR: return .unknown
        case .msRE: return .unknown
        case .msNIR: return .unknown
        case .unknown: return .unknown
        }
    }
    
    var djiLensType: DJILensType {
        switch self {
        case ._default: return .wide
        case .wide: return .wide
        case .zoom: return .zoom
        case .thermal: return .infraredThermal
        case .ndvi: return .wide
        case .visible: return .wide
        case .msG: return .wide
        case .msR: return .wide
        case .msRE: return .wide
        case .msNIR: return .wide
        case .unknown: return .wide
        }
    }
}

extension DJICameraWhiteBalancePreset {
    var kernelValue: Kernel.CameraWhiteBalancePreset {
        switch self {
        case .auto: return .auto
        case .sunny: return .sunny
        case .cloudy: return .cloudy
        case .waterSurface: return .waterSurface
        case .indoorIncandescent: return .indoorIncandescent
        case .indoorFluorescent: return .indoorFluorescent
        case .custom: return .custom
        case .neutral: return .neutral
        case .unknown: return .unknown
        @unknown default: return .unknown
        }
    }
}

extension Kernel.CameraWhiteBalancePreset {
    var djiValue: DJICameraWhiteBalancePreset {
        switch self {
        case .auto: return .auto
        case .sunny: return .sunny
        case .cloudy: return .cloudy
        case .waterSurface: return .waterSurface
        case .indoorIncandescent: return .indoorIncandescent
        case .indoorFluorescent: return .indoorFluorescent
        case .custom: return .custom
        case .neutral: return .neutral
        case .underwater: return .unknown
        case .unknown: return .unknown
        }
    }
}

extension Kernel.DJIWaypointActionType {
    var djiValue: DJIWaypointActionType {
        switch self {
        case .stay: return .stay
        case .shootPhoto: return .shootPhoto
        case .startRecord: return .startRecord
        case .stopRecord: return .stopRecord
        case .rotateAircraft: return .rotateAircraft
        case .rotateGimbalPitch: return .rotateGimbalPitch
        }
    }
}

extension Kernel.DJIWaypointMissionComponentWaypointAction {
    var djiValue: DJIWaypointAction {
        var param = param
        switch (type) {
        case .stay, .shootPhoto, .startRecord, .stopRecord:
            break
            
        case .rotateAircraft:
            param = param.angleDifferenceSigned(angle: 0).convertRadiansToDegrees
            break
            
        case .rotateGimbalPitch:
            param = max(-90, param.convertRadiansToDegrees)
            break
        }
        return DJIWaypointAction(actionType: type.djiValue, param: Int16(param))
    }
}

extension Kernel.DJIWaypointMissionComponent {
    var djiValue: DJIMutableWaypointMission {
        let djiMission = DJIMutableWaypointMission()
        djiMission.missionID = UInt16(truncatingIfNeeded: id.hashValue)
        djiMission.autoFlightSpeed = Float(autoFlightSpeed)
        djiMission.gotoFirstWaypointMode = gotoFirstWaypointMode.djiValue
        djiMission.exitMissionOnRCSignalLost = exitMissionOnRCSignalLost
        djiMission.repeatTimes = Int32(repeatTimes)
        djiMission.maxFlightSpeed = Float(maxFlightSpeed)
        if let pointOfInterest = pointOfInterest?.coordinate {
            djiMission.pointOfInterest = pointOfInterest
        }
        djiMission.rotateGimbalPitch = rotateGimbalPitch
        djiMission.headingMode = headingMode.djiValue
        djiMission.flightPathMode = flightPathMode.djiValue
        djiMission.finishedAction = finishedAction.djiValue
        waypoints.enumerated().forEach({ index, waypoint in
            let djiWaypoint = waypoint.djiValue
            if (!(index > 0 && index < waypoints.count - 1)) {
                djiWaypoint.cornerRadiusInMeters = 0.2
            }
            djiMission.add(djiWaypoint)
        })
        return djiMission
    }
}

extension Kernel.DJIWaypointMissionComponentWaypoint {
    var djiValue: DJIWaypoint {
        let djiWaypoint = DJIWaypoint()
        djiWaypoint.coordinate = coordinate.coordinate
        djiWaypoint.altitude = Float(altitude)
        djiWaypoint.heading = Int(heading.angleDifferenceSigned(angle: 0).convertRadiansToDegrees)
        djiWaypoint.cornerRadiusInMeters = Float(cornerRadius)
        djiWaypoint.turnMode = turnMode.djiValue
        djiWaypoint.gimbalPitch = max(-90, Float(gimbalPitch.convertRadiansToDegrees))
        djiWaypoint.speed = Float(speed)
        djiWaypoint.shootPhotoTimeInterval = Float(shootPhotoTimeInterval)
        djiWaypoint.shootPhotoDistanceInterval = Float(shootPhotoDistanceInterval)
        djiWaypoint.actionRepeatTimes = UInt(actionRepeatTimes)
        djiWaypoint.actionTimeoutInSeconds = Int32(actionTimeout)
        actions.forEach { action in
            djiWaypoint.add(action.djiValue)
        }
        return djiWaypoint
    }
}

extension Kernel.DJIWaypointMissionFinishedAction {
    var djiValue: DJIWaypointMissionFinishedAction {
        switch self {
        case .noAction: return .noAction
        case .goHome: return .goHome
        case .autoLand: return .autoLand
        case .goFirstWaypoint: return .goFirstWaypoint
        case .continueUntilStop: return .continueUntilStop
        }
    }
}

extension Kernel.DJIWaypointMissionFlightPathMode {
    var djiValue: DJIWaypointMissionFlightPathMode {
        switch self {
        case .normal: return .normal
        case .curved: return .curved
        }
    }
}

extension Kernel.DJIWaypointMissionGotoWaypointMode {
    var djiValue: DJIWaypointMissionGotoWaypointMode {
        switch self {
        case .safely: return .safely
        case .pointToPoint: return .pointToPoint
        }
    }
}

extension Kernel.DJIWaypointMissionHeadingMode {
    var djiValue: DJIWaypointMissionHeadingMode {
        switch self {
        case .auto: return .auto
        case .usingInitialDirection: return .usingInitialDirection
        case .controlledByRemoteController: return .controlledByRemoteController
        case .usingWaypointHeading: return .usingWaypointHeading
        case .towardPointOfInterest: return .towardPointOfInterest
        }
    }
}

extension Kernel.DJIWaypointTurnMode {
    var djiValue: DJIWaypointTurnMode {
        switch self {
        case .clockwise: return .clockwise
        case .counterClockwise: return .counterClockwise
        }
    }
}

extension Kernel.DroneLightbridgeChannelSelectionMode {
    var djiValue: DJILightbridgeChannelSelectionMode {
        switch self {
        case .auto: return .auto
        case .manual: return .manual
        case .unknown: return .unknown
        }
    }
}

extension Kernel.DroneLightbridgeFrequencyBand {
    var djiValue: DJILightbridgeFrequencyBand {
        switch self {
        case ._2dot4ghz: return .band2Dot4GHz
        case ._5dot7ghz: return .band5Dot7GHz
        case ._5dot8ghz: return .band5Dot8GHz
        case .unknown: return .bandUnknown
        }
    }
}

extension DJILightbridgeFrequencyBand {
    var kernelValue: Kernel.DroneLightbridgeFrequencyBand {
        switch self {
        case .band2Dot4GHz: return ._2dot4ghz
        case .band5Dot7GHz: return ._5dot7ghz
        case .band5Dot8GHz: return ._5dot8ghz
        case .bandUnknown: return .unknown
        }
    }
}

extension Kernel.OcuSyncVideoFeedSourcesDroneCommand {
    public func djiValue(channel: UInt = 0) -> DJIVideoFeedPhysicalSource {
        return ocuSyncVideoFeedSources[channel]?.djiValue ?? .unknown
    }
}

extension Kernel.VideoFeedSource {
    var djiValue: DJIVideoFeedPhysicalSource {
        switch self {
        case .mainCamera: return .mainCamera
        case .fpvCamera: return .fpvCamera
        case .lb: return .LB
        case .ext: return .EXT
        case .hdmi: return .HDMI
        case .av: return .AV
        case .leftCamera: return .leftCamera
        case .rightCamera: return .rightCamera
        case .topCamera: return .topCamera
        case .unknown: return .unknown
        }
    }
}

extension Kernel.DroneOcuSyncChannelSelectionMode {
    var djiValue: DJIOcuSyncChannelSelectionMode {
        switch self {
        case .auto: return .auto
        case .manual: return .manual
        case .unknown: return .unknown
        }
    }
}

extension Kernel.DroneOcuSyncFrequencyBand {
    var djiValue: DJIOcuSyncFrequencyBand {
        switch self {
        case ._1dot4ghz: return .bandUnknown
        case ._2dot4ghz: return .band2Dot4GHz
        case ._5dot2ghz: return .bandUnknown
        case ._5dot7ghz: return .bandUnknown
        case ._5dot8ghz: return .band5Dot8GHz
        case .dual: return .bandDual
        case .unknown: return .bandUnknown
        }
    }
}

extension DJIOcuSyncFrequencyBand {
    var kernelValue: Kernel.DroneOcuSyncFrequencyBand {
        switch self {
        case .band2Dot4GHz: return ._2dot4ghz
        case .band5Dot8GHz: return ._5dot8ghz
        case .bandDual: return .dual
        case .bandUnknown: return .unknown
        }
    }
}

extension DJIGimbalMode {
    var kernelValue: Kernel.GimbalMode {
        switch self {
        case .yawFollow: return .yawFollow
        case .free: return .free
        case .FPV: return .fpv
        case .unknown: return .unknown
        default: return .unknown
        }
    }
}

extension Kernel.GimbalMode {
    var djiValue: DJIGimbalMode {
        switch self {
        case .yawFollow: return .yawFollow
        case .free: return .free
        case .fpv: return .FPV
        case .unknown: return .unknown
        }
    }
}

extension DJIVideoFeedPhysicalSource {
    public var message: Kernel.Message {
        return Kernel.Message(title: "DJIVideoFeedPhysicalSource.title".localized, details: "DJIVideoFeedPhysicalSource.value.\(rawValue)".localized)
    }
    
    public var cameraChannel: UInt? {
        switch self {
        case .mainCamera: return 0
        case .fpvCamera: return nil
        case .LB: return nil
        case .EXT: return nil
        case .HDMI: return nil
        case .AV: return nil
        case .leftCamera: return 0
        case .rightCamera: return 1
        case .topCamera: return 2
        case .unknown: return nil
        @unknown default: return nil
        }
    }
}

extension DJIDiagnosticsDeviceHealthInformationWarningLevel {
    var kernelValue: Kernel.MessageLevel {
        switch self {
        case .none: return .info
        case .notice: return .info
        case .caution: return .warning
        case .warning: return .warning
        case .seriousWarning: return .warning
        case .unknown:  return .info
        default: return .info
        }
    }
}

extension DJIFlyZoneState {
    var message: Kernel.Message? {
        var level: Kernel.MessageLevel?
        
        switch self {
        case .clear, .unknown:
            break
            
        case .nearRestrictedZone,
             .inWarningZoneWithHeightLimitation,
             .inWarningZone,
             .inRestrictedZone:
            level = .warning
            break
            
        @unknown default:
            return nil
        }
        
        return Kernel.Message(title: "DJIFlyZoneState.title".localized, details: "DJIFlyZoneState.value.\(rawValue)".localized, level: level)
    }
}

extension DJIAppActivationState {
    var message: Kernel.Message? {
        var level: Kernel.MessageLevel?
        
        switch self {
        case .activated, .unknown:
            break
            
        case .notSupported:
            level = .error
            break
            
        case .loginRequired:
            level = .warning
            break
            
        @unknown default:
            return nil
        }
        
        return Kernel.Message(title: "DJIAppActivationState.title".localized, details: "DJIAppActivationState.value.\(rawValue)".localized, level: level)
    }
}

extension DJIDiagnostics {
    var message: Kernel.Message? {
        var level: Kernel.MessageLevel?
        
        switch component {
        case .camera:
            if let code = DJIDiagnosticsErrorCamera(rawValue: code) {
                switch code {
                case .upgradeError,
                     .sensorError,
                     .overHeat,
                     .sdCardError,
                     .ssdError,
                     .internalStorageError,
                     .chipOverHeat,
                     .temperaturesTooHighToStopRecord:
                    level = .warning
                    break
                    
                case .encryptionError, //DJI Mini 2 seems to give this error incorrectly!
                     .usbConnected,
                     .noSDCard,
                     .noInternalStorage,
                     .noSSD:
                    return nil
                    
                @unknown default:
                    break
                }
            }
            break
            
        case .gimbal:
            if let code = DJIDiagnosticsErrorGimbal(rawValue: code) {
                switch code {
                case .gyroscopeError,
                     .pitchError,
                     .rollError,
                     .yawError,
                     .connectToFCError,
                     .overload,
                     .gyroscopeBroken,
                     .startupBlock,
                     .calibrateError,
                     .runCrazy,
                     .rollMechLimitError,
                     .pitchMechLimitError,
                     .sectorsJudgeError,
                     .waitRestart,
                     .motorProtected,
                     .vibrationAbnormal:
                    level = .warning
                    break
                    
                @unknown default:
                    break
                }
            }
            break
            
        case .battery:
            if let code = DJIDiagnosticsErrorBattery(rawValue: code) {
                switch code {
                case .cellBroken,
                     .illegal,
                     .notInPosition,
                     .communicationFailed,
                     .notEnough,
                     .shortcut,
                     .overload,
                     .dangerousWarningSerious,
                     .lowVoltage,
                     .dischargeOverCurrent,
                     .dischargeOverHeat,
                     .lowTemperature,
                     .lowTemperatureInAir,
                     .needStudy:
                    level = .warning
                    break
                    
                @unknown default:
                    break
                }
            }
            break
            
        case .remoteController:
            if let code = DJIDiagnosticsErrorRemoteController(rawValue: code) {
                switch code {
                case .fpgaError,
                     .transmitterError,
                     .batteryError,
                     .gpsError,
                     .encryptionError,
                     .idleTooLong,
                     .reset,
                     .overHeat,
                     .goHomeFail,
                     .batteryLow,
                     .needCalibration:
                    level = .warning
                    break
                    
                @unknown default:
                    break
                }
            }
            break
            
        case .central:
            if let code = DJIDiagnosticsErrorCentral(rawValue: code) {
                switch code {
                case .connectToBatteryError,
                     .connectToGPSError,
                     .connectToFlightControllerError,
                     .connectToRemoteControllerError,
                     .connectToCameraError,
                     .connectToGimbalError:
                    level = .warning
                    break
                    
                @unknown default:
                    break
                }
            }
            break
            
        case .video:
            if let code = DJIDiagnosticsErrorVideo(rawValue: code) {
                switch code {
                case .decoderEncryptionError,
                     .decoderConnectToDeserializerError:
                    level = .warning
                    break
                    
                @unknown default:
                    break
                }
            }
            break
            
        case .airlink:
            if let code = DJIDiagnosticsErrorAirlink(rawValue: code) {
                switch code {
                case .airlinkEncoderUpgrade,
                     .airLinkNoSignal,
                     .airLinkLowRCSignal,
                     .airLinkStrongRCRadioSignalNoise,
                     .airLinkLowRadioSignal,
                     .airLinkStrongRadioSignalNoise,
                     .airLinkWiFiMagneticInterferenceHigh,
                     .airlinkEncoderError:
                     level = .warning
                     break
                    
                @unknown default:
                    break
                }
            }
            break
            
        case .flightController:
            if let code = DJIDiagnosticsErrorFlightController(rawValue: code) {
                switch code {
                case .barometerInitFailed,
                     .barometerError,
                     .accelerometerInitFailed,
                     .gyroscopeError,
                     .attitudeError,
                     .dataRecordError,
                     .takeoffFailed,
                     .systemError,
                     .compassNeedRestart,
                     .usingWrongPropellers,
                     .mcDataError,
                     .notEnoughForce,
                     .goHomeFailed,
                     .gpsError,
                     .compassInstallError,
                     .motorStopForEscShortCircuit,
                     .aircraftPropulsionSystemError,
                     .outOfControl,
                     .barometerStuckInAir,
                     .compassAbnormal,
                     .gpsSignalBlockedByGimbal:
                    level = .error
                    break
                    
                case .strongGaleWarning,
                     .imuDataError,
                     .imuError,
                     .imuInitFailed,
                     .imuNeedCalibration,
                     .imuCalibrationIncomplete,
                     .warmingUp,
                     .mcReadingData,
                     .onlySupportAttiMode,
                     .waterSurfaceWarning,
                     .kernelBoardHighTemperature,
                     .enableNearGroundAlert,
                     .headingControlAbnormal,
                     .tiltControlAbnormal,
                     .aircraftVibrationAbnormal,
                     .paddleHasIceOnIt,
                     .motorBlocked,
                     .smartLowPowerGoHome,
                     .overHeatGoHome,
                     .outOfFlightRadiusLimit,
                     .lowVoltageGoingHome,
                     .lowVoltageLanding,
                     .outOfControlGoingHome,
                     .heightLimitReasonNoGPS,
                     .heightLimitReasonCompassInterrupt,
                     .envStateTempTooHigh,
                     .envStateTempTooLow,
                     .coverFlightEnableLimit,
                     .noRealNameHeightLimit,
                     .threePropellerEmergencyLanding,
                     .landingProtection:
                     level = .warning
                     break
                    
                @unknown default:
                    break
                }
            }
            break
            
        case .vision:
            if let code = DJIDiagnosticsErrorVision(rawValue: code) {
                switch code {
                case .visionPropellerGuard,
                     .visionSensorError,
                     .visionSensorCalibrationError,
                     .visionSensorCommunicationError,
                     .visionSystemError,
                     .visionTofSenserError,
                     .vision3DTofSenserError,
                     .visionWeakAmbientLight,
                     .visionSystemNeedCalibration:
                    level = .warning
                    break
                    
                @unknown default:
                    break
                }
            }
            break
            
        case .RTK:
            if let code = DJIDiagnosticsErrorRTK(rawValue: code) {
                switch code {
                case .positioningError,
                     .orienteeringError:
                    level = .warning
                    break
                    
                @unknown default:
                    break
                }
            }
            break
            
        case .deviceHealthInformation:
            //TODO not sure how to use healthInformation.informationId
            //level =  healthInformation.warningLevel.kernelValue
            return nil
            
        @unknown default:
            break
        }
        
        return Kernel.Message(title: reason, details: solution, level: level)
    }
}

extension DJIGoHomeExecutionState {
    var message: Kernel.Message? {
        var level: Kernel.MessageLevel?
        
        switch self {
        case .notExecuting,
             .completed,
             .unknown:
            break
            
        case .turnDirectionToHomePoint,
             .goUpToHeight,
             .autoFlyToHomePoint,
             .goDownToGround,
             .braking,
             .bypassing:
            level = .warning
            break
            
        @unknown default:
            return nil
        }
        
        return Kernel.Message(title: "DJIGoHomeExecutionState.title".localized, details: "DJIGoHomeExecutionState.value.\(rawValue)".localized, level: level)
    }
}

extension DJIWaypointMissionState {
    var message: Kernel.Message? {
        var level: Kernel.MessageLevel?
        switch self {
        case .unknown, .disconnected, .notSupported:
            return nil
            
        case .recovering:
            level = .warning
            
        case .readyToUpload:
            level = .info
            
        case .uploading:
            level = .warning
            break
            
        case .readyToExecute, .executing, .executionPaused:
            level = .info
            break
            
        @unknown default:
            return nil
        }
        
        return Kernel.Message(title: "DJIWaypointMissionState.title".localized, details: "DJIWaypointMissionState.value.\(rawValue)".localized, level: level)
    }
}

extension DJIFlightControllerState {
    var statusMessages: [Kernel.Message] {
        var messages: [Kernel.Message] = []
        
        if let goHomeExecutionStateMessage = goHomeExecutionState.message {
            if flightMode == .confirmLanding {
                //messages.append(Kernel.Message(title: flightModeString, level: .warning))
            }
            else {
                messages.append(goHomeExecutionStateMessage)
            }
        }
        //KLUGE: sometimes DJI doesn't have any goHomeExecutionState, even though the flightMode is .goHome!
        else if flightMode == .goHome {
            messages.append(Kernel.Message(title: "DJIGoHomeExecutionState.title".localized, details: "DJIGoHomeExecutionState.value.\(DJIGoHomeExecutionState.autoFlyToHomePoint.rawValue)".localized, level: .warning))
        }
        else {
            if isLowerThanSeriousBatteryWarningThreshold {
                messages.append(Kernel.Message(title: "DJIDronelink:DJIFlightControllerState.statusMessages.isLowerThanSeriousBatteryWarningThreshold.title".localized, level: .danger))
            }
            else if isLowerThanBatteryWarningThreshold {
                messages.append(Kernel.Message(title: "DJIDronelink:DJIFlightControllerState.statusMessages.isLowerThanBatteryWarningThreshold.title".localized, level: .warning))
            }
            
            if hasReachedMaxFlightRadius {
                messages.append(Kernel.Message(title: "DJIDronelink:DJIFlightControllerState.statusMessages.hasReachedMaxFlightRadius.title".localized, level: .warning))
            }
            
            if hasReachedMaxFlightHeight {
                messages.append(Kernel.Message(title: "DJIDronelink:DJIFlightControllerState.statusMessages.hasReachedMaxFlightHeight.title".localized, level: .warning))
            }
            
            if let currentState = DJISDKManager.missionControl()?.waypointMissionOperator().currentState {
                switch currentState {
                case .uploading:
                    if let message = currentState.message {
                        messages.append(message)
                    }
                    break
                    
                default:
                    break
                }
            }
            
            switch flightMode {
            case .assistedTakeoff,
                 .autoTakeoff,
                 .autoLanding,
                 .motorsJustStarted,
                 .confirmLanding:
                //messages.append(Kernel.Message(title: flightModeString, level: .warning))
                break
                
            case .gpsWaypoint:
                if let message = DJISDKManager.missionControl()?.waypointMissionOperator().currentState.message {
                    messages.append(message)
                }
                break
                
            case .manual,
                 .atti,
                 .attiCourseLock,
                 .gpsAtti,
                 .gpsCourseLock,
                 .gpsHomeLock,
                 .gpsHotPoint,
                 .gpsAttiWristband,
                 .goHome,
                 .joystick,
                 .draw,
                 .gpsFollowMe,
                 .activeTrack,
                 .tapFly,
                 .gpsSport,
                 .gpsNovice,
                 .terrainFollow,
                 .tripod,
                 .activeTrackSpotlight,
                 .unknown:
                break
                
            @unknown default:
                break
            }
        }
        
        if location == nil {
            messages.append(Kernel.Message(title: "DJIDronelink:DJIFlightControllerState.statusMessages.locationUnavailable.title".localized, details: "DJIDronelink:DJIFlightControllerState.statusMessages.locationUnavailable.details".localized, level: .danger))
        }
        
        if !isHomeLocationSet {
            messages.append(Kernel.Message(title: "DJIDronelink:DJIFlightControllerState.statusMessages.homeLocationNotSet.title".localized, level: .danger))
        }
        
        return messages
    }
}

extension DJIAirSenseSystemInformation {
    var statusMessages: [Kernel.Message] { airplaneStates.map { $0.message } }
}

extension DJIAirSenseAirplaneState {
    var message: Kernel.Message {
        var level = Kernel.MessageLevel.danger
        
        switch warningLevel {
        case .level0,
             .level1,
             .level2:
            level = .info
            break
            
        case .level3:
            level = .warning
            
        case .level4,
             .levelUnknown:
            level = .danger
            break
            
        @unknown default:
            level = .danger
            break
        }
        
        return Kernel.Message(
            title: "DJIAirSenseAirplaneState.title".localized,
            details: String(
                format: "DJIAirSenseAirplaneState.message".localized,
                Dronelink.shared.format(formatter: "distance", value: distance),
                "DJIAirSenseDirection.value.\(relativeDirection.rawValue)".localized,
                Dronelink.shared.format(formatter: "angle", value: Double(heading).convertDegreesToRadians),
                code),
            level: level)
    }
}

extension DJICompassState {
    var statusMessages: [Kernel.Message] {
        var messages: [Kernel.Message] = []
        
        if let message = state.message {
            messages.append(message)
        }
        
        return messages
    }
}

extension DJICompassSensorState {
    var message: Kernel.Message? {
        var level: Kernel.MessageLevel?
        switch self {
        case .disconnected,
             .idle,
             .superModulusSamll,
             .superModulusWeak,
             .superModulusDeviate:
            return nil

        case .calibrating,
             .inconsistentDirection,
             .dataException,
             .calibrationFailed:
            level = .warning
            break
            
        case .unknown:
            return nil
            
        @unknown default:
            return nil
        }
        
        return Kernel.Message(title: "DJICompassSensorState.title".localized, details: "DJICompassSensorState.value.\(rawValue)".localized, level: level)
    }
}

extension DJICompassCalibrationState {
    var message: Kernel.Message? {
        var level: Kernel.MessageLevel?
        switch self {
        case .notCalibrating:
            return nil
            
        case .horizontal:
            level = .warning
            break
            
        case .vertical:
            level = .warning
            break
            
        case .successful:
            level = .info
            break
            
        case .failed:
            level = .warning
            break
            
        case .unknown:
            return nil
            
        @unknown default:
            return nil
        }
        
        return Kernel.Message(title: "DJICompassCalibrationState.title".localized, details: "DJICompassCalibrationState.value.\(rawValue)".localized, level: level)
    }
}

extension DJIWaypoint {
    func distance(to: DJIWaypoint) -> Double {
        let x = coordinate.distance(to: to.coordinate)
        let y = Double(abs(altitude - to.altitude))
        return sqrt(pow(x, 2) + pow(y, 2))
    }
}
