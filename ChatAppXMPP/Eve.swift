//
//  Eve.swift
//  ChatAppXMPP
//
//  Created by caos numerico on 24/12/16.
//  Copyright © 2016 marco. All rights reserved.
//

import Foundation
import XMPPFramework

//public typealias XMPPStreamCompletionHandler = (shouldTrustPeer: Bool?) -> Void
//public typealias OneChatAuthCompletionHandler = (stream: XMPPStream, error: DDXMLElement?) -> Void
//public typealias OneChatConnectCompletionHandler = (stream: XMPPStream, error: DDXMLElement?) -> Void

public protocol EveDelegate {
    func eveStream(sender: XMPPStream?, socketDidConnect socket: GCDAsyncSocket?)
    func eveStreamDidConnect(sender: XMPPStream)
    func eveStreamDidAuthenticate(sender: XMPPStream)
    func eveStream(sender: XMPPStream, didNotAuthenticate error: DDXMLElement)
    func eveStreamDidDisconnect(sender: XMPPStream, withError error: NSError)
}

public class Eve: NSObject {
    
    var delegate: EveDelegate?
    var window: UIWindow?
    
    public var xmppStream: XMPPStream?
    var xmppReconnect: XMPPReconnect?
    var xmppRosterStorage = XMPPRosterCoreDataStorage()
    var xmppRoster: XMPPRoster?
    var xmppvCardStorage: XMPPvCardCoreDataStorage?
    var xmppvCardTempModule: XMPPvCardTempModule?
    public var xmppvCardAvatarModule: XMPPvCardAvatarModule?
    var xmppCapabilitiesStorage: XMPPCapabilitiesCoreDataStorage?
    var xmppMessageDeliveryRecipts: XMPPMessageDeliveryReceipts?
    var xmppCapabilities: XMPPCapabilities?
    //var user = XMPPUserCoreDataStorageObject()
    
    var customCertEvaluation: Bool?
    var isXmppConnected: Bool?
    let password: String="test"
    let username: String="test@192.168.168.73"
    
//    var streamDidAuthenticateCompletionBlock: OneChatAuthCompletionHandler?
//    var streamDidConnectCompletionBlock: OneChatConnectCompletionHandler?
    
    // MARK: Singleton
    
    public class var sharedInstance : Eve {
        struct EveSingleton {
            static let instance = Eve()
        }
        return EveSingleton.instance
    }
    
    // MARK: Functions
    
//    public class func stop() {
//        sharedInstance.teardownStream()
//    }
    
    public class func startEve(delegate: EveDelegate? = nil) {
        sharedInstance.setupStream()
        
            if let delegate: EveDelegate = delegate {
            sharedInstance.delegate = delegate
        }
     
    }
    
    public func setupStream() {

        xmppStream = XMPPStream()
        #if !TARGET_IPHONE_SIMULATOR
   
            xmppStream!.enableBackgroundingOnSocket = true
        #endif
        
        xmppStream?.hostName = "192.168.168.73"
        xmppStream?.hostPort = 5222
        
        
        xmppReconnect = XMPPReconnect()
        
      
        xmppRoster = XMPPRoster(rosterStorage: xmppRosterStorage)
        
        xmppRoster!.autoFetchRoster = true;
        xmppRoster!.autoAcceptKnownPresenceSubscriptionRequests = true;
        
   /*     xmppvCardStorage = XMPPvCardCoreDataStorage.sharedInstance()
        xmppvCardTempModule = XMPPvCardTempModule(vCardStorage: xmppvCardStorage)
        xmppvCardAvatarModule = XMPPvCardAvatarModule(vCardTempModule: xmppvCardTempModule)
        xmppCapabilitiesStorage = XMPPCapabilitiesCoreDataStorage.sharedInstance()
        xmppCapabilities = XMPPCapabilities(capabilitiesStorage: xmppCapabilitiesStorage)
        
        xmppCapabilities!.autoFetchHashedCapabilities = true;
        xmppCapabilities!.autoFetchNonHashedCapabilities = false;
        
     */   
        xmppMessageDeliveryRecipts = XMPPMessageDeliveryReceipts(dispatchQueue: DispatchQueue.main)
        xmppMessageDeliveryRecipts!.autoSendMessageDeliveryReceipts = true
        xmppMessageDeliveryRecipts!.autoSendMessageDeliveryRequests = true
        
        // Activate xmpp modules
        xmppReconnect!.activate(xmppStream)
        xmppRoster!.activate(xmppStream)
        /*xmppvCardTempModule!.activate(xmppStream)
        xmppvCardAvatarModule!.activate(xmppStream)
        xmppCapabilities!.activate(xmppStream)*/
        xmppMessageDeliveryRecipts!.activate(xmppStream)
        
        // Add ourself as a delegate to anything we may be interested in
        xmppStream!.addDelegate(self, delegateQueue: DispatchQueue.main)
        xmppRoster!.addDelegate(self, delegateQueue: DispatchQueue.main)
        
        Eve.sharedInstance.connect()
        
            }
    
     
    // MARK: Connect / Disconnect
    
    public func connect() {
        
         if isConnected() {
            return
         }
         
        xmppStream?.myJID = XMPPJID(string: username)
        try! xmppStream!.connect(withTimeout: XMPPStreamTimeoutNone)
         
        
        
    }
    
    public func isConnected() -> Bool {
        return xmppStream!.isConnected()
    }
    
    public func disconnect() {
        xmppStream?.disconnect()
    }
    
    // Mark: Private function
    
    private func setValue(value: String, forKey key: String) {
        if value.characters.count > 0 {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
    
    // Mark: UITableViewCell helpers
    

}

// MARK: XMPPStream Delegate
extension Eve: XMPPStreamDelegate {
    
    //optional public func xmppStream(_ sender: XMPPStream!, socketDidConnect socket: GCDAsyncSocket!)

    
    public func xmppStream(_ sender: XMPPStream?, socketDidConnect socket: GCDAsyncSocket?) {
        delegate?.eveStream(sender: sender, socketDidConnect: socket)
    }
    
    public func xmppStream(_ sender: XMPPStream?, willSecureWithSettings settings: NSMutableDictionary?) {
        let expectedCertName: String? = xmppStream?.myJID.domain
        
        if expectedCertName != nil {
            settings![kCFStreamSSLPeerName as String] = expectedCertName
        }
        if customCertEvaluation! {
            settings![GCDAsyncSocketManuallyEvaluateTrust] = true
        }
    }
    
    public func xmppStreamDidAuthenticate(_ sender: XMPPStream!){
        print("dentro")
    }
    
    public func xmppStreamDidSecure(_ sender: XMPPStream) {
        //did secure
    }
    
    public func xmppStreamDidConnect(_ sender: XMPPStream) {
        isXmppConnected = true
        print("utente")
        print(sender.myJID.domain)
        do {
            try xmppStream!.authenticate(withPassword: password)
            print(sender.isAuthenticating())
            print(sender.isAuthenticated())
        } catch _ {
            //Handle error
            print("error")
        }
    }
    
 
  }
