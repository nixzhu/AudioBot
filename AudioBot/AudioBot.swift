//
//  AudioBot.swift
//  AudioBot
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import Foundation
import AVFoundation

public class AudioBot: NSObject {

    public static var mixWithOthersWhenRecording: Bool = false

    private override init() {
        super.init()
    }
    private static let sharedBot = AudioBot()

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?

    public static var recording: Bool {
        return sharedBot.audioRecorder?.recording ?? false
    }

    public static var recordingFileURL: NSURL? {
        return sharedBot.audioRecorder?.url
    }

    public static var playing: Bool {
        return sharedBot.audioPlayer?.playing ?? false
    }

    public static var playingFileURL: NSURL? {
        return sharedBot.audioPlayer?.url
    }

    public static var reportRecordingDuration: ((duration: NSTimeInterval) -> Void)?

    private var recordingTimer: NSTimer?
    private var playingTimer: NSTimer?

    public enum Error: ErrorType {

        case InvalidReportingFrequency
        case NoFileURL
    }

    public typealias PeriodicReport = (reportingFrequency: NSTimeInterval, report: (value: Float) -> Void)

    private var recordingPeriodicReport: PeriodicReport?
    private var playingPeriodicReport: PeriodicReport?

    private var playingFinish: (Bool -> Void)?

    private var decibelSamples: [Float] = []

    private func clearForRecording() {

        AudioBot.reportRecordingDuration = nil

        recordingTimer?.invalidate()
        recordingTimer = nil

        recordingPeriodicReport = nil

        decibelSamples = []
    }

    private func clearForPlaying(finish finish: Bool) {

        playingTimer?.invalidate()
        playingTimer = nil

        if finish {
            playingPeriodicReport?.report(value: 0)
        }
        playingPeriodicReport = nil
    }

    private func deactiveAudioSessionAndNotifyOthers() {

        let _ = try? AVAudioSession.sharedInstance().setActive(false, withOptions: .NotifyOthersOnDeactivation)
    }
}

// MARK: - Record

public extension AudioBot {

    public enum Usage {

        case Normal
        case Custom(settings: [String: AnyObject])

        var settings: [String: AnyObject] {

            switch self {

            case .Normal:
                return [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVEncoderAudioQualityKey : AVAudioQuality.Medium.rawValue,
                    AVEncoderBitRateKey : 64000,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey : 44100.0
                ]

            case .Custom(let settings):
                return settings
            }
        }
    }

    public class func startRecordAudioToFileURL(fileURL: NSURL?, forUsage usage: Usage, withDecibelSamplePeriodicReport decibelSamplePeriodicReport: PeriodicReport) throws {

        stopPlay()

        do {
            if mixWithOthersWhenRecording {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, withOptions: [.MixWithOthers, .DefaultToSpeaker])
            } else {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryRecord)
            }

            try AVAudioSession.sharedInstance().setActive(true)

        } catch let error {
            throw error
        }

        if let audioRecorder = sharedBot.audioRecorder where audioRecorder.recording {

            audioRecorder.stop()

            // TODO: delete previews record file?
        }

        guard let fileURL = (fileURL ?? NSFileManager.audiobot_audioFileURLWithName(NSUUID().UUIDString)) else {
            throw Error.NoFileURL
        }

        guard decibelSamplePeriodicReport.reportingFrequency > 0 else {
            throw Error.InvalidReportingFrequency
        }

        let settings = usage.settings

        do {
            let audioRecorder = try AVAudioRecorder(URL: fileURL, settings: settings)
            sharedBot.audioRecorder = audioRecorder

            audioRecorder.delegate = sharedBot
            audioRecorder.meteringEnabled = true
            audioRecorder.prepareToRecord()

        } catch let error {
            throw error
        }

        sharedBot.audioRecorder?.record()

        sharedBot.recordingPeriodicReport = decibelSamplePeriodicReport

        let timeInterval = 1 / decibelSamplePeriodicReport.reportingFrequency
        let timer = NSTimer.scheduledTimerWithTimeInterval(timeInterval, target: sharedBot, selector: #selector(AudioBot.reportRecordingDecibel(_:)), userInfo: nil, repeats: true)
        sharedBot.recordingTimer?.invalidate()
        sharedBot.recordingTimer = timer
    }

    @objc private func reportRecordingDecibel(sender: NSTimer) {

        guard let audioRecorder = audioRecorder else {
            return
        }

        audioRecorder.updateMeters()

        let normalizedDecibel = pow(10, audioRecorder.averagePowerForChannel(0) * 0.05)

        recordingPeriodicReport?.report(value: normalizedDecibel)

        decibelSamples.append(normalizedDecibel)

        AudioBot.reportRecordingDuration?(duration: audioRecorder.currentTime)
    }

    public class func stopRecord(finish: (fileURL: NSURL, duration: NSTimeInterval, decibelSamples: [Float]) -> Void) {

        defer {
            sharedBot.clearForRecording()
        }

        guard let audioRecorder = sharedBot.audioRecorder where audioRecorder.recording else {
            return
        }

        let duration = audioRecorder.currentTime

        audioRecorder.stop()

        finish(fileURL: audioRecorder.url, duration: duration, decibelSamples: sharedBot.decibelSamples)
    }

    public class func removeAudioAtFileURL(fileURL: NSURL) {

        NSFileManager.audiobot_removeAudioAtFileURL(fileURL)
    }

    public class func compressDecibelSamples(decibelSamples: [Float], withSamplingInterval samplingInterval: Int, minNumberOfDecibelSamples: Int, maxNumberOfDecibelSamples: Int) -> [Float] {

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

        func f(x: Int, max: Int) -> Int {
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

        func averageSamplingFrom(values: [Float], withCount count: Int) -> [Float] {

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

    public class func startPlayAudioAtFileURL(fileURL: NSURL, fromTime: NSTimeInterval, withProgressPeriodicReport progressPeriodicReport: PeriodicReport, finish: Bool -> Void) throws {

        stopRecord { _, _, _ in }

        if AVAudioSession.sharedInstance().category != AVAudioSessionCategoryPlayback {
            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch let error {
                throw error
            }
        }

        guard progressPeriodicReport.reportingFrequency > 0 else {
            throw Error.InvalidReportingFrequency
        }

        if let audioPlayer = sharedBot.audioPlayer where audioPlayer.url == fileURL {
            audioPlayer.play()

        } else {
            sharedBot.audioPlayer?.pause()

            do {
                let audioPlayer = try AVAudioPlayer(contentsOfURL: fileURL)
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
        let timer = NSTimer.scheduledTimerWithTimeInterval(timeInterval, target: sharedBot, selector: #selector(AudioBot.reportPlayingProgress(_:)), userInfo: nil, repeats: true)
        sharedBot.playingTimer?.invalidate()
        sharedBot.playingTimer = timer
    }

    @objc private func reportPlayingProgress(sender: NSTimer) {

        guard let audioPlayer = audioPlayer else {
            return
        }

        let progress = audioPlayer.currentTime / audioPlayer.duration

        playingPeriodicReport?.report(value: Float(progress))
    }

    public class func pausePlay() {

        sharedBot.clearForPlaying(finish: false)

        sharedBot.audioPlayer?.pause()

        sharedBot.deactiveAudioSessionAndNotifyOthers()
    }

    public class func stopPlay() {

        sharedBot.clearForPlaying(finish: true)

        sharedBot.audioPlayer?.stop()

        sharedBot.playingFinish?(true)
        sharedBot.playingFinish = nil

        sharedBot.deactiveAudioSessionAndNotifyOthers()
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioBot: AVAudioRecorderDelegate {

    public func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {

        print("AudioBot audioRecorderDidFinishRecording: \(flag)")
    }

    public func audioRecorderEncodeErrorDidOccur(recorder: AVAudioRecorder, error: NSError?) {

        print("AudioBot audioRecorderEncodeErrorDidOccur: \(error)")

        if let fileURL = AudioBot.recordingFileURL {
            AudioBot.removeAudioAtFileURL(fileURL)
        }

        clearForRecording()
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioBot: AVAudioPlayerDelegate {

    public func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {

        print("AudioBot audioPlayerDidFinishPlaying: \(flag)")

        clearForPlaying(finish: true)
        playingFinish?(true)
        playingFinish = nil

        deactiveAudioSessionAndNotifyOthers()
    }

    public func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer, error: NSError?) {

        print("AudioBot audioPlayerDecodeErrorDidOccur: \(error)")

        clearForPlaying(finish: true)
        playingFinish?(false)
        playingFinish = nil

        deactiveAudioSessionAndNotifyOthers()
    }
}

