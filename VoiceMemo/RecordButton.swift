//
//  RecordButton.swift
//  VoiceMemo
//
//  Created by NIX on 15/12/25.
//  Copyright © 2015年 nixWork. All rights reserved.
//

import UIKit

@IBDesignable
class RecordButton: UIButton {

    override func intrinsicContentSize() -> CGSize {
        return CGSize(width: 100, height: 100)
    }

    lazy var outerPath: UIBezierPath = {
        return UIBezierPath(ovalInRect: CGRectInset(self.bounds, 8, 8))
    }()

    lazy var innerDefaultPath: UIBezierPath = {
        return UIBezierPath(roundedRect: CGRectInset(self.bounds, 14, 14), cornerRadius: 43)
    }()

    lazy var innerRecordingPath: UIBezierPath = {
        return UIBezierPath(roundedRect: CGRectInset(self.bounds, 35, 35), cornerRadius: 5)
    }()

    var fromInnerPath: UIBezierPath {
        switch appearance {
        case .Default:
            return innerRecordingPath
        case .Recording:
            return innerDefaultPath
        }
    }

    var toInnerPath: UIBezierPath {
        switch appearance {
        case .Default:
            return innerDefaultPath
        case .Recording:
            return innerRecordingPath
        }
    }

    enum Appearance {
        case Default
        case Recording

        var fromOuterLineWidth: CGFloat {
            switch self {
            case .Default:
                return 3
            case .Recording:
                return 8
            }
        }

        var toOuterLineWidth: CGFloat {
            switch self {
            case .Default:
                return 8
            case .Recording:
                return 3
            }
        }

        var fromOuterFillColor: UIColor {
            switch self {
            case .Default:
                return UIColor(red: 237/255.0, green: 247/255.0, blue: 1, alpha: 1)
            case .Recording:
                return UIColor.whiteColor()
            }
        }

        var toOuterFillColor: UIColor {
            switch self {
            case .Default:
                return UIColor.whiteColor()
            case .Recording:
                return UIColor(red: 237/255.0, green: 247/255.0, blue: 1, alpha: 1)
            }
        }

        var fromInnerFillColor: UIColor {
            switch self {
            case .Default:
                return UIColor.redColor()
            case .Recording:
                return UIColor.blueColor()
            }
        }

        var toInnerFillColor: UIColor {
            switch self {
            case .Default:
                return UIColor.blueColor()
            case .Recording:
                return UIColor.redColor()
            }
        }
    }

    var appearance: Appearance = .Default {
        didSet {

            let duration: NSTimeInterval = 0.25

            do {
                let animation = CABasicAnimation(keyPath: "lineWidth")
                animation.fromValue = appearance.fromOuterLineWidth
                animation.toValue = appearance.toOuterLineWidth
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
                animation.fillMode = kCAFillModeBoth
                animation.removedOnCompletion = false

                outerShapeLayer.addAnimation(animation, forKey: "lineWidth")
            }

            do {
                let animation = CABasicAnimation(keyPath: "fillColor")
                animation.fromValue = appearance.fromOuterFillColor.CGColor
                animation.toValue = appearance.toOuterFillColor.CGColor
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
                animation.fillMode = kCAFillModeBoth
                animation.removedOnCompletion = false

                outerShapeLayer.addAnimation(animation, forKey: "fillColor")
            }

            do {
                let animation = CABasicAnimation(keyPath: "path")

                animation.fromValue = fromInnerPath.CGPath
                animation.toValue = toInnerPath.CGPath
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
                animation.fillMode = kCAFillModeBoth
                animation.removedOnCompletion = false

                innerShapeLayer.addAnimation(animation, forKey: "path")
            }

            do {
                let animation = CABasicAnimation(keyPath: "fillColor")
                animation.fromValue = appearance.fromInnerFillColor.CGColor
                animation.toValue = appearance.toInnerFillColor.CGColor
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
                animation.fillMode = kCAFillModeBoth
                animation.removedOnCompletion = false

                innerShapeLayer.addAnimation(animation, forKey: "fillColor")
            }
        }
    }

    lazy var outerShapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.path = self.outerPath.CGPath
        layer.lineWidth = self.appearance.toOuterLineWidth
        layer.strokeColor = UIColor.blueColor().CGColor
        layer.fillColor = self.appearance.toOuterFillColor.CGColor
        layer.fillRule = kCAFillRuleEvenOdd
        layer.contentsScale = UIScreen.mainScreen().scale
        return layer
    }()

    lazy var innerShapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.path = self.toInnerPath.CGPath
        layer.fillColor = self.appearance.toInnerFillColor.CGColor
        layer.fillRule = kCAFillRuleEvenOdd
        layer.contentsScale = UIScreen.mainScreen().scale
        return layer
    }()

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        layer.addSublayer(outerShapeLayer)
        layer.addSublayer(innerShapeLayer)
    }
}

