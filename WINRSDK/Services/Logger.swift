//
//  Logger.swift
//  WINRSDK
//
//  Created by Ryan Napolitano on 11/25/25.
//

import Foundation

final class Logger {
    static let shared = Logger()
    var level: WINROptions.LoggingLevel = .error

    func log(_ message: String, level: WINROptions.LoggingLevel = .info) {
        guard shouldLog(level) else { return }
        print("[WINRSDK] \(message)")
    }

    private func shouldLog(_ level: WINROptions.LoggingLevel) -> Bool {
        switch (self.level, level) {
        case (.none, _): return false
        case (.error, .info), (.error, .debug): return false
        case (.info, .debug): return false
        default: return true
        }
    }
}
