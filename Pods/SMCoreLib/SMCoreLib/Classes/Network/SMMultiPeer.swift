//
//  SMMultiPeer.swift
//
//  Modified from example by Ralf Ebert on 28/04/15.
//  https://www.ralfebert.de/tutorials/ios-swift-multipeer-connectivity/
//

import Foundation
import MultipeerConnectivity

public protocol SMMultiPeerDelegate : class {
    func didReceive(data:Data, fromPeer:String)
}

open class SMMultiPeer : NSObject {
    fileprivate let ServiceType = "SMMultiPeer"
    fileprivate let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    fileprivate let serviceAdvertiser : MCNearbyServiceAdvertiser
    fileprivate let serviceBrowser : MCNearbyServiceBrowser
    open weak var delegate:SMMultiPeerDelegate?
    
    public override init() {
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: self.myPeerId, discoveryInfo: nil, serviceType: self.ServiceType)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: self.myPeerId, serviceType: self.ServiceType)

        super.init()
        
        self.serviceAdvertiser.delegate = self
        self.serviceAdvertiser.startAdvertisingPeer()
        
        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
    }
    
    deinit {
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
    }
    
    open lazy var session: MCSession = {
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: MCEncryptionPreference.required)
        session.delegate = self
        return session
    }()

    // returns true iff there was no error sending.
    open func sendData(_ data:Data) -> Bool {
        var result:Bool = true
        
        if session.connectedPeers.count > 0 {
            var error : NSError?
            do {
                try self.session.send(data, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.reliable)
            } catch let error1 as NSError {
                error = error1
                Log.error("\(String(describing: error))")
                result = false
            }
        }
        else {
            result = false
        }
        
        return result
    }
    
    // returns true iff there was no error sending.
    open func sendString(_ string : String) -> Bool {
        return self.sendData(string.data(using: String.Encoding.utf8, allowLossyConversion: false)!)
    }
}

extension SMMultiPeer : MCNearbyServiceAdvertiserDelegate {
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
didReceiveInvitationFromPeer peerID: MCPeerID, 
    withContext context: Data?,
invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, self.session)
    }
}

extension SMMultiPeer : MCNearbyServiceBrowserDelegate {
    
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 10)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
}

extension MCSessionState {
    func stringValue() -> String {
        switch(self) {
        case .notConnected: return "NotConnected"
        case .connecting: return "Connecting"
        case .connected: return "Connected"
        }
    }
}

extension SMMultiPeer : MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) -> Void {
        //NSLog("%@", "peer \(peerID) didChangeState: \(state.stringValue())")
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveData: \(data.count) bytes")
        //let str = NSString(data: data, encoding: NSUTF8StringEncoding) as! String
        self.delegate?.didReceive(data: data, fromPeer: peerID.displayName)
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveStream")
    }

    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }

    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        NSLog("%@", "didStartReceivingResourceWithName")
    }
}
