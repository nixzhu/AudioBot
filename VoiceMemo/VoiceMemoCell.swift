//
//  VoiceMemoCell.swift
//  VoiceMemo
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import UIKit

class VoiceMemoCell: UITableViewCell {

    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var datetimeLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    @IBOutlet weak var progressView: UIProgressView!

    var playing: Bool = false {
        willSet {
            if newValue != playing {
                if newValue {
                    playButton.setImage(UIImage(named: "icon_pause"), for: UIControlState())
                } else {
                    playButton.setImage(UIImage(named: "icon_play"), for: UIControlState())
                }
            }
        }
    }

    var playOrPauseAction: ((_ cell: VoiceMemoCell, _ progressView: UIProgressView) -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }

    func configureWithVoiceMemo(_ voiceMemo: VoiceMemo) {

        playing = voiceMemo.playing

        datetimeLabel.text = "\(voiceMemo.createdAt)"

        durationLabel.text = String(format: "%.1f", voiceMemo.duration)

        progressView.progress = Float(voiceMemo.progress)
    }

    @IBAction func playOrPause(_ sender: UIButton) {

        playOrPauseAction?(self, progressView)
    }
}

