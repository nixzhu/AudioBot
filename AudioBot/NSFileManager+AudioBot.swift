//
//  NSFileManager+AudioBot.swift
//  AudioBot
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import Foundation

extension FileManager {

    class func audiobot_cachesURL() -> URL {

        do {
            return try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

        } catch let error {
            fatalError("AudioBot: \(error)")
        }
    }

    class func audiobot_audioCachesURL() -> URL? {

        guard let audioCachesURL = audiobot_cachesURL().appendingPathComponent("audiobot_audios", isDirectory: true) else {
            return nil
        }

        let fileManager = FileManager.default

        do {
            try fileManager.createDirectory(at: audioCachesURL, withIntermediateDirectories: true, attributes: nil)
            return audioCachesURL

        } catch let error {
            print("AudioBot: \(error)")
        }

        return nil
    }

    class func audiobot_audioFileURLWithName(_ name: String) -> URL? {

        if let audioCachesURL = audiobot_audioCachesURL() {
            return audioCachesURL.appendingPathComponent("\(name).m4a")
        }

        return nil
    }

    class func audiobot_removeAudioAtFileURL(_ fileURL: URL) {

        do {
            try FileManager.default.removeItem(at: fileURL)

        } catch let error {
            print("AudioBot: \(error)")
        }
    }
}

