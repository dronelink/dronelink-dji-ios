//
//  DronelinkDJIManager.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 11/29/18.
//  Copyright © 2018 Dronelink. All rights reserved.
//

import Foundation
import os
import DronelinkCore
import DJISDK

public class DJIDroneSessionManager: NSObject {
    private static let log = OSLog(subsystem: "DronelinkDJI", category: "DJIDroneSessionManager")
    
    private let delegates = MulticastDelegate<DroneSessionManagerDelegate>()
    private var _flyZoneState: DatedValue<DJIFlyZoneState>?
    private var _appActivationState: DatedValue<DJIAppActivationState>?
    private var _session: DJIDroneSession?
    private var videoPreviewerView: UIView?
    
    public override init() {
        super.init()
        
        guard let appKey = Bundle.main.object(forInfoDictionaryKey: SDK_APP_KEY_INFO_PLIST_KEY) as? String, !appKey.isEmpty else {
            fatalError("Please enter your DJI SDK app key in the info.plist")
        }
        
        DJISDKManager.registerApp(with: self)
        DJISDKManager.flyZoneManager()?.delegate = self
        DJISDKManager.appActivationManager().delegate = self
    }
}

extension DJIDroneSessionManager: DroneSessionManager {
    
    public func add(delegate: DroneSessionManagerDelegate) {
        delegates.add(delegate)
        if let session = _session {
            delegate.onOpened(session: session)
        }
    }
    
    public func remove(delegate: DroneSessionManagerDelegate) {
        delegates.remove(delegate)
    }
    
    public func closeSession() {
        if let session = _session {
            session.close()
            _session = nil
            delegates.invoke { $0.onClosed(session: session) }
        }
    }
    
    public func startRemoteControllerLinking(finished: CommandFinished?) {
        if let remoteController = (DJISDKManager.product() as? DJIAircraft)?.remoteController(channel: 0) {
            remoteController.startPairing(completion: finished)
            return
        }
        finished?("DJIDroneSessionManager.remoteControllerLinking.unavailable".localized)
    }
    
    public func stopRemoteControllerLinking(finished: CommandFinished?) {
        if let remoteController = (DJISDKManager.product() as? DJIAircraft)?.remoteController(channel: 0) {
            remoteController.stopPairing(completion: finished)
            return
        }
        finished?("DJIDroneSessionManager.remoteControllerLinking.unavailable".localized)
    }
    
    
    public var session: DroneSession? { _session }
    
    public var statusMessages: [Kernel.Message] {
        var messages: [Kernel.Message] = []
        
        if let message = _flyZoneState?.value.message {
            messages.append(message)
        }
        
        if let message = _appActivationState?.value.message {
            messages.append(message)
        }
        
        return messages
    }
}

extension DJIDroneSessionManager: DJISDKManagerDelegate {
    public func appRegisteredWithError(_ error: Error?) {
        if let error = error {
            os_log(.error, log: DJIDroneSessionManager.log, "DJI SDK Registered with error: %{public}s", error.localizedDescription)
        }
        else {
            os_log(.info, log: DJIDroneSessionManager.log, "DJI SDK Registered successfully")
        }
        
        //DJISDKManager.enableBridgeMode(withBridgeAppIP: "")
        DJISDKManager.startConnectionToProduct()
        DJISDKManager.setLocationDesiredAccuracy(kCLLocationAccuracyNearestTenMeters)
    }
    
    public func productConnected(_ product: DJIBaseProduct?) {
        if let drone = product as? DJIAircraft {
            if let session = _session {
                if (session.adapter.drone === drone) {
                    return
                }
                closeSession()
            }
            _session = DJIDroneSession(manager: self, drone: drone)
            delegates.invoke { $0.onOpened(session: self._session!) }
        }
    }
    
    public func productDisconnected() {
        closeSession()
    }
    
    public func componentConnected(withKey key: String?, andIndex index: Int) {
        if key == DJIFlightControllerComponent, _session == nil {
            productConnected(DJISDKManager.product())
            return
        }
        _session?.componentConnected(withKey: key, andIndex: index)
    }
    
    public func componentDisconnected(withKey key: String?, andIndex index: Int) {
        if key == DJIFlightControllerComponent {
            productDisconnected()
            return
        }
        _session?.componentDisconnected(withKey: key, andIndex: index)
    }
    
    public func didUpdateDatabaseDownloadProgress(_ progress: Progress) {
    }
}

extension DJIDroneSessionManager: DJIFlyZoneDelegate {
    public func flyZoneManager(_ manager: DJIFlyZoneManager, didUpdate state: DJIFlyZoneState) {
        _flyZoneState = DatedValue<DJIFlyZoneState>(value: state)
    }
    
    public func flyZoneManager(_ manager: DJIFlyZoneManager, didUpdateBasicDatabaseUpgradeProgress progress: Float, andError error: Error?) {}
    
    public func flyZoneManager(_ manager: DJIFlyZoneManager, didUpdateFlyZoneNotification notification: DJIFlySafeNotification) {}
}

extension DJIDroneSessionManager: DJIAppActivationManagerDelegate {
    public func manager(_ manager: DJIAppActivationManager!, didUpdate appActivationState: DJIAppActivationState) {
        _appActivationState = DatedValue<DJIAppActivationState>(value: appActivationState)
    }
}
