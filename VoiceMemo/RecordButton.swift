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

    override var intrinsicContentSize : CGSize {
        return CGSize(width: 100, height: 100)
    }

    lazy var outerPath: UIBezierPath = {
        return UIBezierPath(ovalIn: self.bounds.insetBy(dx: 8, dy: 8))
    }()

    lazy var innerDefaultPath: UIBezierPath = {
        return UIBezierPath(roundedRect: self.bounds.insetBy(dx: 14, dy: 14), cornerRadius: 43)
    }()

    lazy var innerRecordingPath: UIBezierPath = {
        return UIBezierPath(roundedRect: self.bounds.insetBy(dx: 35, dy: 35), cornerRadius: 5)
    }()

    var fromInnerPath: UIBezierPath {
        switch appearance {
        case .default:
            return innerRecordingPath
        case .recording:
            return innerDefaultPath
        }
    }

    var toInnerPath: UIBezierPath {
        switch appearance {
        case .default:
            return innerDefaultPath
        case .recording:
            return innerRecordingPath
        }
    }

    enum Appearance {
        case `default`
        case recording

        var fromOuterLineWidth: CGFloat {
            switch self {
            case .default:
                return 3
            case .recording:
                return 8
            }
        }

        var toOuterLineWidth: CGFloat {
            switch self {
            case .default:
                return 8
            case .recording:
                return 3
            }
        }

        var fromOuterFillColor: UIColor {
            switch self {
            case .default:
                return UIColor(red: 237/255.0, green: 247/255.0, blue: 1, alpha: 1)
            case .recording:
                return UIColor.white
            }
        }

        var toOuterFillColor: UIColor {
            switch self {
            case .default:
                return UIColor.white
            case .recording:
                return UIColor(red: 237/255.0, green: 247/255.0, blue: 1, alpha: 1)
            }
        }

        var fromInnerFillColor: UIColor {
            switch self {
            case .default:
                return UIColor.red
            case .recording:
                return UIColor.blue
            }
        }

        var toInnerFillColor: UIColor {
            switch self {
            case .default:
                return UIColor.blue
            case .recording:
                return UIColor.red
            }
        }
    }

    var appearance: Appearance = .default {
        didSet {

            let duration: TimeInterval = 0.25

            do {
                let animation = CABasicAnimation(keyPath: "lineWidth")
                animation.fromValue = appearance.fromOuterLineWidth
                animation.toValue = appearance.toOuterLineWidth
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
                animation.fillMode = CAMediaTimingFillMode.both
                animation.isRemovedOnCompletion = false

                outerShapeLayer.add(animation, forKey: "lineWidth")
            }

            do {
                let animation = CABasicAnimation(keyPath: "fillColor")
                animation.fromValue = appearance.fromOuterFillColor.cgColor
                animation.toValue = appearance.toOuterFillColor.cgColor
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
                animation.fillMode = CAMediaTimingFillMode.both
                animation.isRemovedOnCompletion = false

                outerShapeLayer.add(animation, forKey: "fillColor")
            }

            do {
                let animation = CABasicAnimation(keyPath: "path")

                animation.fromValue = fromInnerPath.cgPath
                animation.toValue = toInnerPath.cgPath
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
                animation.fillMode = CAMediaTimingFillMode.both
                animation.isRemovedOnCompletion = false

                innerShapeLayer.add(animation, forKey: "path")
            }

            do {
                let animation = CABasicAnimation(keyPath: "fillColor")
                animation.fromValue = appearance.fromInnerFillColor.cgColor
                animation.toValue = appearance.toInnerFillColor.cgColor
                animation.duration = duration
                animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
                animation.fillMode = CAMediaTimingFillMode.both
                animation.isRemovedOnCompletion = false

                innerShapeLayer.add(animation, forKey: "fillColor")
            }
        }
    }

    lazy var outerShapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.path = self.outerPath.cgPath
        layer.lineWidth = self.appearance.toOuterLineWidth
        layer.strokeColor = UIColor.blue.cgColor
        layer.fillColor = self.appearance.toOuterFillColor.cgColor
        layer.fillRule = CAShapeLayerFillRule.evenOdd
        layer.contentsScale = UIScreen.main.scale
        return layer
    }()

    lazy var innerShapeLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.path = self.toInnerPath.cgPath
        layer.fillColor = self.appearance.toInnerFillColor.cgColor
        layer.fillRule = CAShapeLayerFillRule.evenOdd
        layer.contentsScale = UIScreen.main.scale
        return layer
    }()

    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        layer.addSublayer(outerShapeLayer)
        layer.addSublayer(innerShapeLayer)
    }
}

