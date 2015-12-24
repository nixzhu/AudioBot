//
//  AudioBot.swift
//  AudioBot
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import AVFoundation

public class AudioBot: NSObject {

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

    private var recordingTimer: NSTimer?
    private var playingTimer: NSTimer?

    public enum Error: ErrorType {

        case InvalidReportingFrequency
        case NoFileURL
    }

    public typealias PeriodicReport = (reportingFrequency: NSTimeInterval, report: (value: CGFloat) -> Void)

    private var recordingPeriodicReport: PeriodicReport?
    private var playingPeriodicReport: PeriodicReport?

    private var playingFinish: (Bool -> Void)?

    private var maxNumberOfDecibelSamples: Int?
    private var decibelSamples: [CGFloat] = []
}

// MARK: - Record

public extension AudioBot {

    public class func startRecordAudioToFileURL(fileURL: NSURL?, withSettings settings: [String: AnyObject]?, maxNumberOfDecibelSamples: Int? = nil, decibelSamplePeriodicReport: PeriodicReport) throws {

        stopPlay()

        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, withOptions: [.MixWithOthers, .DefaultToSpeaker])

        } catch let error {
            throw error
        }

        if let audioRecorder = sharedBot.audioRecorder where audioRecorder.recording {

            audioRecorder.stop()

            // TODO: delete previews record file?
        }

        guard let fileURL = (fileURL ?? NSFileManager.audiobot_audioURLWithName(NSUUID().UUIDString)) else {
            throw Error.NoFileURL
        }

        let settings: [String: AnyObject] = settings ?? [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVEncoderAudioQualityKey : AVAudioQuality.Max.rawValue,
            AVEncoderBitRateKey : 64000,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey : 44100.0
        ]

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

        sharedBot.maxNumberOfDecibelSamples = maxNumberOfDecibelSamples
        sharedBot.recordingPeriodicReport = decibelSamplePeriodicReport

        guard decibelSamplePeriodicReport.reportingFrequency > 0 else {
            throw Error.InvalidReportingFrequency
        }
        let timeInterval = 1 / decibelSamplePeriodicReport.reportingFrequency
        let timer = NSTimer.scheduledTimerWithTimeInterval(timeInterval, target: sharedBot, selector: "reportRecordingDecibel:", userInfo: nil, repeats: true)
        sharedBot.recordingTimer = timer
    }

    func reportRecordingDecibel(sender: NSTimer) {

        guard let audioRecorder = audioRecorder else {
            return
        }

        audioRecorder.updateMeters()

        let normalizedDecibel = CGFloat(pow(10, audioRecorder.averagePowerForChannel(0) / 40))

        recordingPeriodicReport?.report(value: normalizedDecibel)

        decibelSamples.append(normalizedDecibel)
    }

    public class func stopRecord(finish: (fileURL: NSURL, duration: NSTimeInterval, compressedDecibelSamples: [CGFloat]) -> Void) {

        defer {
            sharedBot.recordingTimer?.invalidate()
            sharedBot.recordingTimer = nil

            sharedBot.recordingPeriodicReport = nil
        }

        guard let audioRecorder = sharedBot.audioRecorder where audioRecorder.recording else {
            return
        }

        let duration = audioRecorder.currentTime

        audioRecorder.stop()

        // handle decibel samples compresse if need

        let compressedDecibelSamples: [CGFloat]

        if let maxNumberOfDecibelSamples = sharedBot.maxNumberOfDecibelSamples where maxNumberOfDecibelSamples > 0 {

            func f(x: Int, max: Int) -> Int {
                let n = 1 - 1 / exp(Double(x) / 100)
                return Int(Double(max) * n)
            }

            let finalNumber = f(sharedBot.decibelSamples.count, max: maxNumberOfDecibelSamples)

            func averageSamplingFrom(values:[CGFloat], withCount count: Int) -> [CGFloat] {

                let step = Double(values.count) / Double(count)

                var outputValues = [CGFloat]()

                var x: Double = 0

                for _ in 0..<count {

                    let index = Int(x)

                    if index < values.count {
                        let value = values[index]
                        let fixedValue = CGFloat(Int(value * 100)) / 100 // 最多两位小数
                        outputValues.append(fixedValue)

                    } else {
                        break
                    }
                    
                    x += step
                }
                
                return outputValues
            }

            compressedDecibelSamples = averageSamplingFrom(sharedBot.decibelSamples, withCount: finalNumber)

        } else {
            compressedDecibelSamples = sharedBot.decibelSamples
        }

        finish(fileURL: audioRecorder.url, duration: duration, compressedDecibelSamples: compressedDecibelSamples)
    }
}

// MARK: - Playback

public extension AudioBot {

    public class func startPlayAudioAtFileURL(fileURL: NSURL, fromTime: NSTimeInterval, withProgressPeriodicReport progressPeriodicReport: PeriodicReport, finish: Bool -> Void) throws {

        stopRecord { _, _, _ in }

        if AVAudioSession.sharedInstance().category == AVAudioSessionCategoryRecord {
            do {
                try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            } catch let error {
                throw error
            }
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

                sharedBot.playingPeriodicReport = progressPeriodicReport
                sharedBot.playingFinish = finish

                guard progressPeriodicReport.reportingFrequency > 0 else {
                    throw Error.InvalidReportingFrequency
                }
                let timeInterval = 1 / progressPeriodicReport.reportingFrequency
                let timer = NSTimer.scheduledTimerWithTimeInterval(timeInterval, target: sharedBot, selector: "reportPlayingProgress:", userInfo: nil, repeats: true)
                sharedBot.playingTimer = timer

            } catch let error {
                throw error
            }
        }
    }

    func reportPlayingProgress(sender: NSTimer) {

        guard let audioPlayer = audioPlayer else {
            return
        }

        let progress = audioPlayer.currentTime / audioPlayer.duration

        playingPeriodicReport?.report(value: CGFloat(progress))
    }

    public class func pausePlay() {

        sharedBot.audioPlayer?.pause()
    }

    public class func stopPlay() {

        sharedBot.playingTimer?.invalidate()
        sharedBot.playingTimer = nil

        sharedBot.playingPeriodicReport = nil

        sharedBot.audioPlayer?.stop()
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioBot: AVAudioRecorderDelegate {

    public func audioRecorderDidFinishRecording(recorder: AVAudioRecorder, successfully flag: Bool) {

        print("AudioBot audioRecorderDidFinishRecording: \(flag)")
    }

    public func audioRecorderEncodeErrorDidOccur(recorder: AVAudioRecorder, error: NSError?) {

        print("AudioBot audioRecorderEncodeErrorDidOccur: \(error)")
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioBot: AVAudioPlayerDelegate {

    public func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {

        print("AudioBot audioPlayerDidFinishPlaying: \(flag)")

        playingFinish?(true)
    }

    public func audioPlayerDecodeErrorDidOccur(player: AVAudioPlayer, error: NSError?) {

        print("AudioBot audioPlayerDecodeErrorDidOccur: \(error)")

        playingFinish?(false)
    }
}

