//
//  NetworkManager+OperationKey.swift
//  NetworkManager
//
//  Created by Qwerty on 10.10.2026.
//

import Foundation

extension NetworkManager {
    struct OperationKey {

        // MARK: Private properties
        private let urlRequest: URLRequest
        private let httpBody: Data?

        // MARK: initializers & deinitializers
        init(urlRequest: URLRequest) {
            self.urlRequest = urlRequest
            self.httpBody = urlRequest.httpBody
        }
    }
}

// MARK: Hashable
extension NetworkManager.OperationKey: Hashable { /* EMPTY */ }
