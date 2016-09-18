//
//  VoiceMemo.swift
//  VoiceMemo
//
//  Created by NIX on 15/11/28.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import UIKit

class VoiceMemo {

    let fileURL: URL
    var duration: TimeInterval

    var progress: CGFloat = 0
    var playing: Bool = false

    let createdAt: Date = Date()

    init(fileURL: URL, duration: TimeInterval) {
        self.fileURL = fileURL
        self.duration = duration
    }
}

