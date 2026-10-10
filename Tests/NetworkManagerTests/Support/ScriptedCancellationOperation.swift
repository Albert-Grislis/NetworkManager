//
//  ScriptedCancellationOperation.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
@testable import NetworkManager

final class ScriptedCancellationOperation: RawNetworkOperation {

    // MARK: Internal properties
    override var isCancelled: Bool {
        return self.lock.withLock {
            guard self.cancellationChecks.count > 1 else { return self.cancellationChecks.first ?? false }
            return self.cancellationChecks.removeFirst()
        }
    }

    // MARK: Private properties
    private let lock: NSLock
    private var cancellationChecks: [Bool]

    // MARK: initializers & deinitializers
    init(
        cancellationChecks: [Bool],
        urlRequest: URLRequest,
        urlSession: URLSession,
        progressObserver: NetworkOperationProgressObservationProtocol?
    ) {
        self.cancellationChecks = cancellationChecks
        self.lock = NSLock()
        super.init(
            urlRequest: urlRequest,
            urlSession: urlSession,
            progressObserver: progressObserver,
            completionHandlersHashTable: nil
        )
    }
}

// MARK: Sendable
extension ScriptedCancellationOperation: @unchecked Sendable { /* EMPTY */ }
