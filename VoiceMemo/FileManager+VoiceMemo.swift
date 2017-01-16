//
//  FileManager+VoiceMemo.swift
//  VoiceMemo
//
//  Created by nixzhu on 2017/1/16.
//  Copyright © 2017年 nixWork. All rights reserved.
//

import Foundation

extension FileManager {

    class func voicememo_cachesURL() -> URL {
        do {
            return try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        } catch {
            fatalError("VoiceMemo: \(error)")
        }
    }

    class func voicememo_audioCachesURL() -> URL? {
        let audioCachesURL = voicememo_cachesURL().appendingPathComponent("voice_memos", isDirectory: true)
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: audioCachesURL, withIntermediateDirectories: true, attributes: nil)
            return audioCachesURL
        } catch {
            print("VoiceMemo: \(error)")
        }
        return nil
    }

    class func voicememo_audioFileURLWithName(_ name: String, _ type: String) -> URL? {
        if let audioCachesURL = voicememo_audioCachesURL() {
            return audioCachesURL.appendingPathComponent("\(name).\(type)")
        }
        return nil
    }

    class func voicememo_removeAudioAtFileURL(_ fileURL: URL) {
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("VoiceMemo: \(error)")
        }
    }
}
