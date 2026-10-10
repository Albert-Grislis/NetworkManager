//
//  MappedNetworkOperationTests.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
import Testing
@testable import NetworkManager

@Suite(.timeLimit(.minutes(1)))
struct MappedNetworkOperationTests {

    // MARK: Private types
    private enum Constants {
        static let concurrentDeliveryTimeout: DispatchTimeInterval = .milliseconds(200)
    }

    // MARK: Private properties
    private let server: StubServer

    // MARK: initializers & deinitializers
    init() {
        self.server = StubServer(responder: { (_, _) in nil })
    }

    // MARK: Internal methods
    @Test func completeDeliversMappedValueSynchronouslyOnEveryQueue() throws {
        let mapper = StubMapper(error: nil)
        let firstQueue = DispatchQueue.unique("first")
        let secondQueue = DispatchQueue.unique("second")
        let firstDeliveries = MappedDeliveries<Payload, ServerError>()
        let secondDeliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: mapper,
            mappedDataCompletionHandlersHashTable: [
                firstQueue: [
                    firstDeliveries.handlers,
                ],
                secondQueue: [
                    secondDeliveries.handlers,
                ],
            ]
        )
        operation.complete(result: .success(Data(#"{"value":"mapped"}"#.utf8)))
        let firstDelivery = try #require(firstDeliveries.successes.values.first)
        let secondDelivery = try #require(secondDeliveries.successes.values.first)
        #expect(try firstDelivery.value.get() == Payload(value: "mapped"))
        #expect(firstDelivery.queueLabel == firstQueue.label)
        #expect(try secondDelivery.value.get() == Payload(value: "mapped"))
        #expect(secondDelivery.queueLabel == secondQueue.label)
        #expect(firstDeliveries.failures.values.isEmpty)
        #expect(secondDeliveries.failures.values.isEmpty)
        #expect(mapper.requestedTypes.values == ["Payload"])
    }

    @Test func completeDeliversDecodedServerErrorThroughSuccessHandler() throws {
        let mapper = StubMapper(error: nil)
        let queue = DispatchQueue.unique("server-error")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: mapper,
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    deliveries.handlers,
                ],
            ]
        )
        operation.complete(result: .success(Data(#"{"code":7,"message":"rejected"}"#.utf8)))
        let delivery = try #require(deliveries.successes.values.first)
        #expect(throws: ServerError(code: 7, message: "rejected")) {
            try delivery.value.get()
        }
        #expect(delivery.queueLabel == queue.label)
        #expect(deliveries.failures.values.isEmpty)
        #expect(mapper.requestedTypes.values == ["Payload", "ServerError"])
    }

    @Test func completeDeliversResponseDecodingErrorWhenServerErrorCannotBeDecoded() throws {
        let mapper = StubMapper(error: nil)
        let queue = DispatchQueue.unique("undecodable")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: mapper,
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    deliveries.handlers,
                ],
            ]
        )
        operation.complete(result: .success(Data(#"{"unexpected":true}"#.utf8)))
        let delivery = try #require(deliveries.failures.values.first)
        let error = try #require(throws: DecodingError.self) {
            try delivery.value.get()
        }
        #expect(error.missingKey == "value")
        #expect(delivery.queueLabel == queue.label)
        #expect(deliveries.successes.values.isEmpty)
        #expect(mapper.requestedTypes.values == ["Payload", "ServerError"])
    }

    @Test func completeDeliversResponseDecodingErrorWhenErrorTypeFailsWithOtherError() throws {
        let mapper = StubMapper(error: nil)
        let queue = DispatchQueue.unique("rejecting")
        let deliveries = MappedDeliveries<Payload, RejectingError>()
        let operation = try self.makeOperation(
            mapper: mapper,
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    deliveries.handlers,
                ],
            ]
        )
        operation.complete(result: .success(Data(#"{"unexpected":true}"#.utf8)))
        let delivery = try #require(deliveries.failures.values.first)
        let error = try #require(throws: DecodingError.self) {
            try delivery.value.get()
        }
        #expect(error.missingKey == "value")
        #expect(deliveries.successes.values.isEmpty)
        #expect(mapper.requestedTypes.values == ["Payload", "RejectingError"])
    }

    @Test func completeDeliversMapperErrorWithoutMappingErrorType() throws {
        let mapper = StubMapper(error: .mapping)
        let queue = DispatchQueue.unique("mapper-error")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: mapper,
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    deliveries.handlers,
                ],
            ]
        )
        operation.complete(result: .success(Data(#"{"value":"ignored"}"#.utf8)))
        let delivery = try #require(deliveries.failures.values.first)
        #expect(throws: StubError.mapping) {
            try delivery.value.get()
        }
        #expect(deliveries.successes.values.isEmpty)
        #expect(mapper.requestedTypes.values == ["Payload"])
    }

    @Test func completeDeliversTransportFailureWithoutMapping() throws {
        let mapper = StubMapper(error: nil)
        let queue = DispatchQueue.unique("transport-failure")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: mapper,
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    deliveries.handlers,
                ],
            ]
        )
        operation.complete(result: .failure(URLError(.timedOut)))
        let delivery = try #require(deliveries.failures.values.first)
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(error.code == .timedOut)
        #expect(delivery.queueLabel == queue.label)
        #expect(deliveries.successes.values.isEmpty)
        #expect(mapper.requestedTypes.values.isEmpty)
    }

    @Test(
        arguments: [
            Result<Data, Error>.failure(URLError(.timedOut)),
            .success(Data(#"{"unexpected":true}"#.utf8)),
        ]
    )
    func failuresWithoutFailureHandlerAreDropped(result: Result<Data, Error>) throws {
        let queue = DispatchQueue.unique("without-failure")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    deliveries.handlersWithoutFailure,
                ],
            ]
        )
        operation.complete(result: result)
        #expect(deliveries.successes.values.isEmpty)
        #expect(deliveries.failures.values.isEmpty)
    }

    @Test(
        arguments: [
            Result<Data, Error>.success(Data(#"{"value":"ordered"}"#.utf8)),
            .failure(URLError(.timedOut)),
        ]
    )
    func rawHandlersReceiveTransportResultBeforeMappedHandlers(result: Result<Data, Error>) throws {
        let queue = DispatchQueue.unique("raw-first")
        let events = Recorder<Delivery<String>>()
        let rawDeliveries = RawDeliveries()
        let operation: MappedNetworkOperation<Payload, ServerError> = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    (
                        success: events.namingHandler("mapped"),
                        failure: events.namingHandler("mapped")
                    ),
                ],
            ]
        )
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                queue: [
                    events.namingHandler("raw"),
                    rawDeliveries.recordingHandler(),
                ],
            ]
        )
        operation.complete(result: result)
        let rawDelivery = try #require(rawDeliveries.values.first)
        #expect(didMerge)
        #expect(events.values.map(\.value) == ["raw", "mapped"])
        #expect(rawDelivery.value.mapError { (error) in error as NSError } == result.mapError { (error) in error as NSError })
    }

    @Test func completeIsDeliveredOnlyOnce() throws {
        let queue = DispatchQueue.unique("once")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    deliveries.handlers,
                ],
            ]
        )
        operation.complete(result: .success(Data(#"{"value":"first"}"#.utf8)))
        operation.complete(result: .success(Data(#"{"value":"second"}"#.utf8)))
        operation.complete(result: .failure(URLError(.timedOut)))
        #expect(deliveries.successes.values.count == 1)
        #expect(try deliveries.successes.values.first?.value.get() == Payload(value: "first"))
        #expect(deliveries.failures.values.isEmpty)
    }

    @Test func completeAfterCancelIsIgnored() async throws {
        let mapper = StubMapper(error: nil)
        let queue = DispatchQueue.unique("cancelled")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: mapper,
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    deliveries.handlers,
                ],
            ]
        )
        operation.cancel()
        operation.complete(result: .success(Data(#"{"value":"late"}"#.utf8)))
        await queue.drain()
        let delivery = try #require(deliveries.failures.values.first)
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(error.code == .cancelled)
        #expect(deliveries.failures.values.count == 1)
        #expect(deliveries.successes.values.isEmpty)
        #expect(mapper.requestedTypes.values.isEmpty)
    }

    @Test func cancelDeliversCancellationToRawHandlersThenMappedFailureHandlers() async throws {
        let queue = DispatchQueue.unique("cancel")
        let events = Recorder<Delivery<String>>()
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    (
                        success: events.namingHandler("success"),
                        failure: events.namingHandler("failure")
                    ),
                    deliveries.handlers,
                ],
            ]
        )
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                queue: [
                    events.namingHandler("raw"),
                ],
            ]
        )
        operation.cancel()
        await queue.drain()
        let delivery = try #require(deliveries.failures.values.first)
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(didMerge)
        #expect(events.values.map(\.value) == ["raw", "failure"])
        #expect(events.values.allSatisfy { (event) in event.queueLabel == queue.label })
        #expect(error.code == .cancelled)
        #expect(deliveries.successes.values.isEmpty)
    }

    @Test func cancelWithoutFailureHandlerDeliversNothingToMappedHandlers() async throws {
        let queue = DispatchQueue.unique("cancel-without-failure")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    deliveries.handlersWithoutFailure,
                ],
            ]
        )
        operation.cancel()
        await queue.drain()
        #expect(deliveries.successes.values.isEmpty)
        #expect(operation.isCancelled)
    }

    @Test func mergeAppendsMappedHandlersToExistingAndNewQueues() throws {
        let firstQueue = DispatchQueue.unique("first")
        let secondQueue = DispatchQueue.unique("second")
        let events = Recorder<Delivery<String>>()
        let operation: MappedNetworkOperation<Payload, ServerError> = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: [
                firstQueue: [
                    (
                        success: events.namingHandler("initial"),
                        failure: nil
                    ),
                ],
            ]
        )
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                firstQueue: [
                    (
                        success: events.namingHandler("appended"),
                        failure: nil
                    ),
                ],
                secondQueue: [
                    (
                        success: events.namingHandler("added"),
                        failure: nil
                    ),
                ],
            ],
            mapper: StubMapper(error: nil)
        )
        operation.complete(result: .success(Data(#"{"value":"merged"}"#.utf8)))
        let delivered = events.values
        #expect(didMerge)
        #expect(delivered.filter { (delivery) in delivery.queueLabel == firstQueue.label }.map(\.value) == ["initial", "appended"])
        #expect(delivered.filter { (delivery) in delivery.queueLabel == secondQueue.label }.map(\.value) == ["added"])
    }

    @Test func mergeIsRejectedOnceCancelled() async throws {
        let queue = DispatchQueue.unique("rejected")
        let initialDeliveries = MappedDeliveries<Payload, ServerError>()
        let lateDeliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    initialDeliveries.handlers,
                ],
            ]
        )
        operation.cancel()
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                queue: [
                    lateDeliveries.handlers,
                ],
            ],
            mapper: StubMapper(error: nil)
        )
        await queue.drain()
        #expect(!didMerge)
        #expect(initialDeliveries.failures.values.count == 1)
        #expect(lateDeliveries.failures.values.isEmpty)
    }

    @Test func mergeIsRejectedOnceCompleted() throws {
        let queue = DispatchQueue.unique("completed")
        let initialDeliveries = MappedDeliveries<Payload, ServerError>()
        let lateDeliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    initialDeliveries.handlers,
                ],
            ]
        )
        operation.complete(result: .success(Data(#"{"value":"done"}"#.utf8)))
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                queue: [
                    lateDeliveries.handlers,
                ],
            ],
            mapper: StubMapper(error: nil)
        )
        operation.complete(result: .success(Data(#"{"value":"done"}"#.utf8)))
        #expect(!didMerge)
        #expect(initialDeliveries.successes.values.count == 1)
        #expect(lateDeliveries.successes.values.isEmpty)
    }

    @Test func operationWithoutInitialHandlersAcceptsMergedHandlers() throws {
        let queue = DispatchQueue.unique("late")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let operation: MappedNetworkOperation<Payload, ServerError> = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: nil
        )
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                queue: [
                    deliveries.handlers,
                ],
            ],
            mapper: StubMapper(error: nil)
        )
        operation.complete(result: .success(Data(#"{"value":"late"}"#.utf8)))
        #expect(didMerge)
        #expect(try deliveries.successes.values.first?.value.get() == Payload(value: "late"))
    }

    @Test func mergedHandlersAreMappedWithTheirOwnMapper() throws {
        let initialMapper = StubMapper(error: nil)
        let mergedMapper = StubMapper(error: .mapping)
        let queue = DispatchQueue.unique("own-mapper")
        let initialDeliveries = MappedDeliveries<Payload, ServerError>()
        let mergedDeliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: initialMapper,
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    initialDeliveries.handlers,
                ],
            ]
        )
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                queue: [
                    mergedDeliveries.handlers,
                ],
            ],
            mapper: mergedMapper
        )
        operation.complete(result: .success(Data(#"{"value":"mapped"}"#.utf8)))
        let initialDelivery = try #require(initialDeliveries.successes.values.first)
        let mergedDelivery = try #require(mergedDeliveries.failures.values.first)
        #expect(didMerge)
        #expect(try initialDelivery.value.get() == Payload(value: "mapped"))
        #expect(throws: StubError.mapping) {
            try mergedDelivery.value.get()
        }
        #expect(initialDeliveries.failures.values.isEmpty)
        #expect(mergedDeliveries.successes.values.isEmpty)
        #expect(initialMapper.requestedTypes.values == ["Payload"])
        #expect(mergedMapper.requestedTypes.values == ["Payload"])
    }

    @Test func cancelDeliversCancellationToMergedMappedFailureHandlers() async throws {
        let initialQueue = DispatchQueue.unique("initial")
        let mergedQueue = DispatchQueue.unique("merged")
        let initialDeliveries = MappedDeliveries<Payload, ServerError>()
        let mergedDeliveries = MappedDeliveries<Payload, ServerError>()
        let operation = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: [
                initialQueue: [
                    initialDeliveries.handlers,
                ],
            ]
        )
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                mergedQueue: [
                    mergedDeliveries.handlers,
                ],
            ],
            mapper: StubMapper(error: nil)
        )
        operation.cancel()
        await initialQueue.drain()
        await mergedQueue.drain()
        let initialDelivery = try #require(initialDeliveries.failures.values.first)
        let mergedDelivery = try #require(mergedDeliveries.failures.values.first)
        let initialError = try #require(throws: URLError.self) {
            try initialDelivery.value.get()
        }
        let mergedError = try #require(throws: URLError.self) {
            try mergedDelivery.value.get()
        }
        #expect(didMerge)
        #expect(initialError.code == .cancelled)
        #expect(initialDelivery.queueLabel == initialQueue.label)
        #expect(mergedError.code == .cancelled)
        #expect(mergedDelivery.queueLabel == mergedQueue.label)
        #expect(initialDeliveries.failures.values.count == 1)
        #expect(mergedDeliveries.failures.values.count == 1)
        #expect(initialDeliveries.successes.values.isEmpty)
        #expect(mergedDeliveries.successes.values.isEmpty)
    }

    @Test func cancelDeliversMergedMappedFailureHandlersOfOneQueueInOneBlockInRegistrationOrder() async throws {
        let queue = DispatchQueue.global()
        let events = Recorder<Delivery<String>>()
        let mergedFailureSemaphore = DispatchSemaphore(value: .zero)
        let operation: MappedNetworkOperation<Payload, ServerError> = try self.makeOperation(
            mapper: StubMapper(error: nil),
            mappedDataCompletionHandlersHashTable: [
                queue: [
                    (
                        success: events.namingHandler("success"),
                        failure: { (_) in
                            _ = mergedFailureSemaphore.wait(timeout: .now() + Constants.concurrentDeliveryTimeout)
                            events.record(
                                Delivery(
                                    value: "initial",
                                    queueLabel: DispatchQueue.currentLabel
                                )
                            )
                        }
                    ),
                ],
            ]
        )
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                queue: [
                    (
                        success: events.namingHandler("success"),
                        failure: { (_) in
                            events.record(
                                Delivery(
                                    value: "merged",
                                    queueLabel: DispatchQueue.currentLabel
                                )
                            )
                            mergedFailureSemaphore.signal()
                        }
                    ),
                ],
            ],
            mapper: StubMapper(error: nil)
        )
        operation.cancel()
        let delivered = await events.values(count: 2)
        #expect(didMerge)
        #expect(delivered.map(\.value) == ["initial", "merged"])
    }

    // MARK: Private methods
    private func makeOperation<ResponseType, ErrorType>(
        mapper: MapperProtocol,
        mappedDataCompletionHandlersHashTable: [DispatchQueue: [MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>]]?
    ) throws -> MappedNetworkOperation<ResponseType, ErrorType> where ResponseType: Decodable & Sendable, ErrorType: Error & Decodable {
        return MappedNetworkOperation(
            urlRequest: URLRequest(url: try self.server.url(path: "/mapped-operation")),
            urlSession: self.server.session,
            progressObserver: nil,
            mapper: mapper,
            mappedDataCompletionHandlersHashTable: mappedDataCompletionHandlersHashTable
        )
    }
}
