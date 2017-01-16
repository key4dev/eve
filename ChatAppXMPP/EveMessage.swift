//
//  EveMessage.swift
//  ChatAppXMPP
//
//  Created by caos numerico on 11/01/17.
//  Copyright © 2017 marco. All rights reserved.
//


import Foundation
import JSQMessagesViewController
import XMPPFramework

public typealias EveMessageCompletionHandler = (_ stream: XMPPStream, _ message: XMPPMessage) -> Void

// MARK: Protocols

public protocol EveMessageDelegate {
    func eveStream(sender: XMPPStream, didReceiveMessage message: XMPPMessage, from user: XMPPUserCoreDataStorageObject)
    func eveStream(sender: XMPPStream, userIsComposing user: XMPPUserCoreDataStorageObject)
}

public class EveMessage: NSObject {
    public var delegate: EveMessageDelegate?
    
    public var xmppMessageStorage: XMPPMessageArchivingCoreDataStorage?
    var xmppMessageArchiving: XMPPMessageArchiving?
    var didSendMessageCompletionBlock: EveChatMessageCompletionHandler?
    
    // MARK: Singleton
    
    public class var sharedInstance : EveMessage {
        struct EveMessageSingleton {
            static let instance = EveMessage()
        }
        
        return EveMessageSingleton.instance
    }
    
    // MARK: private methods
    
    func setupArchiving() {
        xmppMessageStorage = XMPPMessageArchivingCoreDataStorage.sharedInstance()
        xmppMessageArchiving = XMPPMessageArchiving(messageArchivingStorage: xmppMessageStorage)
        
        xmppMessageArchiving?.clientSideMessageArchivingOnly = true
        xmppMessageArchiving?.activate(Eve.sharedInstance.xmppStream)
        xmppMessageArchiving?.addDelegate(self, delegateQueue: dispatch_get_main_queue())
    }
    
    // MARK: public methods
    
    public class func sendMessage(message: String, to recipient: String, completionHandler completion:EveMessageCompletionHandler) {
        let body = DDXMLElement.elementWithName("body") as! DDXMLElement
        let messageID = Eve.sharedInstance.xmppStream?.generateUUID()
        
        body.setStringValue(message)
        
        let completeMessage = DDXMLElement.elementWithName("message") as! DDXMLElement
        
        completeMessage.addAttributeWithName("id", stringValue: messageID)
        completeMessage.addAttributeWithName("type", stringValue: "chat")
        completeMessage.addAttributeWithName("to", stringValue: recipient)
        completeMessage.addChild(body)
        
        let active = DDXMLElement.elementWithName("active", stringValue: "http://jabber.org/protocol/chatstates") as! DDXMLElement
        completeMessage.addChild(active)
        
        sharedInstance.didSendMessageCompletionBlock = completion
        Eve.sharedInstance.xmppStream?.sendElement(completeMessage)
    }
    
    public class func sendIsComposingMessage(recipient: String, completionHandler completion:EveMessageCompletionHandler) {
        if recipient.characters.count > 0 {
            let message = DDXMLElement.elementWithName("message") as! DDXMLElement
            message.addAttributeWithName("type", stringValue: "chat")
            message.addAttributeWithName("to", stringValue: recipient)
            
            let composing = DDXMLElement.elementWithName("composing", stringValue: "http://jabber.org/protocol/chatstates") as! DDXMLElement
            message.addChild(composing)
            
            sharedInstance.didSendMessageCompletionBlock = completion
            Eve.sharedInstance.xmppStream?.sendElement(message)
        }
    }
    
    public class func sendIsNotComposingMessage(recipient: String, completionHandler completion:EveMessageCompletionHandler) {
        if recipient.characters.count > 0 {
            let message = DDXMLElement.elementWithName("message") as! DDXMLElement
            message.addAttributeWithName("type", stringValue: "chat")
            message.addAttributeWithName("to", stringValue: recipient)
            
            let active = DDXMLElement.elementWithName("active", stringValue: "http://jabber.org/protocol/chatstates") as! DDXMLElement
            message.addChild(active)
            
            sharedInstance.didSendMessageCompletionBlock = completion
            Eve.sharedInstance.xmppStream?.sendElement(message)
        }
    }
    
    public func loadArchivedMessagesFrom(jid: String) -> NSMutableArray {
        let moc = xmppMessageStorage?.mainThreadManagedObjectContext
        let entityDescription = NSEntityDescription.entityForName("XMPPMessageArchiving_Message_CoreDataObject", inManagedObjectContext: moc!)
        let request = NSFetchRequest()
        let predicateFormat = "bareJidStr like %@ "
        let predicate = NSPredicate(format: predicateFormat, jid)
        let retrievedMessages = NSMutableArray()
        
        request.predicate = predicate
        request.entity = entityDescription
        
        do {
            let results = try moc?.executeFetchRequest(request)
            
            for message in results! {
                var element: DDXMLElement!
                do {
                    element = try DDXMLElement(XMLString: message.messageStr)
                } catch _ {
                    element = nil
                }
                
                let body: String
                let sender: String
                let date: NSDate
                
                date = message.timestamp
                
                if message.body() != nil {
                    body = message.body()
                } else {
                    body = ""
                }
                
                if element.attributeStringValueForName("to") == jid {
                    let displayName = Eve.sharedInstance.xmppStream?.myJID
                    sender = displayName!.bare()
                } else {
                    sender = jid
                }
                
                let fullMessage = JSQMessage(senderId: sender, senderDisplayName: sender, date: date, text: body)
                retrievedMessages.addObject(fullMessage)
            }
        } catch _ {
            //catch fetch error here
        }
        return retrievedMessages
    }
    
    public func deleteMessagesFrom(jid jid: String, messages: NSArray) {
        messages.enumerateObjectsUsingBlock { (message, idx, stop) -> Void in
            let moc = self.xmppMessageStorage?.mainThreadManagedObjectContext
            let entityDescription = NSEntityDescription.entityForName("XMPPMessageArchiving_Message_CoreDataObject", inManagedObjectContext: moc!)
            let request = NSFetchRequest()
            let predicateFormat = "messageStr like %@ "
            let predicate = NSPredicate(format: predicateFormat, message as! String)
            
            request.predicate = predicate
            request.entity = entityDescription
            
            do {
                let results = try moc?.executeFetchRequest(request)
                
                for message in results! {
                    var element: DDXMLElement!
                    do {
                        element = try DDXMLElement(XMLString: message.messageStr)
                    } catch _ {
                        element = nil
                    }
                    
                    if element.attributeStringValueForName("messageStr") == message as! String {
                        moc?.deleteObject(message as! NSManagedObject)
                    }
                }
            } catch _ {
                //catch fetch error here
            }
        }
    }
}

extension EveMessage: XMPPStreamDelegate {
    
    public func xmppStream(sender: XMPPStream, didSendMessage message: XMPPMessage) {
        EveMessage.sharedInstance.didSendMessageCompletionBlock!(stream: sender, message: message)
    }
    
    public func xmppStream(sender: XMPPStream, didReceiveMessage message: XMPPMessage) {
        let user = Eve.sharedInstance.xmppRosterStorage.userForJID(message.from(), xmppStream: Eve.sharedInstance.xmppStream, managedObjectContext: EveRoster.sharedInstance.managedObjectContext_roster())
        
 /*       if !OneChats.knownUserForJid(jidStr: user.jidStr) {
            OneChats.addUserToChatList(jidStr: user.jidStr)
        }
 */       if message.isChatMessageWithBody() {
            EveMessage.sharedInstance.delegate?.eveStream(sender, didReceiveMessage: message, from: user)
        } else {
            //was composing
            if let _ = message.elementForName("composing") {
                EveMessage.sharedInstance.delegate?.eveStream(sender, userIsComposing: user)
            }
        }
    }
}
