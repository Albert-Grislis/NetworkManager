//
//  RequestVariant.swift
//  NetworkManagerTests
//
//  Created by Qwerty on 30.09.2026.
//

import Foundation
@testable import NetworkManager

enum RequestVariant: String {
    case url
    case urlWithProgressObserver
    case urlRequest
    case urlRequestWithProgressObserver

    // MARK: Internal properties
    var passesProgressObserver: Bool {
        switch self {
        case .url, .urlRequest:
            return false
        case .urlWithProgressObserver, .urlRequestWithProgressObserver:
            return true
        }
    }

    // MARK: Internal methods
    func makeURLRequest(url: URL) -> URLRequest {
        var urlRequest = URLRequest(url: url)
        switch self {
        case .url, .urlWithProgressObserver:
            break
        case .urlRequest, .urlRequestWithProgressObserver:
            urlRequest.httpMethod = "PUT"
            urlRequest.setValue(self.rawValue, forHTTPHeaderField: "X-Variant")
            urlRequest.httpBody = Data(self.rawValue.utf8)
        }
        return urlRequest
    }

    func requestRawData(
        from manager: NetworkManagerProtocol,
        url: URL,
        completionHandlerQueue: DispatchQueue,
        completionHandler: @escaping RawNetworkRequestCompletionHandler,
        progressObserver: NetworkOperationProgressObservationProtocol
    ) {
        let urlRequest = self.makeURLRequest(url: url)
        switch self {
        case .url:
            manager.rawData(
                url: url,
                completionHandlerQueue: completionHandlerQueue,
                completionHandler: completionHandler
            )
        case .urlWithProgressObserver:
            manager.rawData(
                url: url,
                completionHandlerQueue: completionHandlerQueue,
                completionHandler: completionHandler,
                progressObserver: progressObserver
            )
        case .urlRequest:
            manager.rawData(
                urlRequest: urlRequest,
                completionHandlerQueue: completionHandlerQueue,
                completionHandler: completionHandler
            )
        case .urlRequestWithProgressObserver:
            manager.rawData(
                urlRequest: urlRequest,
                completionHandlerQueue: completionHandlerQueue,
                completionHandler: completionHandler,
                progressObserver: progressObserver
            )
        }
    }

    func requestMappedData<ResponseType, ErrorType>(
        from manager: NetworkManagerProtocol,
        url: URL,
        mapper: MapperProtocol,
        completionHandlerQueue: DispatchQueue,
        completionHandlers: MappedNetworkRequestCompletionHandlers<ResponseType, ErrorType>,
        progressObserver: NetworkOperationProgressObservationProtocol
    ) where ResponseType: Decodable & Sendable, ErrorType: Error & Decodable {
        let urlRequest = self.makeURLRequest(url: url)
        switch self {
        case .url:
            manager.mappedData(
                url: url,
                mapper: mapper,
                completionHandlerQueue: completionHandlerQueue,
                completionHandlers: completionHandlers
            )
        case .urlWithProgressObserver:
            manager.mappedData(
                url: url,
                mapper: mapper,
                completionHandlerQueue: completionHandlerQueue,
                completionHandlers: completionHandlers,
                progressObserver: progressObserver
            )
        case .urlRequest:
            manager.mappedData(
                urlRequest: urlRequest,
                mapper: mapper,
                completionHandlerQueue: completionHandlerQueue,
                completionHandlers: completionHandlers
            )
        case .urlRequestWithProgressObserver:
            manager.mappedData(
                urlRequest: urlRequest,
                mapper: mapper,
                completionHandlerQueue: completionHandlerQueue,
                completionHandlers: completionHandlers,
                progressObserver: progressObserver
            )
        }
    }
}

// MARK: CaseIterable
extension RequestVariant: CaseIterable { /* EMPTY */ }

// MARK: Sendable
extension RequestVariant: Sendable { /* EMPTY */ }
