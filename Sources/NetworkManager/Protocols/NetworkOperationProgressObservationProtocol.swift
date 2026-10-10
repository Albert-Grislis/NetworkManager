//
//  NetworkOperationProgressObservationProtocol.swift
//  NetworkManager
//
//  Created by Albert Grislis on 14.04.2021.
//

import Foundation

@preconcurrency
public protocol NetworkOperationProgressObservationProtocol: AnyObject & Sendable {

    // MARK: Public methods
    func observe(progress: Progress)
    func invalidateNetworkOperationProgressObservation()
}
