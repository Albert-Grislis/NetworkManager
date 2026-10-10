//
//  EqualProgressObserver.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
@testable import NetworkManager

final class EqualProgressObserver: NSObject {

    // MARK: Internal properties
    let recordingObserver: RecordingProgressObserver
    override var hash: Int {
        return .zero
    }

    // MARK: initializers & deinitializers
    override init() {
        self.recordingObserver = RecordingProgressObserver()
        super.init()
    }

    // MARK: Internal methods
    override func isEqual(_ object: Any?) -> Bool {
        return object is EqualProgressObserver
    }
}

// MARK: NetworkOperationProgressObservationProtocol
extension EqualProgressObserver: NetworkOperationProgressObservationProtocol {
    func observe(progress: Progress) {
        self.recordingObserver.observe(progress: progress)
    }

    func invalidateNetworkOperationProgressObservation() {
        self.recordingObserver.invalidateNetworkOperationProgressObservation()
    }
}
