//
//  SecureStore.swift
//  FeedReader
//
//  Created by kwrsin on 2021/10/13.
//
//ref: https://www.raywenderlich.com/9240-keychain-services-api-tutorial-for-passwords-in-swift#toc-anchor-003

import Foundation
import Security

struct SecureStore {
    let query: [String: Any]
    
    init(service: String, accessGroup: String? = nil) {
        var _query: [String: Any] = [
            String(kSecClass) : kSecClassGenericPassword,
            String(kSecAttrService) : service,
        ]
        #if targetEnvironment(simulator)
        if let accessGroup = accessGroup {
            _query[String(kSecAttrAccessGroup)] = accessGroup
        }
        #endif
        query = _query
    }
    
    public func setValue(_ value: String, for userAccount: String) throws {
        guard let encodedPassword = value.data(using: .utf8) else {
          throw SecureStoreError.string2DataConversionError
        }
        
        var query = query
        query[String(kSecAttrAccount)] = userAccount

        var status = SecItemCopyMatching(query as CFDictionary, nil)

        //https://developer.apple.com/forums/thread/7961
        //https://developer.apple.com/forums/thread/78372
        query[String(kSecAttrAccessible)] = kSecAttrAccessibleAfterFirstUnlock
        switch status {
        case errSecSuccess:
          var attributesToUpdate: [String: Any] = [:]
          attributesToUpdate[String(kSecValueData)] = encodedPassword
          
          status = SecItemUpdate(query as CFDictionary,
                                 attributesToUpdate as CFDictionary)
          if status != errSecSuccess {
            throw error(from: status)
          }
        case errSecItemNotFound:
          query[String(kSecValueData)] = encodedPassword
          
          status = SecItemAdd(query as CFDictionary, nil)
          if status != errSecSuccess {
            throw error(from: status)
          }
        default:
          throw error(from: status)
        }
      }
      
      public func getValue(for userAccount: String) throws -> String? {
        var query = query
        query[String(kSecMatchLimit)] = kSecMatchLimitOne
        query[String(kSecReturnAttributes)] = kCFBooleanTrue
        query[String(kSecReturnData)] = kCFBooleanTrue
        query[String(kSecAttrAccount)] = userAccount
        
        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
          SecItemCopyMatching(query as CFDictionary, $0)
        }
        
        switch status {
        case errSecSuccess:
          guard
            let queriedItem = queryResult as? [String: Any],
            let passwordData = queriedItem[String(kSecValueData)] as? Data,
            let password = String(data: passwordData, encoding: .utf8)
            else {
              throw SecureStoreError.data2StringConversionError
          }
          return password
        case errSecItemNotFound:
          return nil
        default:
          throw error(from: status)
        }
      }
      
      public func removeValue(for userAccount: String) throws {
        var query = query
        query[String(kSecAttrAccount)] = userAccount
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
          throw error(from: status)
        }
      }
      
      public func removeAllValues() throws {
        let query = query
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
          throw error(from: status)
        }
      }
      
      private func error(from status: OSStatus) -> SecureStoreError {
        var message = ""
        if #available(iOS 11.3, *) {
            message = SecCopyErrorMessageString(status, nil) as String? ?? NSLocalizedString("Unhandled Error", comment: "")
        } else {
            message = NSLocalizedString("Version Error", comment: "")
        }
        return SecureStoreError.unhandledError(message: message)
      }

}

public enum SecureStoreError: Error {
  case string2DataConversionError
  case data2StringConversionError
  case unhandledError(message: String)
}

