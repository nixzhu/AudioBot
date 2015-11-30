//
//  VoiceMemo.swift
//  VoiceMemo
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import UIKit

class VoiceMemo {

    let fileURL: NSURL
    var duration: NSTimeInterval

    var progress: CGFloat = 0
    var playing: Bool = false

    let createdAt: NSDate = NSDate()

    init(fileURL: NSURL, duration: NSTimeInterval) {
        self.fileURL = fileURL
        self.duration = duration
    }
}

