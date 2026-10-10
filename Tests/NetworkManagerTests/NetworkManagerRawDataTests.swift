//
//  NetworkManagerRawDataTests.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
import Testing
@testable import NetworkManager

@Suite(.timeLimit(.minutes(1)))
struct NetworkManagerRawDataTests {

    // MARK: Internal methods
    @Test(arguments: RequestVariant.allCases)
    func rawDataSendsRequestAndDeliversBodyOnHandlerQueue(variant: RequestVariant) async throws {
        let server = StubServer(reply: .text("raw body"))
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("raw")
        let observer = RecordingProgressObserver()
        let deliveries = RawDeliveries()
        let url = try server.url(path: "/raw")
        let expectedRequest = variant.makeURLRequest(url: url)
        variant.requestRawData(
            from: manager,
            url: url,
            completionHandlerQueue: queue,
            completionHandler: deliveries.recordingHandler(),
            progressObserver: observer
        )
        let delivery = try #require(await deliveries.values(count: 1).first)
        let exchange = try #require(server.exchanges.first)
        #expect(try delivery.value.get() == Data("raw body".utf8))
        #expect(delivery.queueLabel == queue.label)
        #expect(server.exchanges.count == 1)
        #expect(exchange.request.url == url)
        #expect(exchange.request.httpMethod == expectedRequest.httpMethod)
        #expect(exchange.request.value(forHTTPHeaderField: "X-Variant") == expectedRequest.value(forHTTPHeaderField: "X-Variant"))
        #expect(exchange.body == (expectedRequest.httpBody ?? Data()))
        #expect(observer.observations.values.count == (variant.passesProgressObserver ? 1 : .zero))
        #expect(observer.observations.values.allSatisfy { (observation) in observation.progress.isFinished })
    }

    @Test(arguments: [200, 201, 404, 500])
    func rawDataDeliversBodyWhateverTheStatusCode(statusCode: Int) async throws {
        let server = StubServer(
            reply: .response(
                statusCode: statusCode,
                body: Data("status \(statusCode)".utf8)
            )
        )
        let manager = server.makeManager()
        let deliveries = RawDeliveries()
        manager.rawData(
            url: try server.url(path: "/status"),
            completionHandlerQueue: DispatchQueue.unique("status"),
            completionHandler: deliveries.recordingHandler()
        )
        let delivery = try #require(await deliveries.values(count: 1).first)
        #expect(try delivery.value.get() == Data("status \(statusCode)".utf8))
    }

    @Test func rawDataDeliversEmptyBodyAsEmptyData() async throws {
        let server = StubServer(reply: .text(""))
        let manager = server.makeManager()
        let deliveries = RawDeliveries()
        manager.rawData(
            url: try server.url(path: "/empty"),
            completionHandlerQueue: DispatchQueue.unique("empty"),
            completionHandler: deliveries.recordingHandler()
        )
        let delivery = try #require(await deliveries.values(count: 1).first)
        #expect(try delivery.value.get() == Data())
    }

    @Test(
        arguments: [
            URLError.Code.notConnectedToInternet,
            .timedOut,
            .cannotFindHost,
        ]
    )
    func rawDataDeliversTransportFailure(code: URLError.Code) async throws {
        let server = StubServer(reply: .failure(URLError(code)))
        let manager = server.makeManager()
        let queue = DispatchQueue.unique("failure")
        let deliveries = RawDeliveries()
        manager.rawData(
            url: try server.url(path: "/failure"),
            completionHandlerQueue: queue,
            completionHandler: deliveries.recordingHandler()
        )
        let delivery = try #require(await deliveries.values(count: 1).first)
        let error = try #require(throws: URLError.self) {
            try delivery.value.get()
        }
        #expect(error.code == code)
        #expect(delivery.queueLabel == queue.label)
    }

    @Test(
        arguments: zip(
            [
                QualityOfService.userInteractive,
                .userInitiated,
                .utility,
            ],
            [
                DispatchQoS.QoSClass.userInteractive,
                .userInitiated,
                .utility,
            ]
        )
    )
    func operationsRunWithRequestedQualityOfService(
        qualityOfService: QualityOfService,
        expectedClass: DispatchQoS.QoSClass
    ) async throws {
        let server = StubServer(reply: .text("quality of service"))
        let manager = NetworkManager(
            urlSession: server.session,
            qualityOfServiceOfOperationQueue: qualityOfService
        )
        let observer = RecordingProgressObserver()
        let deliveries = RawDeliveries()
        manager.rawData(
            url: try server.url(path: "/quality-of-service"),
            completionHandlerQueue: DispatchQueue.unique("quality-of-service"),
            completionHandler: deliveries.recordingHandler(),
            progressObserver: observer
        )
        await deliveries.values(count: 1)
        let observation = try #require(observer.observations.values.first)
        #expect(observation.qualityOfServiceClass == expectedClass)
    }

    @Test func completedOperationIsReleasedAndInvalidatesItsProgressObserver() async throws {
        let server = StubServer(reply: .text("released"))
        let manager = server.makeManager()
        let observer = RecordingProgressObserver()
        let deliveries = RawDeliveries()
        manager.rawData(
            url: try server.url(path: "/released"),
            completionHandlerQueue: DispatchQueue.unique("released"),
            completionHandler: deliveries.recordingHandler(),
            progressObserver: observer
        )
        await deliveries.values(count: 1)
        await observer.invalidations.values(count: 1)
        let observation = try #require(observer.observations.values.first)
        #expect(observer.observations.values.count == 1)
        #expect(observation.progress.isFinished)
        #expect(observer.invalidations.values.count == 1)
    }
}
