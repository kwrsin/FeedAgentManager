//
//  StrageManager.swift
//  FeedManager
//
//  Created by kwrsin on 2020/11/04.
//

import Foundation

public class StrageManager {
    private static var strageManager: StrageManager?
    public let strage: Strage
    private init(_ type: StrageType = StrageType.None) {
        switch type {
        case .KeyChains:
            strage = KChanins()
        default:
            strage = UDefaults()
        }
    }
    public static func shared(_ type: StrageType = StrageType.UserDefaults) -> StrageManager {
        if let strageManager: StrageManager = StrageManager.strageManager,
                                                strageManager.strage.type == type {
            return strageManager
        }
        StrageManager.strageManager = StrageManager(type)
        return StrageManager.strageManager!
    }
}

//MARK: constants
extension StrageManager {
    public enum StrageType {
        case UserDefaults
        case KeyChains
        case None
    }
    
}

//MRAK: types
extension StrageManager {
    public typealias Properties = [String: Any]
}

//MARK: strages
public protocol Strage {
    var type: StrageManager.StrageType {get set}
    func loadProperties(key: String) -> StrageManager.Properties?
    func storeProperties(key: String, dict: StrageManager.Properties)

}

public class UDefaults: Strage {
    public func loadProperties(key: String) -> [String : Any]? {
        UserDefaults.standard.dictionary(forKey: key)
    }
    
    public func storeProperties(key: String, dict: [String : Any]) {
        UserDefaults.standard.set(dict, forKey: key)
    }
    
    public var type: StrageManager.StrageType =
        StrageManager.StrageType.UserDefaults
    
}

//TODO: Key Chanins Not Implemented
public class KChanins: Strage {
    public func loadProperties(key: String) -> [String : Any]? {
        UserDefaults.standard.dictionary(forKey: key)
    }
    
    public func storeProperties(key: String, dict: [String : Any]) {
        UserDefaults.standard.set(dict, forKey: key)
    }

    public var type: StrageManager.StrageType =
        StrageManager.StrageType.KeyChains

}


