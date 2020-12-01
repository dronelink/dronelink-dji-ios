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
    internal static let bundle = Bundle.init(for: DronelinkDJI.self)
}

public class DronelinkDJI {}

extension DJIBaseProduct {
    public var targetVideoFeed: DJIVideoFeed? {
        switch model {
        case DJIAircraftModelNameA3,
             DJIAircraftModelNameN3,
             DJIAircraftModelNameMatrice600,
             DJIAircraftModelNameMatrice600Pro:
            return DJISDKManager.videoFeeder()?.secondaryVideoFeed
        default:
            return DJISDKManager.videoFeeder()?.primaryVideoFeed
        }
    }
}

extension DJIAircraft {
    public static var maxVelocity: Double { 15.0 }
    
    public func camera(channel: UInt) -> DJICamera? { cameras?[safeIndex: Int(channel)] }
    public func gimbal(channel: UInt) -> DJIGimbal? { gimbals?[safeIndex: Int(channel)] }
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
    
    public var kernelOrientation: Kernel.Orientation3 {
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

extension Kernel.CameraAperture {
    var djiValue: DJICameraAperture {
        switch self {
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
        case .f4dot5: return .f4Dot5
        case .f4dot8: return .f4Dot8
        case .f5: return .F5
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
        case .unknown: return .colorUnknown
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
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraISO {
    var djiValue: DJICameraISO {
        switch self {
        case .auto: return .isoAuto
        case ._100: return .ISO100
        case ._200: return .ISO200
        case ._400: return .ISO400
        case ._800: return .ISO800
        case ._1600: return .ISO1600
        case ._3200: return .ISO3200
        case ._6400: return .ISO6400
        case ._12800: return .ISO12800
        case ._25600: return .ISO25600
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

extension Kernel.CameraMeteringMode {
    var djiValue: DJICameraMeteringMode {
        switch self {
        case .center: return .center
        case .average: return .average
        case .spot: return .spot
        case .unknown: return .unknown
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
}

extension Kernel.CameraPhotoAspectRatio {
    var djiValue: DJICameraPhotoAspectRatio {
        switch self {
        case ._4x3: return .ratio4_3
        case ._16x9: return .ratio16_9
        case ._3x2: return .ratio3_2
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
        case .tiff14bit: return .tiff14Bit
        case .radiometricJpeg: return .radiometricJPEG
        case .tiff14bitLinearLowTempResolution: return .tiff14BitLinearLowTempResolution
        case .tiff14bitLinearHighTempResolution: return .tiff14BitLinearHighTempResolution
        case .unknown: return .unknown
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
        case .unknown: return .unknown
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

extension Kernel.CameraShutterSpeed {
    var djiValue: DJICameraShutterSpeed {
        switch self {
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
        case .unknown: return .speed1Dot3
        }
    }
}

extension Kernel.CameraStorageLocation {
    var djiValue: DJICameraStorageLocation {
        switch self {
        case .sdCard: return .sdCard
        case ._internal: return .internalStorage
        case .unknown: return .unknown
        }
    }
}

extension Kernel.CameraVideoFileCompressionStandard {
    var djiValue: DJIVideoFileCompressionStandard {
        switch self {
        case .h264: return .H264
        case .h265: return .H265
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
        case ._8dot7: return .rate8dot7FPS
        case .unknown: return .rateUnknown
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
        case ._5760x3240: return .resolution5760x3240
        case ._6016x3200: return .resolution6016x3200
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
        case .unknown: return .unknown
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
        case ._2dot4ghz: return .band2Dot4GHz
        case ._5dot8ghz: return .band5Dot8GHz
        case .dual: return .bandDual
        case .unknown: return .bandUnknown
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

extension DJIDiagnosticsDeviceHealthInformationWarningLevel {
    var kernelValue: Kernel.MessageLevel {
        switch self {
        case .none: return .info
        case .notice: return .info
        case .caution: return .warning
        case .warning: return .warning
        case .seriousWarning: return .danger
        case .unknown:  return .info
        default: return .info
        }
    }
}
