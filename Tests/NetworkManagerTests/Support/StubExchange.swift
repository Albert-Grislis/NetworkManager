//
//  StubExchange.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation

struct StubExchange {

    // MARK: Private types
    private enum Constants {
        static let readBufferSize: Int = 1_024
    }

    // MARK: Internal properties
    let request: URLRequest
    let body: Data

    // MARK: Private properties
    private let urlProtocol: StubURLProtocol

    // MARK: initializers & deinitializers
    init(urlProtocol: StubURLProtocol) {
        self.urlProtocol = urlProtocol
        self.request = urlProtocol.request
        self.body = urlProtocol.request.httpBody ?? Self.readBody(from: urlProtocol.request.httpBodyStream)
    }

    // MARK: Internal methods
    func reply(_ reply: StubReply) {
        self.urlProtocol.deliver(reply)
    }

    func waitUntilStopped() async {
        await self.urlProtocol.stops.values(count: 1)
    }

    // MARK: Private methods
    private static func readBody(from stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer {
            stream.close()
        }
        var body = Data()
        var buffer = [UInt8](repeating: .zero, count: Constants.readBufferSize)
        while stream.hasBytesAvailable {
            let readCount = stream.read(&buffer, maxLength: buffer.count)
            guard readCount > .zero else { break }
            body.append(buffer, count: readCount)
        }
        return body
    }
}
