//
//  NetworkOperationProgressObservationProtocol.swift
//  
//
//  Created by Albert Grislis on 14.04.2021.
//

import Foundation

public protocol NetworkOperationProgressObservationProtocol: AnyObject {
    
    // MARK: Public properties
    var changeNetworkOperationProgressHandler: (Progress, NSKeyValueObservedChange<Double>) -> Void { get }
    var invalidateNetworkOperationProgressObservation: (() -> Void)? { get }
    
    // MARK: Public methods
    func setNetworkOperationProgressObserver(to observer: NSKeyValueObservation)
}
