//
//  NetworkOperationProgressObservationProtocol.swift
//  
//
//  Created by Albert Grislis on 14.04.2021.
//

import Foundation

public protocol NetworkOperationProgressObservationProtocol: class {
    var changeNetworkOperationProgressHandler: (Progress, NSKeyValueObservedChange<Double>) -> Void { get }
    var invalidateNetworkOperationProgressObservation: (() -> Void)? { get }
    
    func setNetworkOperationProgressObserver(to observer: NSKeyValueObservation)
}
