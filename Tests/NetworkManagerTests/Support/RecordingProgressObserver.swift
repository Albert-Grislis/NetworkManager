//
//  RecordingProgressObserver.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
@testable import NetworkManager

final class RecordingProgressObserver {

    // MARK: Internal properties
    let observations: Recorder<ProgressObservation>
    let invalidations: Recorder<Void>

    // MARK: initializers & deinitializers
    init() {
        self.observations = Recorder<ProgressObservation>()
        self.invalidations = Recorder<Void>()
    }
}

// MARK: NetworkOperationProgressObservationProtocol
extension RecordingProgressObserver: NetworkOperationProgressObservationProtocol {
    func observe(progress: Progress) {
        self.observations.record(
            ProgressObservation(
                progress: progress,
                qualityOfServiceClass: DispatchQoS.QoSClass(rawValue: qos_class_self())
            )
        )
    }

    func invalidateNetworkOperationProgressObservation() {
        self.invalidations.record(())
    }
}
