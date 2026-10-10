//
//  RawNetworkOperationTests.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
import Testing
@testable import NetworkManager

@Suite(.timeLimit(.minutes(1)))
struct RawNetworkOperationTests {

    // MARK: Private properties
    private let server: StubServer
    private let operationQueue: OperationQueue

    // MARK: initializers & deinitializers
    init() {
        self.server = StubServer(responder: { (_, _) in nil })
        self.operationQueue = OperationQueue()
    }

    // MARK: Internal methods
    @Test func completeDeliversResultSynchronouslyOnEveryQueue() throws {
        let firstQueue = DispatchQueue.unique("first")
        let secondQueue = DispatchQueue.unique("second")
        let firstDeliveries = RawDeliveries()
        let secondDeliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                firstQueue: [
                    firstDeliveries.recordingHandler(),
                ],
                secondQueue: [
                    secondDeliveries.recordingHandler(),
                ],
            ]
        )
        operation.complete(result: .success(Data("payload".utf8)))
        let firstDelivery = try #require(firstDeliveries.values.first)
        let secondDelivery = try #require(secondDeliveries.values.first)
        #expect(try firstDelivery.value.get() == Data("payload".utf8))
        #expect(firstDelivery.queueLabel == firstQueue.label)
        #expect(try secondDelivery.value.get() == Data("payload".utf8))
        #expect(secondDelivery.queueLabel == secondQueue.label)
    }

    @Test func completeRunsHandlersOfOneQueueInRegistrationOrder() throws {
        let queue = DispatchQueue.unique("order")
        let events = Recorder<Delivery<String>>()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                queue: [
                    events.namingHandler("first"),
                    events.namingHandler("second"),
                    events.namingHandler("third"),
                ],
            ]
        )
        operation.complete(result: .failure(URLError(.timedOut)))
        #expect(events.values.map(\.value) == ["first", "second", "third"])
    }

    @Test func completeIsDeliveredOnlyOnce() throws {
        let queue = DispatchQueue.unique("once")
        let deliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                queue: [
                    deliveries.recordingHandler(),
                ],
            ]
        )
        operation.complete(result: .success(Data("first".utf8)))
        operation.complete(result: .success(Data("second".utf8)))
        operation.complete(result: .failure(URLError(.timedOut)))
        #expect(deliveries.values.count == 1)
        #expect(try deliveries.values.first?.value.get() == Data("first".utf8))
    }

    @Test func completeAfterCancelIsIgnored() async throws {
        let queue = DispatchQueue.unique("cancelled")
        let deliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                queue: [
                    deliveries.recordingHandler(),
                ],
            ]
        )
        operation.cancel()
        operation.complete(result: .success(Data("late".utf8)))
        await queue.drain()
        let delivery = try #require(deliveries.values.first)
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(deliveries.values.count == 1)
        #expect(error.code == .cancelled)
    }

    @Test func cancelDeliversCancellationAsynchronouslyOnHandlerQueue() async throws {
        let queue = DispatchQueue.unique("asynchronous")
        let deliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                queue: [
                    deliveries.recordingHandler(),
                ],
            ]
        )
        let deliveryCountWhenCancelReturned = queue.sync { () -> Int in
            operation.cancel()
            return deliveries.values.count
        }
        let delivery = try #require(await deliveries.values(count: 1).first)
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(deliveryCountWhenCancelReturned == .zero)
        #expect(error.code == .cancelled)
        #expect(delivery.queueLabel == queue.label)
        #expect(operation.isCancelled)
    }

    @Test func cancelIsDeliveredOnlyOnce() async throws {
        let queue = DispatchQueue.unique("cancel-once")
        let deliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                queue: [
                    deliveries.recordingHandler(),
                ],
            ]
        )
        operation.cancel()
        operation.cancel()
        await queue.drain()
        #expect(deliveries.values.count == 1)
    }

    @Test func cancelAfterCompleteDeliversNothing() async throws {
        let queue = DispatchQueue.unique("completed")
        let deliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                queue: [
                    deliveries.recordingHandler(),
                ],
            ]
        )
        operation.complete(result: .success(Data("done".utf8)))
        operation.cancel()
        await queue.drain()
        #expect(deliveries.values.count == 1)
        #expect(try deliveries.values.first?.value.get() == Data("done".utf8))
        #expect(operation.isCancelled)
    }

    @Test func cancelInvalidatesProgressObserver() throws {
        let observer = RecordingProgressObserver()
        let operation = try self.makeOperation(
            progressObserver: observer,
            completionHandlersHashTable: nil
        )
        operation.cancel()
        #expect(observer.invalidations.values.count == 1)
        #expect(observer.observations.values.isEmpty)
        #expect(operation.isCancelled)
    }

    @Test func mergeAppendsHandlersToExistingAndNewQueues() throws {
        let firstQueue = DispatchQueue.unique("first")
        let secondQueue = DispatchQueue.unique("second")
        let events = Recorder<Delivery<String>>()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                firstQueue: [
                    events.namingHandler("initial"),
                ],
            ]
        )
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                firstQueue: [
                    events.namingHandler("appended"),
                ],
                secondQueue: [
                    events.namingHandler("added"),
                ],
            ]
        )
        operation.complete(result: .success(Data()))
        let delivered = events.values
        #expect(didMerge)
        #expect(delivered.filter { (delivery) in delivery.queueLabel == firstQueue.label }.map(\.value) == ["initial", "appended"])
        #expect(delivered.filter { (delivery) in delivery.queueLabel == secondQueue.label }.map(\.value) == ["added"])
    }

    @Test func mergeIsRejectedOnceCancelled() async throws {
        let queue = DispatchQueue.unique("rejected")
        let events = Recorder<Delivery<String>>()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                queue: [
                    events.namingHandler("initial"),
                ],
            ]
        )
        operation.cancel()
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                queue: [
                    events.namingHandler("late"),
                ],
            ]
        )
        await queue.drain()
        #expect(!didMerge)
        #expect(events.values.map(\.value) == ["initial"])
    }

    @Test func mergeIsRejectedOnceCompleted() throws {
        let queue = DispatchQueue.unique("completed")
        let events = Recorder<Delivery<String>>()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                queue: [
                    events.namingHandler("initial"),
                ],
            ]
        )
        operation.complete(result: .success(Data()))
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                queue: [
                    events.namingHandler("late"),
                ],
            ]
        )
        operation.complete(result: .success(Data()))
        #expect(!didMerge)
        #expect(events.values.map(\.value) == ["initial"])
    }

    @Test func operationWithoutInitialHandlersAcceptsMergedHandlers() throws {
        let queue = DispatchQueue.unique("late")
        let deliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: nil
        )
        let didMerge = operation.mergeCompletionHandlers(
            contentsOf: [
                queue: [
                    deliveries.recordingHandler(),
                ],
            ]
        )
        operation.complete(result: .success(Data("late".utf8)))
        #expect(didMerge)
        #expect(try deliveries.values.first?.value.get() == Data("late".utf8))
    }

    @Test func finalizeCompletionIfNeededSucceedsOnlyOnce() throws {
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: nil
        )
        #expect(operation.finalizeCompletionIfNeeded())
        #expect(!operation.finalizeCompletionIfNeeded())
    }

    @Test func performIfCompletionIsNotFinalizedRunsMutationOnlyBeforeFinalization() throws {
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: nil
        )
        var mutationCount = Int.zero
        let didPerformBeforeFinalization = operation.performIfCompletionIsNotFinalized {
            mutationCount += 1
        }
        let didFinalize = operation.finalizeCompletionIfNeeded()
        let didPerformAfterFinalization = operation.performIfCompletionIsNotFinalized {
            mutationCount += 1
        }
        #expect(didPerformBeforeFinalization)
        #expect(didFinalize)
        #expect(!didPerformAfterFinalization)
        #expect(mutationCount == 1)
    }

    @Test func deinitInvalidatesProgressObserver() throws {
        let observer = RecordingProgressObserver()
        var operation: RawNetworkOperation? = try self.makeOperation(
            progressObserver: observer,
            completionHandlersHashTable: nil
        )
        let invalidationCountBeforeRelease = observer.invalidations.values.count
        #expect(operation?.isCancelled == false)
        operation = nil
        #expect(invalidationCountBeforeRelease == .zero)
        #expect(observer.invalidations.values.count == 1)
    }

    @Test func operationDoesNotRetainProgressObserver() throws {
        var observer: RecordingProgressObserver? = RecordingProgressObserver()
        weak let releasedObserver = observer
        let operation = try self.makeOperation(
            progressObserver: observer,
            completionHandlersHashTable: nil
        )
        observer = nil
        #expect(releasedObserver == nil)
        #expect(!operation.isCancelled)
    }

    @Test func operationDoesNotRetainAddedProgressObserver() throws {
        var observer: RecordingProgressObserver? = RecordingProgressObserver()
        weak let releasedObserver = observer
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: nil
        )
        operation.addProgressObserver(observer)
        observer = nil
        #expect(releasedObserver == nil)
        #expect(!operation.isCancelled)
    }

    @Test func cancelInvalidatesEveryProgressObserver() throws {
        let initialObserver = RecordingProgressObserver()
        let addedObserver = RecordingProgressObserver()
        let operation = try self.makeOperation(
            progressObserver: initialObserver,
            completionHandlersHashTable: nil
        )
        operation.addProgressObserver(addedObserver)
        operation.cancel()
        #expect(initialObserver.invalidations.values.count == 1)
        #expect(addedObserver.invalidations.values.count == 1)
        #expect(addedObserver.observations.values.isEmpty)
        #expect(operation.isCancelled)
    }

    @Test func progressObserverAddedBeforeStartObservesLoad() async throws {
        let initialObserver = RecordingProgressObserver()
        let addedObserver = RecordingProgressObserver()
        let operation = try self.makeOperation(
            progressObserver: initialObserver,
            completionHandlersHashTable: nil
        )
        operation.addProgressObserver(addedObserver)
        let observationCountBeforeStart = addedObserver.observations.values.count
        let finishes = self.enqueue(operation)
        let exchange = try #require(await self.server.exchanges(count: 1).first)
        let initialObservation = try #require(initialObserver.observations.values.first)
        let addedObservation = try #require(addedObserver.observations.values.first)
        exchange.reply(.text("observed"))
        await finishes.values(count: 1)
        #expect(observationCountBeforeStart == .zero)
        #expect(addedObservation.progress === initialObservation.progress)
        #expect(addedObserver.observations.values.count == 1)
        #expect(operation.isFinished)
    }

    @Test func progressObserverAddedDuringLoadObservesRunningTaskImmediately() async throws {
        let initialObserver = RecordingProgressObserver()
        let addedObserver = RecordingProgressObserver()
        let operation = try self.makeOperation(
            progressObserver: initialObserver,
            completionHandlersHashTable: nil
        )
        let finishes = self.enqueue(operation)
        let exchange = try #require(await self.server.exchanges(count: 1).first)
        operation.addProgressObserver(addedObserver)
        let initialObservation = try #require(initialObserver.observations.values.first)
        let addedObservation = try #require(addedObserver.observations.values.first)
        exchange.reply(.text("observed"))
        await finishes.values(count: 1)
        #expect(addedObservation.progress === initialObservation.progress)
        #expect(initialObserver.observations.values.count == 1)
        #expect(addedObserver.observations.values.count == 1)
        #expect(operation.isFinished)
    }

    @Test func progressObserverAddedAgainIsNotObservedTwice() async throws {
        let observer = RecordingProgressObserver()
        let operation = try self.makeOperation(
            progressObserver: observer,
            completionHandlersHashTable: nil
        )
        let finishes = self.enqueue(operation)
        let exchange = try #require(await self.server.exchanges(count: 1).first)
        operation.addProgressObserver(observer)
        let observationCountBeforeReply = observer.observations.values.count
        exchange.reply(.text("observed"))
        await finishes.values(count: 1)
        #expect(observationCountBeforeReply == 1)
        #expect(observer.observations.values.count == 1)
        #expect(operation.isFinished)
    }

    @Test func equalButDistinctProgressObserversAreEachObserved() async throws {
        let initialObserver = EqualProgressObserver()
        let addedObserver = EqualProgressObserver()
        let operation = try self.makeOperation(
            progressObserver: initialObserver,
            completionHandlersHashTable: nil
        )
        let finishes = self.enqueue(operation)
        let exchange = try #require(await self.server.exchanges(count: 1).first)
        operation.addProgressObserver(addedObserver)
        let initialObservation = try #require(initialObserver.recordingObserver.observations.values.first)
        let addedObservation = try #require(addedObserver.recordingObserver.observations.values.first)
        operation.cancel()
        await exchange.waitUntilStopped()
        await finishes.values(count: 1)
        #expect(initialObserver == addedObserver)
        #expect(initialObserver !== addedObserver)
        #expect(addedObservation.progress === initialObservation.progress)
        #expect(initialObserver.recordingObserver.observations.values.count == 1)
        #expect(addedObserver.recordingObserver.observations.values.count == 1)
        #expect(initialObserver.recordingObserver.invalidations.values.count == 1)
        #expect(addedObserver.recordingObserver.invalidations.values.count == 1)
    }

    @Test func startObservesProgressLoadsAndFinishesAfterDelivery() async throws {
        let queue = DispatchQueue.unique("start")
        let observer = RecordingProgressObserver()
        let deliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: observer,
            completionHandlersHashTable: [
                queue: [
                    deliveries.recordingHandler(),
                ],
            ]
        )
        let finishes = self.enqueue(operation)
        let exchange = try #require(await self.server.exchanges(count: 1).first)
        let observationCountBeforeReply = observer.observations.values.count
        let deliveryCountBeforeReply = deliveries.values.count
        exchange.reply(.text("started"))
        await finishes.values(count: 1)
        let observation = try #require(observer.observations.values.first)
        #expect(observationCountBeforeReply == 1)
        #expect(observation.progress.isFinished)
        #expect(deliveryCountBeforeReply == .zero)
        #expect(operation.isFinished)
        #expect(deliveries.values.count == 1)
        #expect(try deliveries.values.first?.value.get() == Data("started".utf8))
        #expect(exchange.request.url == operation.urlRequest.url)
    }

    @Test func transportFailureIsDeliveredBeforeOperationFinishes() async throws {
        let queue = DispatchQueue.unique("failure")
        let deliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: nil,
            completionHandlersHashTable: [
                queue: [
                    deliveries.recordingHandler(),
                ],
            ]
        )
        let finishes = self.enqueue(operation)
        let exchange = try #require(await self.server.exchanges(count: 1).first)
        exchange.reply(.failure(URLError(.networkConnectionLost)))
        await finishes.values(count: 1)
        let delivery = try #require(deliveries.values.first)
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(error.code == .networkConnectionLost)
        #expect(deliveries.values.count == 1)
        #expect(operation.isFinished)
    }

    @Test func cancelDuringLoadStopsTaskFinishesAndDeliversCancellationOnce() async throws {
        let queue = DispatchQueue.unique("in-flight")
        let observer = RecordingProgressObserver()
        let deliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: observer,
            completionHandlersHashTable: [
                queue: [
                    deliveries.recordingHandler(),
                ],
            ]
        )
        let finishes = self.enqueue(operation)
        let exchange = try #require(await self.server.exchanges(count: 1).first)
        operation.cancel()
        await exchange.waitUntilStopped()
        await finishes.values(count: 1)
        await queue.drain()
        let delivery = try #require(deliveries.values.first)
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        let observation = try #require(observer.observations.values.first)
        #expect(error.code == .cancelled)
        #expect(deliveries.values.count == 1)
        #expect(operation.isFinished)
        #expect(observation.progress.isCancelled)
        #expect(observer.invalidations.values.count == 1)
    }

    @Test func cancelBeforeStartFinishesWithoutLoading() async throws {
        let queue = DispatchQueue.unique("before-start")
        let observer = RecordingProgressObserver()
        let deliveries = RawDeliveries()
        let operation = try self.makeOperation(
            progressObserver: observer,
            completionHandlersHashTable: [
                queue: [
                    deliveries.recordingHandler(),
                ],
            ]
        )
        operation.cancel()
        let finishes = self.enqueue(operation)
        await finishes.values(count: 1)
        await queue.drain()
        let delivery = try #require(deliveries.values.first)
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(error.code == .cancelled)
        #expect(deliveries.values.count == 1)
        #expect(operation.isFinished)
        #expect(observer.observations.values.isEmpty)
        #expect(self.server.exchanges.isEmpty)
    }

    @Test(arguments: [1, 2])
    func cancellationNoticedInsideMainFinishesWithoutObservingProgress(uncancelledChecks: Int) throws {
        let observer = RecordingProgressObserver()
        let operation = ScriptedCancellationOperation(
            cancellationChecks: Array(repeating: false, count: uncancelledChecks) + [true],
            urlRequest: URLRequest(url: try self.server.url(path: "/scripted")),
            urlSession: self.server.session,
            progressObserver: observer
        )
        operation.start()
        #expect(operation.isFinished)
        #expect(observer.observations.values.isEmpty)
    }

    // MARK: Private methods
    private func makeOperation(
        progressObserver: NetworkOperationProgressObservationProtocol?,
        completionHandlersHashTable: [DispatchQueue: [RawNetworkRequestCompletionHandler]]?
    ) throws -> RawNetworkOperation {
        return RawNetworkOperation(
            urlRequest: URLRequest(url: try self.server.url(path: "/operation")),
            urlSession: self.server.session,
            progressObserver: progressObserver,
            completionHandlersHashTable: completionHandlersHashTable
        )
    }

    private func enqueue(_ operation: RawNetworkOperation) -> Recorder<Void> {
        let finishes = Recorder<Void>()
        operation.completionBlock = {
            finishes.record(())
        }
        self.operationQueue.addOperation(operation)
        return finishes
    }
}
