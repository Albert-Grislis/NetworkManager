//
//  ReentrantProgressObserver.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
@testable import NetworkManager

final class ReentrantProgressObserver {

    // MARK: Internal properties
    let recordingObserver: RecordingProgressObserver

    // MARK: Private properties
    private let reentry: @Sendable () -> Void

    // MARK: initializers & deinitializers
    init(reentry: @escaping @Sendable () -> Void) {
        self.reentry = reentry
        self.recordingObserver = RecordingProgressObserver()
    }
}

// MARK: NetworkOperationProgressObservationProtocol
extension ReentrantProgressObserver: NetworkOperationProgressObservationProtocol {
    func observe(progress: Progress) {
        self.reentry()
        self.recordingObserver.observe(progress: progress)
    }

    func invalidateNetworkOperationProgressObservation() {
        self.reentry()
        self.recordingObserver.invalidateNetworkOperationProgressObservation()
    }
}
