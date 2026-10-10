//
//  NetworkManagerDeduplicationTests.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
import Testing
@testable import NetworkManager

@Suite(.timeLimit(.minutes(1)))
struct NetworkManagerDeduplicationTests {

    // MARK: Private types
    private enum Constants {
        static let concurrentCallerCount: Int = 16
    }

    // MARK: Internal methods
    @Test(
        arguments: [
            ("/same", "body", "/same", "body", 1),
            ("/same", nil, "/same", nil, 1),
            ("/same", "first", "/same", "second", 2),
            ("/same", nil, "/same", "body", 2),
            ("/first", "body", "/second", "body", 2),
        ] as [(String, String?, String, String?, Int)]
    )
    func requestsShareLoadOnlyWhenURLRequestAndBodyMatch(
        firstPath: String,
        firstBody: String?,
        secondPath: String,
        secondBody: String?,
        expectedLoadCount: Int
    ) async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("deduplication")
        let firstDeliveries = RawDeliveries()
        let secondDeliveries = RawDeliveries()
        manager.rawData(
            urlRequest: try server.urlRequest(
                path: firstPath,
                method: "POST",
                body: firstBody
            ),
            completionHandlerQueue: queue,
            completionHandler: firstDeliveries.recordingHandler()
        )
        manager.rawData(
            urlRequest: try server.urlRequest(
                path: secondPath,
                method: "POST",
                body: secondBody
            ),
            completionHandlerQueue: queue,
            completionHandler: secondDeliveries.recordingHandler()
        )
        let exchanges = await server.exchanges(count: expectedLoadCount)
        exchanges.forEach { (exchange) in
            exchange.reply(.echo(of: exchange))
        }
        let firstDelivery = try #require(await firstDeliveries.values(count: 1).first)
        let secondDelivery = try #require(await secondDeliveries.values(count: 1).first)
        #expect(try firstDelivery.value.get() == Data("\(firstPath):\(firstBody ?? "")".utf8))
        #expect(try secondDelivery.value.get() == Data("\(secondPath):\(secondBody ?? "")".utf8))
        #expect(server.exchanges.count == expectedLoadCount)
    }

    @Test func mergedHandlersOnOneQueueRunInRegistrationOrder() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("order")
        let events = Recorder<Delivery<String>>()
        let url = try server.url(path: "/order")
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: events.namingHandler("first")
        )
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: events.namingHandler("second")
        )
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: events.namingHandler("third")
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        exchange.reply(.text("ordered"))
        let delivered = await events.values(count: 3)
        #expect(delivered.map(\.value) == ["first", "second", "third"])
        #expect(delivered.allSatisfy { (delivery) in delivery.queueLabel == queue.label })
        #expect(server.exchanges.count == 1)
    }

    @Test func mergedHandlersRunOnTheirOwnQueues() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let firstQueue = DispatchQueue.unique("first")
        let secondQueue = DispatchQueue.unique("second")
        let firstDeliveries = RawDeliveries()
        let secondDeliveries = RawDeliveries()
        let url = try server.url(path: "/queues")
        manager.rawData(
            url: url,
            completionHandlerQueue: firstQueue,
            completionHandler: firstDeliveries.recordingHandler()
        )
        manager.rawData(
            urlRequest: URLRequest(url: url),
            completionHandlerQueue: secondQueue,
            completionHandler: secondDeliveries.recordingHandler()
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        exchange.reply(.text("shared"))
        let firstDelivery = try #require(await firstDeliveries.values(count: 1).first)
        let secondDelivery = try #require(await secondDeliveries.values(count: 1).first)
        #expect(try firstDelivery.value.get() == Data("shared".utf8))
        #expect(firstDelivery.queueLabel == firstQueue.label)
        #expect(try secondDelivery.value.get() == Data("shared".utf8))
        #expect(secondDelivery.queueLabel == secondQueue.label)
        #expect(server.exchanges.count == 1)
    }

    @Test func concurrentCallersShareOneLoad() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("concurrent")
        let deliveries = RawDeliveries()
        let url = try server.url(path: "/concurrent")
        await withTaskGroup(of: Void.self) { (group) in
            for _ in .zero..<Constants.concurrentCallerCount {
                group.addTask {
                    manager.rawData(
                        url: url,
                        completionHandlerQueue: queue,
                        completionHandler: deliveries.recordingHandler()
                    )
                }
            }
        }
        let exchange = try #require(await server.exchanges(count: 1).first)
        exchange.reply(.text("shared"))
        let delivered = await deliveries.values(count: Constants.concurrentCallerCount)
        #expect(delivered.allSatisfy { (delivery) in (try? delivery.value.get()) == Data("shared".utf8) })
        #expect(server.exchanges.count == 1)
    }

    @Test func independentRequestsLoadConcurrently() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("independent")
        let firstDeliveries = RawDeliveries()
        let secondDeliveries = RawDeliveries()
        manager.rawData(
            url: try server.url(path: "/first"),
            completionHandlerQueue: queue,
            completionHandler: firstDeliveries.recordingHandler()
        )
        manager.rawData(
            url: try server.url(path: "/second"),
            completionHandlerQueue: queue,
            completionHandler: secondDeliveries.recordingHandler()
        )
        let exchanges = await server.exchanges(count: 2)
        exchanges.forEach { (exchange) in
            exchange.reply(.echo(of: exchange))
        }
        let firstDelivery = try #require(await firstDeliveries.values(count: 1).first)
        let secondDelivery = try #require(await secondDeliveries.values(count: 1).first)
        #expect(try firstDelivery.value.get() == Data("/first:".utf8))
        #expect(try secondDelivery.value.get() == Data("/second:".utf8))
    }

    @Test func mappedRequestsWithSameTypesShareOneLoad() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let mapper = StubMapper(error: nil)
        let firstQueue = DispatchQueue.unique("first")
        let secondQueue = DispatchQueue.unique("second")
        let firstDeliveries = MappedDeliveries<Payload, ServerError>()
        let secondDeliveries = MappedDeliveries<Payload, ServerError>()
        let url = try server.url(path: "/mapped")
        manager.mappedData(
            url: url,
            mapper: mapper,
            completionHandlerQueue: firstQueue,
            completionHandlers: firstDeliveries.handlers
        )
        manager.mappedData(
            urlRequest: URLRequest(url: url),
            mapper: mapper,
            completionHandlerQueue: secondQueue,
            completionHandlers: secondDeliveries.handlers
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        exchange.reply(.text(#"{"value":"shared"}"#))
        let firstDelivery = try #require(await firstDeliveries.successes.values(count: 1).first)
        let secondDelivery = try #require(await secondDeliveries.successes.values(count: 1).first)
        #expect(try firstDelivery.value.get() == Payload(value: "shared"))
        #expect(firstDelivery.queueLabel == firstQueue.label)
        #expect(try secondDelivery.value.get() == Payload(value: "shared"))
        #expect(secondDelivery.queueLabel == secondQueue.label)
        #expect(mapper.requestedTypes.values == ["Payload", "Payload"])
        #expect(server.exchanges.count == 1)
    }

    @Test func mappedRequestJoiningInFlightLoadIsMappedWithItsOwnMapper() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("own-mapper")
        let initialMapper = StubMapper(error: nil)
        let joiningMapper = StubMapper(error: .mapping)
        let initialDeliveries = MappedDeliveries<Payload, ServerError>()
        let joiningDeliveries = Recorder<Delivery<Result<Payload, Error>>>()
        let recordJoiningDelivery = joiningDeliveries.recordingHandler()
        let url = try server.url(path: "/own-mapper")
        manager.mappedData(
            url: url,
            mapper: initialMapper,
            completionHandlerQueue: queue,
            completionHandlers: initialDeliveries.handlers
        )
        manager.mappedData(
            url: url,
            mapper: joiningMapper,
            completionHandlerQueue: queue,
            completionHandlers: (
                success: { (result: Result<Payload, ServerError>) in
                    recordJoiningDelivery(result.mapError { (error) in error })
                },
                failure: recordJoiningDelivery
            )
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        exchange.reply(.text(#"{"value":"shared"}"#))
        let joiningDelivery = try #require(await joiningDeliveries.values(count: 1).first)
        let initialDelivery = try #require(initialDeliveries.successes.values.first)
        #expect(throws: StubError.mapping) {
            try joiningDelivery.value.get()
        }
        #expect(try initialDelivery.value.get() == Payload(value: "shared"))
        #expect(initialDeliveries.failures.values.isEmpty)
        #expect(initialMapper.requestedTypes.values == ["Payload"])
        #expect(joiningMapper.requestedTypes.values == ["Payload"])
        #expect(server.exchanges.count == 1)
    }

    @Test func requestsJoiningInFlightLoadObserveItsProgressUntilItIsReleased() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("joined-progress")
        let initialObserver = RecordingProgressObserver()
        let joiningRawObserver = RecordingProgressObserver()
        let joiningMappedObserver = RecordingProgressObserver()
        let initialDeliveries = MappedDeliveries<Payload, ServerError>()
        let joiningRawDeliveries = RawDeliveries()
        let joiningMappedDeliveries = MappedDeliveries<Payload, ServerError>()
        let url = try server.url(path: "/joined-progress")
        manager.mappedData(
            url: url,
            mapper: StubMapper(error: nil),
            completionHandlerQueue: queue,
            completionHandlers: initialDeliveries.handlers,
            progressObserver: initialObserver
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: joiningRawDeliveries.recordingHandler(),
            progressObserver: joiningRawObserver
        )
        manager.mappedData(
            url: url,
            mapper: StubMapper(error: nil),
            completionHandlerQueue: queue,
            completionHandlers: joiningMappedDeliveries.handlers,
            progressObserver: joiningMappedObserver
        )
        let initialObservation = try #require(initialObserver.observations.values.first)
        let joiningRawObservation = try #require(joiningRawObserver.observations.values.first)
        let joiningMappedObservation = try #require(joiningMappedObserver.observations.values.first)
        exchange.reply(.text(#"{"value":"joined"}"#))
        await initialDeliveries.successes.values(count: 1)
        await joiningRawDeliveries.values(count: 1)
        await joiningMappedDeliveries.successes.values(count: 1)
        await initialObserver.invalidations.values(count: 1)
        await joiningRawObserver.invalidations.values(count: 1)
        await joiningMappedObserver.invalidations.values(count: 1)
        #expect(joiningRawObservation.progress === initialObservation.progress)
        #expect(joiningMappedObservation.progress === initialObservation.progress)
        #expect(joiningRawObserver.observations.values.count == 1)
        #expect(joiningMappedObserver.observations.values.count == 1)
        #expect(joiningRawObserver.invalidations.values.count == 1)
        #expect(joiningMappedObserver.invalidations.values.count == 1)
        #expect(server.exchanges.count == 1)
    }

    @Test func progressObserversOfJoiningRequestsCanCallBackIntoManager() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("reentrant-observer")
        let untrackedRequest = URLRequest(url: try server.url(path: "/untracked"))
        let joiningRawObserver = ReentrantProgressObserver {
            manager.cancelAnyTasksIfNeeded(at: untrackedRequest)
        }
        let joiningMappedObserver = ReentrantProgressObserver {
            manager.cancelAnyTasksIfNeeded(at: untrackedRequest)
        }
        let initialDeliveries = MappedDeliveries<Payload, ServerError>()
        let joiningRawDeliveries = RawDeliveries()
        let joiningMappedDeliveries = MappedDeliveries<Payload, ServerError>()
        let url = try server.url(path: "/reentrant-observer")
        let body = #"{"value":"reentrant"}"#
        manager.mappedData(
            url: url,
            mapper: StubMapper(error: nil),
            completionHandlerQueue: queue,
            completionHandlers: initialDeliveries.handlers
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: joiningRawDeliveries.recordingHandler(),
            progressObserver: joiningRawObserver
        )
        manager.mappedData(
            url: url,
            mapper: StubMapper(error: nil),
            completionHandlerQueue: queue,
            completionHandlers: joiningMappedDeliveries.handlers,
            progressObserver: joiningMappedObserver
        )
        let joiningRawObservationCount = joiningRawObserver.recordingObserver.observations.values.count
        let joiningMappedObservationCount = joiningMappedObserver.recordingObserver.observations.values.count
        exchange.reply(.text(body))
        let initialDelivery = try #require(await initialDeliveries.successes.values(count: 1).first)
        let joiningRawDelivery = try #require(await joiningRawDeliveries.values(count: 1).first)
        let joiningMappedDelivery = try #require(await joiningMappedDeliveries.successes.values(count: 1).first)
        await joiningRawObserver.recordingObserver.invalidations.values(count: 1)
        await joiningMappedObserver.recordingObserver.invalidations.values(count: 1)
        #expect(joiningRawObservationCount == 1)
        #expect(joiningMappedObservationCount == 1)
        #expect(joiningRawObserver.recordingObserver.invalidations.values.count == 1)
        #expect(joiningMappedObserver.recordingObserver.invalidations.values.count == 1)
        #expect(try initialDelivery.value.get() == Payload(value: "reentrant"))
        #expect(try joiningRawDelivery.value.get() == Data(body.utf8))
        #expect(try joiningMappedDelivery.value.get() == Payload(value: "reentrant"))
        #expect(server.exchanges.count == 1)
    }

    @Test func rawRequestJoinsInFlightMappedRequest() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("joined")
        let mappedDeliveries = MappedDeliveries<Payload, ServerError>()
        let rawDeliveries = RawDeliveries()
        let url = try server.url(path: "/joined")
        let body = #"{"value":"joined"}"#
        manager.mappedData(
            url: url,
            mapper: StubMapper(error: nil),
            completionHandlerQueue: queue,
            completionHandlers: mappedDeliveries.handlers
        )
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: rawDeliveries.recordingHandler()
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        exchange.reply(.text(body))
        let mappedDelivery = try #require(await mappedDeliveries.successes.values(count: 1).first)
        let rawDelivery = try #require(await rawDeliveries.values(count: 1).first)
        #expect(try mappedDelivery.value.get() == Payload(value: "joined"))
        #expect(try rawDelivery.value.get() == Data(body.utf8))
        #expect(server.exchanges.count == 1)
    }

    @Test func mappedRequestDoesNotJoinInFlightRawRequest() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("separate")
        let rawDeliveries = RawDeliveries()
        let mappedDeliveries = MappedDeliveries<Payload, ServerError>()
        let url = try server.url(path: "/separate")
        let body = #"{"value":"separate"}"#
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: rawDeliveries.recordingHandler()
        )
        manager.mappedData(
            url: url,
            mapper: StubMapper(error: nil),
            completionHandlerQueue: queue,
            completionHandlers: mappedDeliveries.handlers
        )
        let exchanges = await server.exchanges(count: 2)
        exchanges.forEach { (exchange) in
            exchange.reply(.text(body))
        }
        let rawDelivery = try #require(await rawDeliveries.values(count: 1).first)
        let mappedDelivery = try #require(await mappedDeliveries.successes.values(count: 1).first)
        #expect(try rawDelivery.value.get() == Data(body.utf8))
        #expect(try mappedDelivery.value.get() == Payload(value: "separate"))
        #expect(server.exchanges.count == 2)
    }

    @Test func mappedRequestsWithDifferentResponseTypesDoNotShareLoad() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("types")
        let payloadDeliveries = MappedDeliveries<Payload, ServerError>()
        let alternativeDeliveries = MappedDeliveries<AlternativePayload, ServerError>()
        let url = try server.url(path: "/types")
        manager.mappedData(
            url: url,
            mapper: StubMapper(error: nil),
            completionHandlerQueue: queue,
            completionHandlers: payloadDeliveries.handlers
        )
        manager.mappedData(
            url: url,
            mapper: StubMapper(error: nil),
            completionHandlerQueue: queue,
            completionHandlers: alternativeDeliveries.handlers
        )
        let exchanges = await server.exchanges(count: 2)
        exchanges.forEach { (exchange) in
            exchange.reply(.text(#"{"value":"typed"}"#))
        }
        let payloadDelivery = try #require(await payloadDeliveries.successes.values(count: 1).first)
        let alternativeDelivery = try #require(await alternativeDeliveries.successes.values(count: 1).first)
        #expect(try payloadDelivery.value.get() == Payload(value: "typed"))
        #expect(try alternativeDelivery.value.get() == AlternativePayload(value: "typed"))
        #expect(server.exchanges.count == 2)
    }

    @Test func requestAfterCompletionStartsNewLoad() async throws {
        let server = StubServer { (index, _) in
            .text("load \(index)")
        }
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("repeated")
        let firstDeliveries = RawDeliveries()
        let secondDeliveries = RawDeliveries()
        let url = try server.url(path: "/repeated")
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: firstDeliveries.recordingHandler()
        )
        let firstDelivery = try #require(await firstDeliveries.values(count: 1).first)
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: secondDeliveries.recordingHandler()
        )
        let secondDelivery = try #require(await secondDeliveries.values(count: 1).first)
        #expect(try firstDelivery.value.get() == Data("load 0".utf8))
        #expect(try secondDelivery.value.get() == Data("load 1".utf8))
        #expect(server.exchanges.count == 2)
    }

    @Test func requestAfterNewestLoadCompletesDoesNotJoinDisplacedLoad() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("displaced")
        let newestObserver = RecordingProgressObserver()
        let displacedDeliveries = RawDeliveries()
        let newestDeliveries = MappedDeliveries<Payload, ServerError>()
        let laterDeliveries = RawDeliveries()
        let url = try server.url(path: "/displaced")
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: displacedDeliveries.recordingHandler()
        )
        let displacedExchange = try #require(await server.exchanges(count: 1).first)
        manager.mappedData(
            url: url,
            mapper: StubMapper(error: nil),
            completionHandlerQueue: queue,
            completionHandlers: newestDeliveries.handlers,
            progressObserver: newestObserver
        )
        let newestExchange = try #require(await server.exchanges(count: 2).dropFirst().first)
        newestExchange.reply(.text(#"{"value":"newest"}"#))
        let newestDelivery = try #require(await newestDeliveries.successes.values(count: 1).first)
        await newestObserver.invalidations.values(count: 1)
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: laterDeliveries.recordingHandler()
        )
        displacedExchange.reply(.text("displaced"))
        let displacedDelivery = try #require(await displacedDeliveries.values(count: 1).first)
        await queue.drain()
        try #require(laterDeliveries.values.isEmpty)
        let laterExchange = try #require(await server.exchanges(count: 3).dropFirst(2).first)
        laterExchange.reply(.text("later"))
        let laterDelivery = try #require(await laterDeliveries.values(count: 1).first)
        #expect(try newestDelivery.value.get() == Payload(value: "newest"))
        #expect(try displacedDelivery.value.get() == Data("displaced".utf8))
        #expect(try laterDelivery.value.get() == Data("later".utf8))
        #expect(server.exchanges.count == 3)
    }

    @Test func loadStartedFromCompletionHandlerStaysTrackedAfterPreviousLoadIsReleased() async throws {
        let server = StubServer { (index, _) in
            index == .zero ? .text("first") : nil
        }
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("reentrant")
        let firstObserver = RecordingProgressObserver()
        let firstDeliveries = RawDeliveries()
        let secondDeliveries = RawDeliveries()
        let thirdDeliveries = RawDeliveries()
        let url = try server.url(path: "/reentrant")
        let recordFirstDelivery = firstDeliveries.recordingHandler()
        let recordSecondDelivery = secondDeliveries.recordingHandler()
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: { (result) in
                recordFirstDelivery(result)
                manager.rawData(
                    url: url,
                    completionHandlerQueue: queue,
                    completionHandler: recordSecondDelivery
                )
            },
            progressObserver: firstObserver
        )
        let secondExchange = try #require(await server.exchanges(count: 2).dropFirst().first)
        await firstObserver.invalidations.values(count: 1)
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: thirdDeliveries.recordingHandler()
        )
        secondExchange.reply(.text("second"))
        let firstDelivery = try #require(await firstDeliveries.values(count: 1).first)
        let secondDelivery = try #require(await secondDeliveries.values(count: 1).first)
        let thirdDelivery = try #require(await thirdDeliveries.values(count: 1).first)
        #expect(try firstDelivery.value.get() == Data("first".utf8))
        #expect(try secondDelivery.value.get() == Data("second".utf8))
        #expect(try thirdDelivery.value.get() == Data("second".utf8))
        #expect(server.exchanges.count == 2)
    }
}
