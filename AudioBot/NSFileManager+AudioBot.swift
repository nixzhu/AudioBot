//
//  NSFileManager+AudioBot.swift
//  AudioBot
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import Foundation

extension NSFileManager {

    class func audiobot_cachesURL() -> NSURL {

        do {
            return try NSFileManager.defaultManager().URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: false)

        } catch let error {
            fatalError("AudioBot: \(error)")
        }
    }

    class func audiobot_audioCachesURL() -> NSURL? {

        guard let audioCachesURL = audiobot_cachesURL().URLByAppendingPathComponent("audiobot_audios", isDirectory: true) else {
            return nil
        }

        let fileManager = NSFileManager.defaultManager()

        do {
            try fileManager.createDirectoryAtURL(audioCachesURL, withIntermediateDirectories: true, attributes: nil)
            return audioCachesURL

        } catch let error {
            print("AudioBot: \(error)")
        }

        return nil
    }

    class func audiobot_audioFileURLWithName(name: String) -> NSURL? {

        if let audioCachesURL = audiobot_audioCachesURL() {
            return audioCachesURL.URLByAppendingPathComponent("\(name).m4a")
        }

        return nil
    }

    class func audiobot_removeAudioAtFileURL(fileURL: NSURL) {

        do {
            try NSFileManager.defaultManager().removeItemAtURL(fileURL)

        } catch let error {
            print("AudioBot: \(error)")
        }
    }
}

