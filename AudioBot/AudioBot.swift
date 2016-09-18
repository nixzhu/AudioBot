//
//  AudioBot.swift
//  AudioBot
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import Foundation
import AVFoundation

open class AudioBot: NSObject {

    open static var mixWithOthersWhenRecording: Bool = false

    fileprivate override init() {
        super.init()
    }
    fileprivate static let sharedBot = AudioBot()

    fileprivate var audioRecorder: AVAudioRecorder?
    fileprivate var audioPlayer: AVAudioPlayer?

    open static var recording: Bool {
        return sharedBot.audioRecorder?.isRecording ?? false
    }

    open static var recordingFileURL: URL? {
        return sharedBot.audioRecorder?.url
    }

    open static var playing: Bool {
        return sharedBot.audioPlayer?.isPlaying ?? false
    }

    open static var playingFileURL: URL? {
        return sharedBot.audioPlayer?.url
    }

    open static var reportRecordingDuration: ((_ duration: TimeInterval) -> Void)?
    open static var reportPlayingDuration: ((_ duration: TimeInterval) -> Void)?

    fileprivate var recordingTimer: Timer?
    fileprivate var playingTimer: Timer?

    public enum Error: Error {

        case invalidReportingFrequency
        case noFileURL
    }

    public typealias PeriodicReport = (reportingFrequency: TimeInterval, report: (_ value: Float) -> Void)

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

        _ = try? AVAudioSession.sharedInstance().setActive(false, with: .notifyOthersOnDeactivation)
    }
}

// MARK: - Record

public extension AudioBot {

    public enum Usage {

        case normal
        case custom(settings: [String: AnyObject])

        var settings: [String: AnyObject] {

            switch self {

            case .normal:
                return [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC) as AnyObject,
                    AVEncoderAudioQualityKey : AVAudioQuality.medium.rawValue as AnyObject,
                    AVEncoderBitRateKey : 64000 as AnyObject,
                    AVNumberOfChannelsKey: 2 as AnyObject,
                    AVSampleRateKey : 44100.0 as AnyObject
                ]

            case .custom(let settings):
                return settings
            }
        }
    }

    public class func startRecordAudioToFileURL(_ fileURL: URL?, forUsage usage: Usage, withDecibelSamplePeriodicReport decibelSamplePeriodicReport: PeriodicReport) throws {

        stopPlay()

        do {
            if mixWithOthersWhenRecording {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: [.mixWithOthers, .defaultToSpeaker])
            } else {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord)
            }

            try AVAudioSession.sharedInstance().setActive(true)

        } catch let error {
            throw error
        }

        if let audioRecorder = sharedBot.audioRecorder , audioRecorder.isRecording {

            audioRecorder.stop()

            // TODO: delete previews record file?
        }

        guard let fileURL = (fileURL ?? FileManager.audiobot_audioFileURLWithName(UUID().uuidString)) else {
            throw Error.noFileURL
        }

        guard decibelSamplePeriodicReport.reportingFrequency > 0 else {
            throw Error.invalidReportingFrequency
        }

        let settings = usage.settings

        do {
            let audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            sharedBot.audioRecorder = audioRecorder

            audioRecorder.delegate = sharedBot
            audioRecorder.isMeteringEnabled = true
            audioRecorder.prepareToRecord()

        } catch let error {
            throw error
        }

        sharedBot.audioRecorder?.record()

        sharedBot.recordingPeriodicReport = decibelSamplePeriodicReport

        let timeInterval = 1 / decibelSamplePeriodicReport.reportingFrequency
        let timer = Timer.scheduledTimer(timeInterval: timeInterval, target: sharedBot, selector: #selector(AudioBot.reportRecordingDecibel(_:)), userInfo: nil, repeats: true)
        sharedBot.recordingTimer?.invalidate()
        sharedBot.recordingTimer = timer
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

    public class func stopRecord(_ finish: (_ fileURL: URL, _ duration: TimeInterval, _ decibelSamples: [Float]) -> Void) {

        defer {
            sharedBot.clearForRecording()
        }

        guard let audioRecorder = sharedBot.audioRecorder , audioRecorder.isRecording else {
            return
        }

        let duration = audioRecorder.currentTime

        audioRecorder.stop()

        finish(audioRecorder.url, duration, sharedBot.decibelSamples)
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

// MARK: - Playback

public extension AudioBot {

    public class func startPlayAudioAtFileURL(_ fileURL: URL, fromTime: TimeInterval, withProgressPeriodicReport progressPeriodicReport: PeriodicReport, finish: @escaping (Bool) -> Void) throws {

        stopRecord { _, _, _ in }

        if !AVAudioSession.sharedInstance().audiobot_canPlay {
            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch let error {
                throw error
            }
        }

        guard progressPeriodicReport.reportingFrequency > 0 else {
            throw Error.invalidReportingFrequency
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

            } catch let error {
                throw error
            }
        }

        sharedBot.playingPeriodicReport = progressPeriodicReport
        sharedBot.playingFinish = finish

        let timeInterval = 1 / progressPeriodicReport.reportingFrequency
        let timer = Timer.scheduledTimer(timeInterval: timeInterval, target: sharedBot, selector: #selector(AudioBot.reportPlayingProgress(_:)), userInfo: nil, repeats: true)
        sharedBot.playingTimer?.invalidate()
        sharedBot.playingTimer = timer
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

        print("AudioBot audioRecorderEncodeErrorDidOccur: \(error)")

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
        playingFinish?(true)
        playingFinish = nil

        deactiveAudioSessionAndNotifyOthers()
    }

    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {

        print("AudioBot audioPlayerDecodeErrorDidOccur: \(error)")

        clearForPlaying(finish: true)
        playingFinish?(false)
        playingFinish = nil

        deactiveAudioSessionAndNotifyOthers()
    }
}

