//
//  ViewController.swift
//  VoiceMemo
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import UIKit
import AudioBot

class ViewController: UIViewController {

    @IBOutlet weak var voiceMemosTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    var voiceMemos: [VoiceMemo] = []

    @IBAction func record(sender: UIButton) {

        if AudioBot.recording {

            AudioBot.stopRecord { [weak self] fileURL, duration, decibelSamples in

                print("fileURL: \(fileURL)")
                print("duration: \(duration)")
                print("decibelSamples: \(decibelSamples)")

                let voiceMemo = VoiceMemo(fileURL: fileURL, duration: duration)
                self?.voiceMemos.append(voiceMemo)

                self?.voiceMemosTableView.reloadData()
            }

        } else {
            do {
                let decibelSamplePeriodicReport: AudioBot.PeriodicReport = (reportingFrequency: 10, report: { decibelSample in
                    print("decibelSample: \(decibelSample)")
                })

                try AudioBot.startRecordAudioToFileURL(nil, withSettings: nil, decibelSamplePeriodicReport: decibelSamplePeriodicReport)

            } catch let error {
                print("record error: \(error)")
            }
        }
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSectionsInTableView(tableView: UITableView) -> Int {

        return 1
    }

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        return voiceMemos.count
    }

    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCellWithIdentifier("VoiceMemoCell") as! VoiceMemoCell
        return cell
    }

    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {

        if let cell = cell as? VoiceMemoCell {
            let voiceMemo = voiceMemos[indexPath.row]
            cell.configureWithVoiceMemo(voiceMemo)

            cell.playOrPauseAction = { [weak self] cell, progressView in

                func tryPlay() {

                    do {
                        let progressPeriodicReport: AudioBot.PeriodicReport = (reportingFrequency: 10, report: { progress in
                            print("progress: \(progress)")

                            voiceMemo.progress = progress

                            progressView.progress = Float(progress)
                        })

                        let fromTime = NSTimeInterval(voiceMemo.progress) * voiceMemo.duration
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
                                let indexPath = NSIndexPath(forRow: index, inSection: 0)
                                if let cell = tableView.cellForRowAtIndexPath(indexPath) as? VoiceMemoCell {
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

