//
//  NetworkOperationProgressObservationProtocol.swift
//
//
//  Created by Albert Grislis on 14.04.2021.
//

import Foundation

public protocol NetworkOperationProgressObservationProtocol: AnyObject {

    // MARK: Public methods
    func observe(progress: Progress)
    func invalidateNetworkOperationProgressObservation()
}
