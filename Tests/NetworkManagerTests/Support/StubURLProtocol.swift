//
//  StubURLProtocol.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation

final class StubURLProtocol: URLProtocol {

    // MARK: Internal properties
    let stops: Recorder<Void>

    // MARK: initializers & deinitializers
    override init(
        request: URLRequest,
        cachedResponse: CachedURLResponse?,
        client: URLProtocolClient?
    ) {
        self.stops = Recorder<Void>()
        super.init(
            request: request,
            cachedResponse: cachedResponse,
            client: client
        )
    }

    // MARK: Lifecycle
    override func startLoading() {
        guard let server = StubServer.server(for: self.request) else {
            self.client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        server.accept(StubExchange(urlProtocol: self))
    }

    override func stopLoading() {
        self.stops.record(())
    }

    // MARK: Internal methods
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    func deliver(_ reply: StubReply) {
        guard
            let client = self.client,
            let url = self.request.url
        else {
            return
        }
        switch reply {
        case let .response(statusCode, body):
            let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )
            guard let response else { return }
            client.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client.urlProtocol(self, didLoad: body)
            client.urlProtocolDidFinishLoading(self)
        case let .failure(error):
            client.urlProtocol(self, didFailWithError: error)
        }
    }
}

// MARK: Sendable
extension StubURLProtocol: @unchecked Sendable { /* EMPTY */ }
