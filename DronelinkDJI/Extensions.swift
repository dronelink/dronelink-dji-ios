//
//  Extensions.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 10/28/19.
//  Copyright © 2019 Dronelink. All rights reserved.
//
import Foundation
import DronelinkCore
import DJISDK

extension String {
    private static let LocalizationMissing = "MISSING STRING LOCALIZATION"
    
    var localized: String {
        let value = DronelinkDJI.bundle.localizedString(forKey: self, value: String.LocalizationMissing, table: nil)
        assert(value != String.LocalizationMissing, "String localization missing: \(self)")
        return value
    }
    
    func escapeQuotes(_ type: String = "'") -> String {
        return self.replacingOccurrences(of: type, with: "\\\(type)")
    }
}

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
        if let location = aircraftLocation, isHomeLocationSet {
            if (location.coordinate.latitude == 0 && location.coordinate.longitude == 0) {
                return nil
            }
            
            return location
        }
        return nil
    }
    
    public var horizontalSpeed: Double { Double(sqrt(pow(velocityX, 2) + pow(velocityY, 2))) }
    public var verticalSpeed: Double { velocityZ == 0 ? 0 : Double(-velocityZ) }
    public var course: Double { Double(atan2(velocityY, velocityX)) }
    
    public var missionOrientation: Mission.Orientation3 {
        Mission.Orientation3(
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

