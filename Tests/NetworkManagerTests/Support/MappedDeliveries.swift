//
//  MappedDeliveries.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

@testable import NetworkManager

struct MappedDeliveries<ResponseType, ErrorType>
where ResponseType: Decodable & Sendable, ErrorType: Error & Decodable {

    // MARK: Internal properties
    let successes: Recorder<Delivery<Result<ResponseType, ErrorType>>>
    let failures: Recorder<Delivery<Result<ResponseType, Error>>>
    var handlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType> {
        return (
            success: self.successes.recordingHandler(),
            failure: self.failures.recordingHandler()
        )
    }
    var handlersWithoutFailure: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType> {
        return (
            success: self.successes.recordingHandler(),
            failure: nil
        )
    }

    // MARK: initializers & deinitializers
    init() {
        self.successes = Recorder<Delivery<Result<ResponseType, ErrorType>>>()
        self.failures = Recorder<Delivery<Result<ResponseType, Error>>>()
    }
}
