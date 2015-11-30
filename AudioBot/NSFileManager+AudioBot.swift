//
//  NSFileManager+AudioBot.swift
//  VoiceMemo
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import Foundation

extension NSFileManager {

    class func audiobot_cachesURL() -> NSURL {
        return try! NSFileManager.defaultManager().URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)
    }

    class func audiobot_audioCachesURL() -> NSURL? {

        let fileManager = NSFileManager.defaultManager()

        let audioCachesURL = audiobot_cachesURL().URLByAppendingPathComponent("audiobot_audios", isDirectory: true)

        do {
            try fileManager.createDirectoryAtURL(audioCachesURL, withIntermediateDirectories: true, attributes: nil)
            return audioCachesURL
        } catch _ {
        }

        return nil
    }

    class func audiobot_audioURLWithName(name: String) -> NSURL? {

        if let audioCachesURL = audiobot_audioCachesURL() {
            return audioCachesURL.URLByAppendingPathComponent("\(name).m4a")
        }

        return nil
    }
}