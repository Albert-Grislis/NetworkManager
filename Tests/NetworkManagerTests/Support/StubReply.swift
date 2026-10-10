//
//  StubReply.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation

enum StubReply {
    case response(statusCode: Int, body: Data)
    case failure(URLError)

    // MARK: Private types
    private enum Constants {
        static let successStatusCode: Int = 200
    }

    // MARK: Internal methods
    static func text(_ text: String) -> StubReply {
        return .response(
            statusCode: Constants.successStatusCode,
            body: Data(text.utf8)
        )
    }

    static func echo(of exchange: StubExchange) -> StubReply {
        let path = exchange.request.url?.path() ?? ""
        let body = String(decoding: exchange.body, as: UTF8.self)
        return .text("\(path):\(body)")
    }
}
