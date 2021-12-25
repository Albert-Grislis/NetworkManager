//
//  RawNetworkOperation.swift
//
//
//  Created by Albert Grislis on 13.02.2021.
//

import Foundation
import Utils

class RawNetworkOperation: Operation {
    
    // MARK: Internal properties
    let urlRequest: URLRequest
    private(set) var completionHandlersQueue: DispatchQueue
    @UnfairLock private(set) var rawNetowrkRequestCompletionHandlers: [RawNetworkRequestCompletionHandler]

    // MARK: Private properties
    private weak var urlSessionTaskProgressObserver: NetworkOperationProgressObservationProtocol?
    private let urlSession: URLSession
    private var urlSessionTask: URLSessionTask?
    
    // MARK: Initializers & Deinitializers
    init(urlSession: URLSession,
         urlRequest: URLRequest,
         completionHandlersQueue: DispatchQueue,
         rawNetowrkRequestCompletionHandlers: [RawNetworkRequestCompletionHandler]?,
         progressObserver: NetworkOperationProgressObservationProtocol?) {
        self.urlRequest = urlRequest
        self.completionHandlersQueue = completionHandlersQueue
        self.rawNetowrkRequestCompletionHandlers = rawNetowrkRequestCompletionHandlers ?? []
        self.urlSessionTaskProgressObserver = progressObserver
        self.urlSession = urlSession
        super.init()
    }
    
    // MARK: Internal methods
    override func main() {
        guard !self.isCancelled else {
            return
        }
        self.urlSessionTask = self.urlSession.dataTask(with: self.urlRequest) { [weak self] data, response, error in
            if let error = error {
                self?.complete(result: .failure(error))
            } else if let data = data {
                self?.complete(result: .success(data))
            }
        }
        if // urlSessionTaskProgressObserver exists
            let urlSesstiontask = self.urlSessionTask,
            let urlSessionTaskProgressObserver = self.urlSessionTaskProgressObserver {
            urlSessionTaskProgressObserver.observe(progress: urlSesstiontask.progress)
        }
        self.urlSessionTask?.resume()
    }
    
    override func cancel() {
        super.cancel()
        self.urlSessionTask?.cancel()
        self.urlSessionTaskProgressObserver?.invalidateNetworkOperationProgressObservation()
    }
    
    func appendCompletionHandlers(contentsOf sequence: [RawNetworkRequestCompletionHandler]) {
        if !self.isCancelled {
            self.rawNetowrkRequestCompletionHandlers.append(contentsOf: sequence)
        }
    }
    
    func removeLastCompletionHandler() {
        if !self.isCancelled {
            self.rawNetowrkRequestCompletionHandlers.removeLast()
        }
    }

    func complete(result: Result<Data, Error>) {
        if !self.isCancelled {
            self.completionHandlersQueue.sync { [weak self] in
                self?.rawNetowrkRequestCompletionHandlers.forEach { completionHandler in
                    completionHandler(result)
                }
            }
        }
    }
}
