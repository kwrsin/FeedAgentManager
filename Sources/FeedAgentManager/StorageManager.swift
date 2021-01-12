//
//  StrageManager.swift
//  FeedManager
//
//  Created by kwrsin on 2020/11/04.
//

import Foundation

public class StorageManager {
    private static var storageManager: StorageManager?
    public let storage: Storage
    private init(_ type: StorageType = StorageType.None) {
        switch type {
        case .KeyChains:
            storage = KChanins()
        default:
            storage = UDefaults()
        }
    }
    public static func shared(_ type: StorageType = StorageType.UserDefaults) -> StorageManager {
        if let strageManager: StorageManager = StorageManager.storageManager,
                                                strageManager.storage.type == type {
            return strageManager
        }
        StorageManager.storageManager = StorageManager(type)
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

}

public class UDefaults: Storage {
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
    public func loadProperties(key: String) -> [String : Any]? {
        UserDefaults.standard.dictionary(forKey: key)
    }
    
    public func storeProperties(key: String, dict: [String : Any]) {
        UserDefaults.standard.set(dict, forKey: key)
    }

    public var type: StorageManager.StorageType =
        StorageManager.StorageType.KeyChains

}


