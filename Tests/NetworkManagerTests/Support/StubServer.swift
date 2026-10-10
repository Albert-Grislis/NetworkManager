//
//  StubServer.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
import Testing
@testable import NetworkManager

final class StubServer {

    // MARK: Internal properties
    let session: URLSession
    var exchanges: [StubExchange] {
        return self.recordedExchanges.values
    }

    // MARK: Private properties
    private static let registry: Registry = Registry()
    private let host: String
    private let responder: StubResponder
    private let recordedExchanges: Recorder<StubExchange>

    // MARK: initializers & deinitializers
    init(responder: @escaping StubResponder) {
        self.responder = responder
        self.session = URLSession(
            configuration: {
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [
                    StubURLProtocol.self,
                ]
                return configuration
            }()
        )
        self.host = "\(UUID().uuidString.lowercased()).networkmanager.test"
        self.recordedExchanges = Recorder<StubExchange>()
        Self.registry.register(self, forHost: self.host)
    }

    convenience init(reply: StubReply) {
        self.init { (_, _) in
            reply
        }
    }

    deinit {
        self.session.invalidateAndCancel()
    }

    // MARK: Internal methods
    static func server(for request: URLRequest) -> StubServer? {
        guard let host = request.url?.host() else { return nil }
        return Self.registry.server(forHost: host)
    }

    func url(path: String) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = self.host
        components.path = path
        return try #require(components.url)
    }

    func urlRequest(
        path: String,
        method: String,
        body: String?
    ) throws -> URLRequest {
        var urlRequest = URLRequest(url: try self.url(path: path))
        urlRequest.httpMethod = method
        urlRequest.httpBody = body.map { (body) in
            Data(body.utf8)
        }
        return urlRequest
    }

    func makeManager() -> NetworkManager {
        return NetworkManager(
            urlSession: self.session,
            qualityOfServiceOfOperationQueue: .userInitiated
        )
    }

    @discardableResult func exchanges(count: Int) async -> [StubExchange] {
        return await self.recordedExchanges.values(count: count)
    }

    func accept(_ exchange: StubExchange) {
        let index = self.recordedExchanges.record(exchange)
        if let reply = self.responder(index, exchange) {
            exchange.reply(reply)
        }
    }
}

// MARK: Sendable
extension StubServer: Sendable { /* EMPTY */ }
