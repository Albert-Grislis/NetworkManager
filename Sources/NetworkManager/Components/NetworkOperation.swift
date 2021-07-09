//
//  NetworkOperation.swift
//
//
//  Created by Albert Grislis on 13.02.2021.
//

import Foundation
import Utils

final class NetworkOperation: Operation {
    
    // MARK: Public properties
    let urlRequest: URLRequest
    
    // MARK: Private properties
    private(set) var completionHandlersQueue: DispatchQueue
    @Atomic private(set) var completionHandlers: [NetworkCompletionHandler]
    private weak var urlSessionTaskProgressObserver: NetworkOperationProgressObservationProtocol?
    private let urlSession: URLSession
    private var urlSessionTask: URLSessionTask?
    
    // MARK: Initializers & Deinitializers
    init(urlSession: URLSession,
         urlRequest: URLRequest,
         completionHandlersQueue: DispatchQueue = .main,
         completionHandlers: [NetworkCompletionHandler]? = nil,
         progressObserver: NetworkOperationProgressObservationProtocol? = nil) {
        self.urlRequest = urlRequest
        self.completionHandlersQueue = completionHandlersQueue
        self.completionHandlers = completionHandlers ?? []
        self.urlSessionTaskProgressObserver = progressObserver
        self.urlSession = urlSession
        super.init()
    }
    
    // MARK: Public methods
    override func main() {
        guard !isCancelled else {
            return
        }
        urlSessionTask = urlSession.dataTask(with: urlRequest) { [weak self] data, response, error in
            if let error = error {
                self?.complete(result: .failure(error))
            } else if let data = data {
                self?.complete(result: .success(data))
            }
        }
        if // urlSessionTaskProgressObserver exists
            let urlSesstiontask = urlSessionTask,
            let urlSessionTaskProgressObserver = urlSessionTaskProgressObserver {
            let handler = urlSessionTaskProgressObserver.changeNetworkOperationProgressHandler
            let progressObserver = urlSesstiontask.progress.observe(\.fractionCompleted,
                                                                    options: .new,
                                                                    changeHandler: handler)
            urlSessionTaskProgressObserver.setNetworkOperationProgressObserver(to: progressObserver)
        }
        urlSessionTask?.resume()
    }
    
    override func cancel() {
        super.cancel()
        urlSessionTask?.cancel()
        urlSessionTaskProgressObserver?.invalidateNetworkOperationProgressObservation?()
    }
    
    func appendCompletionHandlers(contentsOf sequence: [NetworkCompletionHandler]) {
        if !isCancelled {
            completionHandlers.append(contentsOf: sequence)
        }
    }
    
    func removeLastCompletionHandler() {
        if !isCancelled {
            _ = completionHandlers.removeLast()
        }
    }
    
    // MARK: Private methods
    private func complete(result: Result<Data, Error>) {
        if !isCancelled {
            completionHandlersQueue.async { [weak self] in
                self?.completionHandlers.forEach { completionHandler in
                    completionHandler(result)
                }
            }
        }
    }
}
