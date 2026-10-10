//
//  NetworkManagerMappedDataTests.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
import Testing
@testable import NetworkManager

@Suite(.timeLimit(.minutes(1)))
struct NetworkManagerMappedDataTests {

    // MARK: Private types
    private enum Constants {
        static let unprocessableEntityStatusCode: Int = 422
    }

    // MARK: Internal methods
    @Test(arguments: RequestVariant.allCases)
    func mappedDataSendsRequestAndDeliversDecodedValueOnHandlerQueue(variant: RequestVariant) async throws {
        let server = StubServer(reply: .text(#"{"value":"decoded"}"#))
        let manager = server.makeManager()
        let mapper = StubMapper(error: nil)
        let queue = DispatchQueue.unique("mapped")
        let observer = RecordingProgressObserver()
        let deliveries = MappedDeliveries<Payload, ServerError>()
        let url = try server.url(path: "/mapped")
        let expectedRequest = variant.makeURLRequest(url: url)
        variant.requestMappedData(
            from: manager,
            url: url,
            mapper: mapper,
            completionHandlerQueue: queue,
            completionHandlers: deliveries.handlers,
            progressObserver: observer
        )
        let delivery = try #require(await deliveries.successes.values(count: 1).first)
        await queue.drain()
        let exchange = try #require(server.exchanges.first)
        #expect(try delivery.value.get() == Payload(value: "decoded"))
        #expect(delivery.queueLabel == queue.label)
        #expect(deliveries.failures.values.isEmpty)
        #expect(mapper.requestedTypes.values == ["Payload"])
        #expect(server.exchanges.count == 1)
        #expect(exchange.request.url == url)
        #expect(exchange.request.httpMethod == expectedRequest.httpMethod)
        #expect(exchange.request.value(forHTTPHeaderField: "X-Variant") == expectedRequest.value(forHTTPHeaderField: "X-Variant"))
        #expect(exchange.body == (expectedRequest.httpBody ?? Data()))
        #expect(observer.observations.values.count == (variant.passesProgressObserver ? 1 : .zero))
        #expect(observer.observations.values.allSatisfy { (observation) in observation.progress.isFinished })
    }

    @Test func mappedDataDeliversDecodedServerErrorThroughSuccessHandler() async throws {
        let server = StubServer(
            reply: .response(
                statusCode: Constants.unprocessableEntityStatusCode,
                body: Data(#"{"code":42,"message":"invalid"}"#.utf8)
            )
        )
        let manager = server.makeManager()
        let mapper = StubMapper(error: nil)
        let queue = DispatchQueue.unique("server-error")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        manager.mappedData(
            url: try server.url(path: "/server-error"),
            mapper: mapper,
            completionHandlerQueue: queue,
            completionHandlers: deliveries.handlers
        )
        let delivery = try #require(await deliveries.successes.values(count: 1).first)
        await queue.drain()
        #expect(throws: ServerError(code: 42, message: "invalid")) {
            try delivery.value.get()
        }
        #expect(delivery.queueLabel == queue.label)
        #expect(deliveries.failures.values.isEmpty)
        #expect(mapper.requestedTypes.values == ["Payload", "ServerError"])
    }

    @Test func mappedDataDeliversDecodingErrorThroughFailureHandler() async throws {
        let server = StubServer(reply: .text(#"{"unexpected":true}"#))
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("decoding-error")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        manager.mappedData(
            url: try server.url(path: "/decoding-error"),
            mapper: StubMapper(error: nil),
            completionHandlerQueue: queue,
            completionHandlers: deliveries.handlers
        )
        let delivery = try #require(await deliveries.failures.values(count: 1).first)
        await queue.drain()
        let error = try #require(throws: DecodingError.self) {
            try delivery.value.get()
        }
        #expect(error.missingKey == "value")
        #expect(delivery.queueLabel == queue.label)
        #expect(deliveries.successes.values.isEmpty)
    }

    @Test func mappedDataDeliversMapperErrorThroughFailureHandler() async throws {
        let server = StubServer(reply: .text(#"{"value":"ignored"}"#))
        let manager = server.makeManager()
        let mapper = StubMapper(error: .mapping)
        let queue = DispatchQueue.unique("mapper-error")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        manager.mappedData(
            url: try server.url(path: "/mapper-error"),
            mapper: mapper,
            completionHandlerQueue: queue,
            completionHandlers: deliveries.handlers
        )
        let delivery = try #require(await deliveries.failures.values(count: 1).first)
        await queue.drain()
        #expect(throws: StubError.mapping) {
            try delivery.value.get()
        }
        #expect(deliveries.successes.values.isEmpty)
        #expect(mapper.requestedTypes.values == ["Payload"])
    }

    @Test func mappedDataDeliversTransportFailureThroughFailureHandler() async throws {
        let server = StubServer(reply: .failure(URLError(.networkConnectionLost)))
        let manager = server.makeManager()
        let mapper = StubMapper(error: nil)
        let queue = DispatchQueue.unique("transport-failure")
        let deliveries = MappedDeliveries<Payload, ServerError>()
        manager.mappedData(
            url: try server.url(path: "/transport-failure"),
            mapper: mapper,
            completionHandlerQueue: queue,
            completionHandlers: deliveries.handlers
        )
        let delivery = try #require(await deliveries.failures.values(count: 1).first)
        await queue.drain()
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(error.code == .networkConnectionLost)
        #expect(delivery.queueLabel == queue.label)
        #expect(deliveries.successes.values.isEmpty)
        #expect(mapper.requestedTypes.values.isEmpty)
    }
}
