//
//  AudioBot.swift
//  AudioBot
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import Foundation
import AVFoundation

public enum AudioBotError: Error {
    case invalidReportingFrequency
    case noFileURL
}

public final class VADSettings: NSObject {
    public var longestDuration: TimeInterval    = 30.0
    public var spaceDuration: TimeInterval      = 2.0
    public var silenceDuration: TimeInterval    = 0.5
    public var silenceVolume: Float             = 0.1
}

final public class AudioBot: NSObject {

    public static var mixWithOthersWhenRecording: Bool = false

    fileprivate static let sharedBot = AudioBot()

    private override init() {
        super.init()
    }

    fileprivate lazy var normalAudioRecorder: AVAudioRecorder = {
        let fileURL = FileManager.audiobot_audioFileURLWithName(UUID().uuidString, Usage.normal.type)!
        return try! AVAudioRecorder(url: fileURL, settings: Usage.normal.settings)
    }()

    fileprivate var audioRecorder: AVAudioRecorder?
    fileprivate var audioPlayer: AVAudioPlayer?

    public static var recording: Bool {
        return sharedBot.audioRecorder?.isRecording ?? false
    }

    public static var recordingFileURL: URL? {
        return sharedBot.audioRecorder?.url
    }

    public static var playing: Bool {
        return sharedBot.audioPlayer?.isPlaying ?? false
    }

    public static var playingFileURL: URL? {
        return sharedBot.audioPlayer?.url
    }

    public static var reportRecordingDuration: ((_ duration: TimeInterval) -> Void)?
    public static var reportPlayingDuration: ((_ duration: TimeInterval) -> Void)?

    fileprivate var recordingTimer: Timer?
    fileprivate var playingTimer: Timer?

    fileprivate var automaticRecordEnable = false
    
    public typealias PeriodicReport = (reportingFrequency: TimeInterval, report: (_ value: Float) -> Void)
    public typealias ResultReport = ((_ fileURL: URL, _ duration: TimeInterval, _ decibelSamples: [Float]) -> Void)

    fileprivate var recordingPeriodicReport: PeriodicReport?
    fileprivate var playingPeriodicReport: PeriodicReport?

    fileprivate var playingFinish: ((Bool) -> Void)?

    fileprivate var decibelSamples: [Float] = []

    fileprivate func clearForRecording() {
        AudioBot.reportRecordingDuration = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingPeriodicReport = nil
        decibelSamples = []
    }

    fileprivate func clearForPlaying(finish: Bool) {
        AudioBot.reportPlayingDuration = nil
        playingTimer?.invalidate()
        playingTimer = nil
        if finish {
            playingPeriodicReport?.report(0)
        }
        playingPeriodicReport = nil
    }

    fileprivate func deactiveAudioSessionAndNotifyOthers() {
        if automaticRecordEnable { return }
        _ = try? AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
    }
}

// MARK: - Record

extension AudioBot {

    public class func prepareForNormalRecord() {
        DispatchQueue.global(qos: .utility).async {
            sharedBot.normalAudioRecorder.prepareToRecord()
        }
    }

    public enum Usage {
        case normal
        case custom(fileURL: URL?, type: String, settings: [String: AnyObject])

        public static let m4aSettings: [String: AnyObject] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC) as AnyObject,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue as AnyObject,
            AVEncoderBitRateKey: 64000 as AnyObject,
            AVNumberOfChannelsKey: 2 as AnyObject,
            AVSampleRateKey: 44100.0 as AnyObject
        ]

        public static let wavSettings: [String: AnyObject] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM) as AnyObject,
            AVEncoderAudioQualityKey : AVAudioQuality.medium.rawValue as AnyObject,
            AVEncoderBitRateKey : 64000 as AnyObject,
            AVNumberOfChannelsKey: 2 as AnyObject,
            AVSampleRateKey : 44100.0 as AnyObject
        ]

        var settings: [String: AnyObject] {
            switch self {
            case .normal:
                return Usage.m4aSettings
            case .custom(_, _, let settings):
                return settings
            }
        }
        
        var fileURL: URL? {
            switch self {
            case .normal:
                return nil
            case .custom(let fileURL, _, _):
                return fileURL
            }
        }
        
        var type: String {
            switch self {
            case .normal:
                return "m4a"
            case .custom(_, let type, _):
                return type
            }
        }
    }

    public class func startRecordAudio(forUsage usage: Usage, withDecibelSamplePeriodicReport decibelSamplePeriodicReport: PeriodicReport) throws {
        do {
            let session = AVAudioSession.sharedInstance()
            if mixWithOthersWhenRecording {
                let categoryOptions: AVAudioSessionCategoryOptions = [.mixWithOthers, .defaultToSpeaker]
                if session.category != AVAudioSessionCategoryPlayAndRecord || session.categoryOptions != categoryOptions {
                    try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: categoryOptions)
                }
            } else {
                if session.category != AVAudioSessionCategoryRecord {
                    try session.setCategory(AVAudioSessionCategoryRecord)
                }
            }
            try session.setActive(true)
        } catch {
            throw error
        }
        if let audioRecorder = sharedBot.audioRecorder, audioRecorder.isRecording {
            audioRecorder.stop()
            audioRecorder.deleteRecording()
        }
        guard decibelSamplePeriodicReport.reportingFrequency > 0 else {
            throw AudioBotError.invalidReportingFrequency
        }
        do {
            let audioRecorder: AVAudioRecorder
            switch usage {
            case .normal:
                audioRecorder = sharedBot.normalAudioRecorder
            case .custom(let fileURL, let type, let settings):
                guard let fileURL = (fileURL ?? FileManager.audiobot_audioFileURLWithName(UUID().uuidString, type)) else {
                    throw AudioBotError.noFileURL
                }
                audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            }
            sharedBot.audioRecorder = audioRecorder
            audioRecorder.delegate = sharedBot
            audioRecorder.isMeteringEnabled = true
        } catch {
            throw error
        }
        sharedBot.audioRecorder?.record()
        sharedBot.recordingPeriodicReport = decibelSamplePeriodicReport
        let timeInterval = 1 / decibelSamplePeriodicReport.reportingFrequency
        DispatchQueue.main.async {
            let timer = Timer.scheduledTimer(timeInterval: timeInterval, target: sharedBot, selector: #selector(AudioBot.reportRecordingDecibel(_:)), userInfo: nil, repeats: true)
            sharedBot.recordingTimer?.invalidate()
            sharedBot.recordingTimer = timer
        }
    }

    @objc fileprivate func reportRecordingDecibel(_ sender: Timer) {
        guard let audioRecorder = audioRecorder else {
            return
        }
        audioRecorder.updateMeters()
        let normalizedDecibel = pow(10, audioRecorder.averagePower(forChannel: 0) * 0.05)
        recordingPeriodicReport?.report(normalizedDecibel)
        decibelSamples.append(normalizedDecibel)
        AudioBot.reportRecordingDuration?(audioRecorder.currentTime)
    }

    public class func stopRecord(_ finish: ResultReport?) {
        defer {
            sharedBot.clearForRecording()
        }
        guard let audioRecorder = sharedBot.audioRecorder, audioRecorder.isRecording else {
            return
        }
        let duration = audioRecorder.currentTime
        audioRecorder.stop()
        finish?(audioRecorder.url, duration, sharedBot.decibelSamples)
    }

    public class func removeAudioAtFileURL(_ fileURL: URL) {
        FileManager.audiobot_removeAudioAtFileURL(fileURL)
    }

    public class func compressDecibelSamples(_ decibelSamples: [Float], withSamplingInterval samplingInterval: Int, minNumberOfDecibelSamples: Int, maxNumberOfDecibelSamples: Int) -> [Float] {
        guard samplingInterval > 0 else {
            fatalError("Invlid samplingInterval!")
        }
        guard minNumberOfDecibelSamples > 0 else {
            fatalError("Invlid minNumberOfDecibelSamples!")
        }
        guard maxNumberOfDecibelSamples >= minNumberOfDecibelSamples else {
            fatalError("Invlid maxNumberOfDecibelSamples!")
        }
        guard decibelSamples.count >= minNumberOfDecibelSamples else {
            print("Warning: Insufficient number of decibelSamples!")
            return decibelSamples
        }
        func f(_ x: Int, max: Int) -> Int {
            let n = 1 - 1 / exp(Double(x) / 100)
            return Int(Double(max) * n)
        }
        let realSamplingInterval = min(samplingInterval, decibelSamples.count / minNumberOfDecibelSamples)
        var samples: [Float] = []
        var i = 0
        while i < decibelSamples.count {
            samples.append(decibelSamples[i])
            i += realSamplingInterval
        }
        let finalNumber = f(samples.count, max: maxNumberOfDecibelSamples)
        func averageSamplingFrom(_ values: [Float], withCount count: Int) -> [Float] {
            let step = Double(values.count) / Double(count)
            var outputValues = [Float]()
            var x: Double = 0
            for _ in 0..<count {
                let index = Int(x)
                if index < values.count {
                    let value = values[index]
                    let fixedValue = Float(Int(value * 100)) / 100 // 最多两位小数
                    outputValues.append(fixedValue)
                } else {
                    break
                }
                x += step
            }
            return outputValues
        }
        let compressedDecibelSamples = averageSamplingFrom(samples, withCount: finalNumber)
        return compressedDecibelSamples
    }
}

// MARK: - AutomaticRecord

extension AudioBot {

    public class func startAutomaticRecordAudio(forUsage usage: Usage, withVADSettings vadSettings: VADSettings, decibelSamplePeriodicReport: PeriodicReport, recordResultReport: @escaping ResultReport) throws {
        do {
            sharedBot.automaticRecordEnable = true
            let settings = usage.settings
            let type = usage.type
            guard let fileURL = (usage.fileURL ?? FileManager.audiobot_audioFileURLWithName(UUID().uuidString, type)) else {
                throw AudioBotError.noFileURL
            }
            let newUsage = AudioBot.Usage.custom(fileURL: fileURL, type: type, settings: settings)
            var isValid = false
            var count = 0
            let activeCount = Int(decibelSamplePeriodicReport.reportingFrequency * vadSettings.silenceDuration)
            func retry() {
                guard sharedBot.automaticRecordEnable else { return }
                try! startAutomaticRecordAudio(forUsage: usage, withVADSettings: vadSettings, decibelSamplePeriodicReport: decibelSamplePeriodicReport, recordResultReport: recordResultReport)
            }
            let decibelPeriodicReport: AudioBot.PeriodicReport = (reportingFrequency: decibelSamplePeriodicReport.reportingFrequency, report: { decibelSample in
                decibelSamplePeriodicReport.report(decibelSample)
                if decibelSample > vadSettings.silenceVolume {
                    isValid = true
                    count = 0
                } else if isValid {
                    count += 1
                }
                if count > activeCount, isValid {
                    stopRecord({ (fileURL, duration, decibelSamples) in
                        recordResultReport(fileURL, duration, decibelSamples)
                    })
                    retry()
                }
            })
            try startRecordAudio(forUsage: newUsage, withDecibelSamplePeriodicReport: decibelPeriodicReport)
            DispatchQueue.main.asyncAfter(deadline: .now() + vadSettings.spaceDuration) {
                if !isValid {
                    stopRecord(nil)
                    retry()
                }
            }
        } catch {
            throw error
        }
    }
    
    public class func stopAutomaticRecord() {
        stopRecord(nil)
        sharedBot.automaticRecordEnable = false
    }
}

// MARK: - Playback

extension AudioBot {

    public class func startPlayAudioAtFileURL(_ fileURL: URL, fromTime: TimeInterval, withProgressPeriodicReport progressPeriodicReport: PeriodicReport, finish: @escaping (Bool) -> Void) throws {
        let session = AVAudioSession.sharedInstance()
        if !session.audiobot_canPlay {
            do {
                try session.setCategory(AVAudioSessionCategoryPlayback)
                try session.setActive(true)
            } catch let error {
                throw error
            }
        }
        guard progressPeriodicReport.reportingFrequency > 0 else {
            throw AudioBotError.invalidReportingFrequency
        }
        if let audioPlayer = sharedBot.audioPlayer , audioPlayer.url == fileURL {
            audioPlayer.play()
        } else {
            sharedBot.audioPlayer?.pause()
            do {
                let audioPlayer = try AVAudioPlayer(contentsOf: fileURL)
                sharedBot.audioPlayer = audioPlayer
                audioPlayer.delegate = sharedBot
                audioPlayer.prepareToPlay()
                audioPlayer.currentTime = fromTime
                audioPlayer.play()
            } catch {
                throw error
            }
        }
        sharedBot.playingPeriodicReport = progressPeriodicReport
        sharedBot.playingFinish = finish
        let timeInterval = 1 / progressPeriodicReport.reportingFrequency
        DispatchQueue.main.async {
            let timer = Timer.scheduledTimer(timeInterval: timeInterval, target: sharedBot, selector: #selector(AudioBot.reportPlayingProgress(_:)), userInfo: nil, repeats: true)
            sharedBot.playingTimer?.invalidate()
            sharedBot.playingTimer = timer
        }
    }

    @objc fileprivate func reportPlayingProgress(_ sender: Timer) {
        guard let audioPlayer = audioPlayer else {
            return
        }
        let progress = audioPlayer.currentTime / audioPlayer.duration
        playingPeriodicReport?.report(Float(progress))
        AudioBot.reportPlayingDuration?(audioPlayer.currentTime)
    }

    public class func pausePlay() {
        sharedBot.clearForPlaying(finish: false)
        sharedBot.audioPlayer?.pause()
        sharedBot.deactiveAudioSessionAndNotifyOthers()
    }

    public class func stopPlay() {
        sharedBot.clearForPlaying(finish: true)
        sharedBot.audioPlayer?.stop()
        sharedBot.playingFinish?(false)
        sharedBot.playingFinish = nil
        sharedBot.deactiveAudioSessionAndNotifyOthers()
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioBot: AVAudioRecorderDelegate {

    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("AudioBot audioRecorderDidFinishRecording: \(flag)")
    }

    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        error.flatMap {
            print("AudioBot audioRecorderEncodeErrorDidOccur: \($0)")
        }
        if let fileURL = AudioBot.recordingFileURL {
            AudioBot.removeAudioAtFileURL(fileURL)
        }
        clearForRecording()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioBot: AVAudioPlayerDelegate {

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("AudioBot audioPlayerDidFinishPlaying: \(flag)")
        clearForPlaying(finish: true)
        DispatchQueue.main.async {
            self.playingFinish?(true)
            self.playingFinish = nil
        }
        deactiveAudioSessionAndNotifyOthers()
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        error.flatMap {
            print("AudioBot audioPlayerDecodeErrorDidOccur: \($0)")
        }
        clearForPlaying(finish: true)
        DispatchQueue.main.async {
            self.playingFinish?(false)
            self.playingFinish = nil
        }
        deactiveAudioSessionAndNotifyOthers()
    }
}
