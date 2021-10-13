//
//  StorageManager.swift
//  FeedManager
//
//  Created by kwrsin on 2020/11/04.
//

import Foundation

public class StorageManager {
    private static var storageManager: StorageManager?
    public let storage: Storage
    public static let defaultServiceName = "_FEEDAGENTMANAGER_STORAGEMANAGER_SERVICE_"
    private init(_ type: StorageType = StorageType.None, _ service: String) {
        switch type {
        case .KeyChains:
            storage = KChanins(service)
        default:
            storage = UDefaults()
        }
    }
    public static func shared(_ type: StorageType = StorageType.UserDefaults, _ service: String = StorageManager.defaultServiceName) -> StorageManager {
        if let strageManager: StorageManager = StorageManager.storageManager {
            return strageManager
        }
        StorageManager.storageManager = StorageManager(type, service)
        return StorageManager.storageManager!
    }
}

//MARK: constants
extension StorageManager {
    public enum StorageType {
        case UserDefaults
        case KeyChains
        case None
    }
}

//MRAK: types
extension StorageManager {
    public typealias Properties = [String: Any]
}

//MARK: storages
public protocol Storage {
    var type: StorageManager.StorageType {get set}
    func loadProperties(key: String) -> StorageManager.Properties?
    func storeProperties(key: String, dict: StorageManager.Properties)
    func clearStorage(key: String)

}

public class UDefaults: Storage {
    public func clearStorage(key: String) {
        self.storeProperties(key: key, dict: [:])
    }
    
    public func loadProperties(key: String) -> [String : Any]? {
        UserDefaults.standard.dictionary(forKey: key)
    }
    
    public func storeProperties(key: String, dict: [String : Any]) {
        UserDefaults.standard.set(dict, forKey: key)
    }
    
    public var type: StorageManager.StorageType =
        StorageManager.StorageType.UserDefaults
    
}

//TODO: Key Chanins Not Implemented
public class KChanins: Storage {
    public func clearStorage(key: String) {
        try? secureStore.removeAllValues()
    }
    
    private let secureStore: SecureStore
    init(_ service: String) {
        secureStore = SecureStore(service: service)
    }
    public func loadProperties(key: String) -> [String : Any]? {
        guard let jsonBase64EncodedString = try? secureStore.getValue(for: key), let decodedData = Data(base64Encoded: jsonBase64EncodedString, options: []) else {
            return nil
        }
        
        let anyDict = try? JSONSerialization.jsonObject(with: decodedData, options: [])
        if let dict = anyDict as? [String : Any] {
            return dict
        }
        return nil
    }
    
    public func storeProperties(key: String, dict: [String : Any]) {
        let jsonData = try? JSONSerialization.data(withJSONObject: dict)
        if let jsonData = jsonData {
            try? secureStore.setValue(jsonData.base64EncodedString(options: []), for: key)
        }
    }

    public var type: StorageManager.StorageType =
        StorageManager.StorageType.KeyChains

}


