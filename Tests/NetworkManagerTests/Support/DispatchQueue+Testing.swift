//
//  DispatchQueue+Testing.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation

extension DispatchQueue {

    // MARK: Internal properties
    static var currentLabel: String {
        return String(cString: __dispatch_queue_get_label(nil))
    }

    // MARK: Internal methods
    static func unique(_ name: String) -> DispatchQueue {
        return DispatchQueue(label: "NetworkManagerTests.\(name).\(UUID().uuidString)")
    }

    func drain() async {
        await withCheckedContinuation { (continuation) in
            self.async {
                continuation.resume()
            }
        }
    }
}
