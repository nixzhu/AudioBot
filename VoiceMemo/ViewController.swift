//
//  ViewController.swift
//  VoiceMemo
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import UIKit
import AudioBot
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var voiceMemosTableView: UITableView!

    @IBOutlet weak var recordButton: RecordButton!
    
    @IBOutlet weak var modeSegmentedControl: UISegmentedControl!
    
    @IBOutlet weak var waver: Waver!
    
    @IBOutlet weak var waverBottom: NSLayoutConstraint!
    
    @IBOutlet weak var buttonBottom: NSLayoutConstraint!
    
    var bottomConstrains: [NSLayoutConstraint] {
            return [self.buttonBottom, self.waverBottom]
        }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        AudioBot.prepareForNormalRecord()
    }

    var voiceMemos: [VoiceMemo] = []

    @IBAction func modeChangeAction(_ sender: Any) {
        
        let startConstant: CGFloat = 0
        let endConstant: CGFloat = -128.0
        let animationDuration: TimeInterval = 0.3
        let index  = modeSegmentedControl.selectedSegmentIndex
        self.bottomConstrains[1 - index].constant = endConstant
        UIView.animate(withDuration: animationDuration, animations: {
            self.view.layoutIfNeeded()
        }, completion: { (finished) in
            if finished {
                self.bottomConstrains[index].constant = startConstant
                UIView.animate(withDuration: animationDuration, animations: {
                    self.view.layoutIfNeeded()
                })
            }
        })
        
        if index == 1 {
            do {
                self.waver.waverCallback = { _ in }
                let decibelSamplePeriodicReport: AudioBot.PeriodicReport = (reportingFrequency: 60, report: { decibelSample in
                    print("decibelSample: \(decibelSample)")
                    self.waver.level = CGFloat(decibelSample)
                    
                })
                
                AudioBot.mixWithOthersWhenRecording = true
                
                let setting = VAD()
                setting.silenceTime = 0.75
                setting.silenceVolume = 0.05
                
                let recorderSetting = [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM) as AnyObject,
                    AVEncoderAudioQualityKey : AVAudioQuality.medium.rawValue as AnyObject,
                    AVEncoderBitRateKey : 64000 as AnyObject,
                    AVNumberOfChannelsKey: 2 as AnyObject,
                    AVSampleRateKey : 44100.0 as AnyObject
                ]
                
                let url = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
                
                let usage = AudioBot.Usage.custom(fileURL: nil, type: "wav", settings: recorderSetting)
                
                try AudioBot.startAutomaticRecordAudio(forUsage: usage, withVADSetting: setting, withDecibelSamplePeriodicReport: decibelSamplePeriodicReport, withRecordResultReport: { [weak self] (fileURL, duration, decibelSamples) in
                    print("fileURL: \(fileURL)")
                    print("duration: \(duration)")
                    print("decibelSamples: \(decibelSamples)")
                    
                    if duration < 2.5 { return }
                    
                    let voiceMemo = VoiceMemo(fileURL: fileURL, duration: duration)
                    self?.voiceMemos.append(voiceMemo)
                    
                    self?.voiceMemosTableView.reloadData()

                })
                
                
            } catch let error {
                print("record error: \(error)")
            }

        }else {
            AudioBot.stopAutomaticRecord()
        }
    }
    
    @IBAction func record(_ sender: UIButton) {

        if AudioBot.recording {

            AudioBot.stopRecord { [weak self] fileURL, duration, decibelSamples in

                print("fileURL: \(fileURL)")
                print("duration: \(duration)")
                print("decibelSamples: \(decibelSamples)")

                let voiceMemo = VoiceMemo(fileURL: fileURL, duration: duration)
                self?.voiceMemos.append(voiceMemo)

                self?.voiceMemosTableView.reloadData()
            }

            recordButton.appearance = .default

        } else {
            do {
                let decibelSamplePeriodicReport: AudioBot.PeriodicReport = (reportingFrequency: 10, report: { decibelSample in
                    print("decibelSample: \(decibelSample)")
                })

                AudioBot.mixWithOthersWhenRecording = true
                try AudioBot.startRecordAudio(forUsage: .normal, withDecibelSamplePeriodicReport: decibelSamplePeriodicReport)

                recordButton.appearance = .recording
                
            } catch let error {
                print("record error: \(error)")
            }
        }
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {

        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return voiceMemos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "VoiceMemoCell") as! VoiceMemoCell
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {

        if let cell = cell as? VoiceMemoCell {
            let voiceMemo = voiceMemos[(indexPath as NSIndexPath).row]
            cell.configureWithVoiceMemo(voiceMemo)

            cell.playOrPauseAction = { [weak self] cell, progressView in

                func tryPlay() {

                    do {
                        let progressPeriodicReport: AudioBot.PeriodicReport = (reportingFrequency: 10, report: { progress in
                            print("progress: \(progress)")

                            voiceMemo.progress = CGFloat(progress)

                            progressView.progress = progress
                        })

                        let fromTime = TimeInterval(voiceMemo.progress) * voiceMemo.duration
                        try AudioBot.startPlayAudioAtFileURL(voiceMemo.fileURL, fromTime: fromTime, withProgressPeriodicReport: progressPeriodicReport, finish: { success in

                            voiceMemo.playing = false
                            cell.playing = false
                        })

                        voiceMemo.playing = true
                        cell.playing = true

                    } catch let error {
                        print("play error: \(error)")
                    }
                }

                if AudioBot.playing {
                    AudioBot.pausePlay()

                    if let strongSelf = self {
                        for index in 0..<(strongSelf.voiceMemos).count {
                            let voiceMemo = strongSelf.voiceMemos[index]
                            if AudioBot.playingFileURL == voiceMemo.fileURL {
                                let indexPath = IndexPath(row: index, section: 0)
                                if let cell = tableView.cellForRow(at: indexPath) as? VoiceMemoCell {
                                    voiceMemo.playing = false
                                    cell.playing = false
                                }

                                break
                            }
                        }
                    }

                    if AudioBot.playingFileURL != voiceMemo.fileURL {
                        tryPlay()
                    }

                } else {
                    tryPlay()
                }
            }
        }
    }
}

