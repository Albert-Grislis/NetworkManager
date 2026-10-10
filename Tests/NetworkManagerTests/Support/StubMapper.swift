//
//  StubMapper.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
@testable import NetworkManager

struct StubMapper {

    // MARK: Internal properties
    let requestedTypes: Recorder<String>

    // MARK: Private properties
    private let error: StubError?

    // MARK: initializers & deinitializers
    init(error: StubError?) {
        self.error = error
        self.requestedTypes = Recorder<String>()
    }
}

// MARK: MapperProtocol
extension StubMapper: MapperProtocol {
    func map<ResponseType>(data: Data) throws -> ResponseType where ResponseType: Decodable {
        self.requestedTypes.record(String(describing: ResponseType.self))
        if let error = self.error {
            throw error
        }
        return try JSONDecoder().decode(ResponseType.self, from: data)
    }
}
