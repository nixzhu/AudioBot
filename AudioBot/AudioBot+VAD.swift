////
////  AudioBot+VAD.swift
////  VoiceMemo
////
////  Created by Wang,Shun on 28/12/2016.
////  Copyright © 2016 nixWork. All rights reserved.
////
//
//import Foundation
//
//public final class VAD: NSObject {
//    var longestTime: TimeInterval   = 30.0
//    var spaceTime: TimeInterval     = 2.0
//    var silenceTime: TimeInterval   = 0.5
//    var silenceVolume: Float        = 0.1
//}
//
//extension AudioBot {
//    public class func startAutomaticRecordAudio(forUsage usage: Usage, withVADSetting setting :VAD, withDecibelSamplePeriodicReport decibelSamplePeriodicReport: PeriodicReport, withRecordResultReport recordResultReport: @escaping ResultReport) throws {
//        do {
//            
//            var isValid = false
//            var count = 0
//            let activeCount = Int(decibelSamplePeriodicReport.reportingFrequency * setting.silenceTime)
//            let decibelPeriodicReport: AudioBot.PeriodicReport = (reportingFrequency: decibelSamplePeriodicReport.reportingFrequency, report: { decibelSample in
//                decibelSamplePeriodicReport.report(decibelSample)
//                
//                if decibelSample > setting.silenceVolume {
//                    isValid = true
//                    count = 0
//                }else if isValid {
//                    count += 1
//                }
//                
//                if count > activeCount, isValid {
//                    stopRecord({ (fileURL, duration, decibelSamples) in
//                        recordResultReport(fileURL, duration, decibelSamples)
//                    })
//                    try! startAutomaticRecordAudio(forUsage: usage, withVADSetting: setting, withDecibelSamplePeriodicReport: decibelSamplePeriodicReport, withRecordResultReport: recordResultReport)
//                }
//            })
//            try startRecordAudio(forUsage: usage, withDecibelSamplePeriodicReport: decibelPeriodicReport)
//            
//            DispatchQueue.main.asyncAfter(deadline: .now() + setting.spaceTime, execute: {
//                if !isValid {
//                    stopRecord(nil)
//                    try! startAutomaticRecordAudio(forUsage: usage, withVADSetting: setting, withDecibelSamplePeriodicReport: decibelSamplePeriodicReport, withRecordResultReport: recordResultReport)
//                    
//                }
//
//            })
//            
//        }
//        catch let error {
//            throw error
//        }
//        
//    }
//    
//    public class func stopAutomaticRecord() {
//        
//    }
//
//}
