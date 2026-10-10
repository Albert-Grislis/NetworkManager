//
//  NetworkManagerCancellationTests.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
import Testing
@testable import NetworkManager

@Suite(.timeLimit(.minutes(1)))
struct NetworkManagerCancellationTests {

    // MARK: Internal methods
    @Test func cancelDeliversCancellationToEveryMergedRawHandlerAndStopsLoad() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let firstQueue = DispatchQueue.unique("first")
        let secondQueue = DispatchQueue.unique("second")
        let firstDeliveries = RawDeliveries()
        let secondDeliveries = RawDeliveries()
        let url = try server.url(path: "/cancelled")
        manager.rawData(
            url: url,
            completionHandlerQueue: firstQueue,
            completionHandler: firstDeliveries.recordingHandler()
        )
        manager.rawData(
            url: url,
            completionHandlerQueue: secondQueue,
            completionHandler: secondDeliveries.recordingHandler()
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        manager.cancelAnyTasksIfNeeded(at: URLRequest(url: url))
        await exchange.waitUntilStopped()
        let firstDelivery = try #require(await firstDeliveries.values(count: 1).first)
        let secondDelivery = try #require(await secondDeliveries.values(count: 1).first)
        let firstError = try #require(throws: URLError.self) {
            try firstDelivery.value.get()
        }
        let secondError = try #require(throws: URLError.self) {
            try secondDelivery.value.get()
        }
        #expect(firstError.code == .cancelled)
        #expect(firstDelivery.queueLabel == firstQueue.label)
        #expect(secondError.code == .cancelled)
        #expect(secondDelivery.queueLabel == secondQueue.label)
        #expect(server.exchanges.count == 1)
    }

    @Test func cancelDeliversCancellationToMappedFailureHandlersOnly() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let mapper = StubMapper(error: nil)
        let queue = DispatchQueue.unique("mapped")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let url = try server.url(path: "/mapped")
        manager.mappedData(
            url: url,
            mapper: mapper,
            completionHandlerQueue: queue,
            completionHandlers: deliveries.handlers
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        manager.cancelAnyTasksIfNeeded(at: URLRequest(url: url))
        await exchange.waitUntilStopped()
        let delivery = try #require(await deliveries.failures.values(count: 1).first)
        await queue.drain()
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(error.code == .cancelled)
        #expect(delivery.queueLabel == queue.label)
        #expect(deliveries.successes.values.isEmpty)
        #expect(mapper.requestedTypes.values.isEmpty)
    }

    @Test func cancelStopsEveryLoadStartedForRequest() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("every-load")
        let rawDeliveries = RawDeliveries()
        let payloadDeliveries = MappedDeliveries<Payload, ServerError>()
        let alternativeDeliveries = MappedDeliveries<AlternativePayload, ServerError>()
        let url = try server.url(path: "/every-load")
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: rawDeliveries.recordingHandler()
        )
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
        let exchanges = await server.exchanges(count: 3)
        manager.cancelAnyTasksIfNeeded(at: URLRequest(url: url))
        await queue.drain()
        let rawDelivery = try #require(rawDeliveries.values.first)
        let payloadDelivery = try #require(payloadDeliveries.failures.values.first)
        let alternativeDelivery = try #require(alternativeDeliveries.failures.values.first)
        for exchange in exchanges {
            await exchange.waitUntilStopped()
        }
        let rawError = try #require(throws: URLError.self) {
            try rawDelivery.value.get()
        }
        let payloadError = try #require(throws: URLError.self) {
            try payloadDelivery.value.get()
        }
        let alternativeError = try #require(throws: URLError.self) {
            try alternativeDelivery.value.get()
        }
        #expect(rawError.code == .cancelled)
        #expect(payloadError.code == .cancelled)
        #expect(alternativeError.code == .cancelled)
        #expect(rawDeliveries.values.count == 1)
        #expect(payloadDeliveries.successes.values.isEmpty)
        #expect(alternativeDeliveries.successes.values.isEmpty)
        #expect(server.exchanges.count == 3)
    }

    @Test func cancelledRequestCanBeRequestedAgain() async throws {
        let server = StubServer { (index, _) in
            index == .zero ? nil : .text("again")
        }
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("again")
        let firstDeliveries = RawDeliveries()
        let secondDeliveries = RawDeliveries()
        let url = try server.url(path: "/again")
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: firstDeliveries.recordingHandler()
        )
        await server.exchanges(count: 1)
        manager.cancelAnyTasksIfNeeded(at: URLRequest(url: url))
        let firstDelivery = try #require(await firstDeliveries.values(count: 1).first)
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: secondDeliveries.recordingHandler()
        )
        let secondDelivery = try #require(await secondDeliveries.values(count: 1).first)
        let error = try #require(throws: URLError.self) {
            try firstDelivery.value.get()
        }
        #expect(error.code == .cancelled)
        #expect(try secondDelivery.value.get() == Data("again".utf8))
        #expect(server.exchanges.count == 2)
    }

    @Test func cancelOfUntrackedRequestLeavesOtherLoadsRunning() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("kept")
        let deliveries = RawDeliveries()
        manager.rawData(
            url: try server.url(path: "/kept"),
            completionHandlerQueue: queue,
            completionHandler: deliveries.recordingHandler()
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        manager.cancelAnyTasksIfNeeded(at: URLRequest(url: try server.url(path: "/untracked")))
        exchange.reply(.text("kept"))
        let delivery = try #require(await deliveries.values(count: 1).first)
        #expect(try delivery.value.get() == Data("kept".utf8))
    }

    @Test func cancelMatchesRequestBody() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("body")
        let cancelledDeliveries = RawDeliveries()
        let keptDeliveries = RawDeliveries()
        let cancelledRequest = try server.urlRequest(
            path: "/body",
            method: "POST",
            body: "cancelled"
        )
        let keptRequest = try server.urlRequest(
            path: "/body",
            method: "POST",
            body: "kept"
        )
        manager.rawData(
            urlRequest: cancelledRequest,
            completionHandlerQueue: queue,
            completionHandler: cancelledDeliveries.recordingHandler()
        )
        manager.rawData(
            urlRequest: keptRequest,
            completionHandlerQueue: queue,
            completionHandler: keptDeliveries.recordingHandler()
        )
        let exchanges = await server.exchanges(count: 2)
        let cancelledExchange = try #require(exchanges.first { (exchange) in exchange.body == Data("cancelled".utf8) })
        let keptExchange = try #require(exchanges.first { (exchange) in exchange.body == Data("kept".utf8) })
        manager.cancelAnyTasksIfNeeded(at: cancelledRequest)
        await cancelledExchange.waitUntilStopped()
        keptExchange.reply(.echo(of: keptExchange))
        let cancelledDelivery = try #require(await cancelledDeliveries.values(count: 1).first)
        let keptDelivery = try #require(await keptDeliveries.values(count: 1).first)
        let error = try #require(throws: URLError.self) {
            try cancelledDelivery.value.get()
        }
        #expect(error.code == .cancelled)
        #expect(try keptDelivery.value.get() == Data("/body:kept".utf8))
    }

    @Test func cancelLetsInvalidatedProgressObserverCallBackIntoManager() async throws {
        let server = StubServer(responder: { (_, _) in nil })
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("reentrant-invalidation")
        let untrackedRequest = URLRequest(url: try server.url(path: "/untracked"))
        let observer = ReentrantProgressObserver {
            manager.cancelAnyTasksIfNeeded(at: untrackedRequest)
        }
        let deliveries = RawDeliveries()
        let url = try server.url(path: "/reentrant-invalidation")
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: deliveries.recordingHandler(),
            progressObserver: observer
        )
        let exchange = try #require(await server.exchanges(count: 1).first)
        manager.cancelAnyTasksIfNeeded(at: URLRequest(url: url))
        await exchange.waitUntilStopped()
        await observer.recordingObserver.invalidations.values(count: 1)
        let delivery = try #require(await deliveries.values(count: 1).first)
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(error.code == .cancelled)
        #expect(delivery.queueLabel == queue.label)
        #expect(observer.recordingObserver.observations.values.count == 1)
        #expect(server.exchanges.count == 1)
    }

    @Test func cancelAfterCompletionDeliversNothing() async throws {
        let server = StubServer(reply: .text("done"))
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("completed")
        let deliveries = RawDeliveries()
        let url = try server.url(path: "/completed")
        manager.rawData(
            url: url,
            completionHandlerQueue: queue,
            completionHandler: deliveries.recordingHandler()
        )
        await deliveries.values(count: 1)
        manager.cancelAnyTasksIfNeeded(at: URLRequest(url: url))
        await queue.drain()
        #expect(deliveries.values.count == 1)
        #expect(try deliveries.values.first?.value.get() == Data("done".utf8))
    }
}
