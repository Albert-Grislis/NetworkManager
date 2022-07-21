//
//  MappedNetworkOperation.swift
//  
//
//  Created by Albert Grislis on 25.12.2021.
//

import Foundation
import Utils

final class MappedNetworkOperation<ResponseType>: RawNetworkOperation where ResponseType: Decodable {
    
    // MARK: Internal properties
    @UnfairLock private(set) var mappedNetworkRequestCompletionHandlers: [MappedNetworkRequestCompletionHandler<ResponseType>]
    
    // MARK: Private properties
    private let mapper: MapperProtocol
    
    // MARK: Initializers & Deinitializers
    init(
        urlSession: URLSession,
        urlRequest: URLRequest,
        mapper: MapperProtocol,
        completionHandlersQueue: DispatchQueue,
        mappedNetworkRequestCompletionHandlers: [MappedNetworkRequestCompletionHandler<ResponseType>]?,
        progressObserver: NetworkOperationProgressObservationProtocol?
    ) {
        self.mappedNetworkRequestCompletionHandlers = mappedNetworkRequestCompletionHandlers ?? []
        self.mapper = mapper
        super.init(
            urlSession: urlSession,
            urlRequest: urlRequest,
            completionHandlersQueue: completionHandlersQueue,
            rawNetowrkRequestCompletionHandlers: [],
            progressObserver: progressObserver
        )
    }
    
    // MARK: Internal methods
    func appendCompletionHandlers(
        contentsOf sequence: [MappedNetworkRequestCompletionHandler<ResponseType>]
    ) {
        if !self.isCancelled {
            self.mappedNetworkRequestCompletionHandlers.append(contentsOf: sequence)
        }
    }
    
    override func removeLastCompletionHandler() {
        if !self.isCancelled {
            self.mappedNetworkRequestCompletionHandlers.removeLast()
        }
    }
    
    override func complete(result: Result<Data, Error>) {
        if !self.isCancelled {
            switch result {
            case let .success(data):
                let mappedData: ResponseType = mapper.map(data: data)
                self.completionHandlersQueue.sync { [weak self] in
                    self?.mappedNetworkRequestCompletionHandlers.forEach { (completionHandler) in
                        completionHandler(.success(mappedData))
                    }
                }
            case let .failure(error):
                self.completionHandlersQueue.sync { [weak self] in
                    self?.mappedNetworkRequestCompletionHandlers.forEach { (completionHandler) in
                        completionHandler(.failure(error))
                    }
                }
            }
        }
    }
}
