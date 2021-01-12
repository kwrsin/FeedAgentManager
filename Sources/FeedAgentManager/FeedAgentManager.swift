import Foundation

public class FeedAgentManager {
    private static var feedManager: FeedAgentManager?
    public let agent: Agent
    private init(_ type: FeedAgentManager.AgentType = FeedAgentManager.AgentType.Feedly,
                 _ storage: StorageManager.StorageType = StorageManager.StorageType.UserDefaults,
                 _ clientId:String? = nil,
                 _ clientSecret:String? = nil) {
        func getConfigurations(
            type: FeedAgentManager.AgentType = FeedAgentManager.AgentType.Feedly,
            clientId: String? = nil,
            clientSecret: String? = nil) -> Dict? {
            guard let url = Bundle.module.url(forResource: "Configurations", withExtension: "plist") else {return nil}
            
            let data = try! Data(contentsOf: url)
            guard let plist = try! PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: nil) as? Dict else {return nil}
            switch type {
            default:
                let agents = plist["Agents"] as! Dict
                var configurantions = agents[type.rawValue] as! Dict
                if let clientId = clientId, let clientSecret = clientSecret {
                    configurantions["client_id"] = configurantions["client_id"] ?? clientId
                    configurantions["client_secret"] = configurantions["client_secret"] ?? clientSecret
                }
                return configurantions
            }
        }
        let configurations = getConfigurations(
            clientId: clientId, clientSecret: clientSecret)!
        switch type {
        case .Feedly:
            agent = Feedly(type: storage, configurations: configurations)
        default:
            agent = Feedly(type: storage, configurations: configurations)
        }
     }
    
    public static func shared(_ type: FeedAgentManager.AgentType = FeedAgentManager.AgentType.Feedly,
                              _ storage: StorageManager.StorageType = StorageManager.StorageType.UserDefaults,
                              _ clientId: String? = nil,
                              _ clientSecret: String? = nil) -> FeedAgentManager {
        if let feedManager: FeedAgentManager = FeedAgentManager.feedManager, feedManager.agent.agentType == type {
           return feedManager
        }
        FeedAgentManager.feedManager = FeedAgentManager(
            type, storage, clientId, clientSecret)
        return FeedAgentManager.feedManager!
    }
}



//MARK: constants
extension FeedAgentManager {
    public enum AgentType: String {
        case Feedly
        case Other
        case None
    }
    
    public enum FeedError: Error {
//        case disconnectedError(String)
//        case notFoundError(String)
//        case parseError(String)
        case requestError(String)
        case responseError(Dict)
        case connectionError(String)
        case parameterError
        case unknownError
    }
    
    public enum FeedResponse {
        case success
    }
    
    public enum HttpMethod: String {
        case GET
        case POST
        case PUT
        case DELETE
    }
    
    public enum ResultType {
        case Single
        case Multiple
    }
    
    public enum ConcurrentType {
        case Blocking
        case NonBlocking
    }

    public enum MarkingAction:String {
        case markAsRead
        case keepUnread
        case undoMarkAsRead
        case markAsSaved
        case markAsUnsaved
        
    }
    
    public enum MarkingType:String {
        case entries
        case feeds
        case categories
        case tags
    }
    
    public enum ContentType {
        case json
        case multipart
        case none
    }

}

//MARK: utilities
extension FeedAgentManager {
    public typealias Dict = [String: Any]
    public typealias Array = [String]
    public typealias DictInArray = [Dict]
    public typealias _URL = URL
    public typealias FeedAgentResult = Result<Any, FeedAgentManager.FeedError>
    public typealias Completion = (FeedAgentResult) -> Void
    public typealias Attachment =  (data: Data, filename: String, mimeType: String)
    public static func getResponseError(values: Any) -> Dict? {
        let errors = values as? Dict ?? [:]
        if errors["errorCode"] != nil {
            return errors
        }
        return nil
    }
    
    public static func isValidResponse(responseHeader: URLResponse) -> Bool {
        if let responseHeader = responseHeader as? HTTPURLResponse {
            return responseHeader.statusCode >= 200 && responseHeader.statusCode < 300
        }
        return false;
    }
    
    public static func process(
        data: Data, responseHeader: URLResponse?, error: Error?, completion: @escaping Completion) {
        do {
            if let responseHeader = responseHeader, isValidResponse(responseHeader: responseHeader) {
                if data.isEmpty {
                    completion(.success([:]))
                    return
                }
            }

            let values = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
            if let responseHeader = responseHeader, isValidResponse(responseHeader: responseHeader) == false {
                if let error = error {
                    completion(.failure(FeedError.requestError(error.localizedDescription)))
                } else {
                    if let errors = FeedAgentManager.getResponseError(values: values) {
                        completion(.failure(FeedError.responseError(errors)))
                    } else {
                        completion(.failure(FeedError.unknownError))
                    }
                }
                return
            }
            completion(.success(values))
//            switch resultType {
//            case .MULTIPLE:
//                var dict: Dict = Dict()
//                dict["Array"] = values as? [Any] ?? []
//                completion(.success(dict))
//
//            case .SINGLE:
//                completion(.success(values as? Dict ?? [:]))
//            }

        } catch(let error) {
            completion(.failure(FeedError.connectionError(error.localizedDescription)))
        }
    }
    
    public static func request(
        url: URL, params: Data? = nil, method: HttpMethod = .POST, concurrentType: ConcurrentType = .NonBlocking ,accessToken: String? = nil, contentType: FeedAgentManager.ContentType = .none, boundary: String? = nil, completion: @escaping Completion) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        switch contentType {
        case .json:
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .multipart:
            if let boundary = boundary, let params = params {
                request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                request.setValue("\(params.count)", forHTTPHeaderField: "Content-Length")
            }
        default:
            break
        }
        
        if let accessToken = accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = method.rawValue
        request.httpBody = params
        switch concurrentType {
        case .NonBlocking:
            URLSession.shared.dataTask(with: request) { data, response, error in
                DispatchQueue.main.async {
                    let data = data ?? Data()
                    FeedAgentManager.process(data: data, responseHeader: response, error: error, completion: completion)
                }
            }.resume()
        case .Blocking:
            let semaphore = DispatchSemaphore(value: 0)
            URLSession.shared.dataTask(with: request) { data, response, error in
                let data = data ?? Data()
                FeedAgentManager.process(data: data, responseHeader: response, error: error, completion: completion)
                semaphore.signal()
            }.resume()
            _ = semaphore.wait(wallTimeout: .distantFuture)//TODO: need timers
        }
    }
    
    public static func post(
        url: URL, params: Data? = nil, concurrentType: ConcurrentType = .NonBlocking, accessToken: String? = nil, contentType: ContentType = .none, boundary: String? = nil, completion: @escaping Completion) {
        FeedAgentManager.request(
            url: url, params: params, method: .POST, concurrentType: concurrentType, accessToken: accessToken, contentType: contentType, boundary: boundary, completion: completion)
    }

    public static func put(
        url: URL, params: Data? = nil, concurrentType: ConcurrentType = .NonBlocking, accessToken: String? = nil, contentType: ContentType = .none, completion: @escaping Completion) {
        FeedAgentManager.request(
            url: url, params: params, method: .PUT, concurrentType: concurrentType, accessToken: accessToken, contentType: contentType, completion: completion)
    }

    public static func delete(
        url: URL, params: Data? = nil, concurrentType: ConcurrentType = .NonBlocking, accessToken: String? = nil, contentType: ContentType = .none, completion: @escaping Completion) {
        FeedAgentManager.request(
            url: url, params: params, method: .DELETE, concurrentType: concurrentType, accessToken: accessToken, contentType: contentType, completion: completion)
    }

    public static func get(
        url: URL, params: Data? = nil, concurrentType: ConcurrentType = .NonBlocking, accessToken: String? = nil, contentType: ContentType = .none, completion: @escaping Completion) {
        FeedAgentManager.request(
            url: url, params: params, method: .GET, concurrentType: concurrentType, accessToken: accessToken, contentType:contentType, completion: completion)
    }

}

//MARK: Agents
public protocol Agent {
    var agentType: FeedAgentManager.AgentType {get set}
    func handleURL(url: URL) -> FeedAgentManager.FeedAgentResult
    func isRedirected() -> Bool
    var endpoint_url: String {get}
    var access_token_url: String {get}
    var accessToken:String? {get}
    var bearerToken:String? {get}
    var refreshToken:String? {get}
    var expiresIn:TimeInterval? {get}
    var isExpired: Bool {get}
    var userId:String? {get}
    var attachmentName:String? {get}
    
    func requestAccessToken() -> FeedAgentManager.FeedAgentResult
    func requestNewAccessToken() -> FeedAgentManager.FeedAgentResult
    func requestProfile() -> FeedAgentManager.FeedAgentResult
    func logout(completion: @escaping FeedAgentManager.Completion)
    func requestAllArticlesByPage(unreadOnly:Bool, completion: @escaping FeedAgentManager.Completion)
    func requestMarking(entries: FeedAgentManager.Dict, type: FeedAgentManager.MarkingType, action: FeedAgentManager.MarkingAction, completion: @escaping FeedAgentManager.Completion)
    func requestUpdatingBoard(board: FeedAgentManager.Dict, tagId: String, completion: @escaping FeedAgentManager.Completion)
    func requestTagging(entries: FeedAgentManager.Dict, tagIds: FeedAgentManager.Array, completion: @escaping FeedAgentManager.Completion)
    func requestUnTagging(entyIds: FeedAgentManager.Array?, tagIds: FeedAgentManager.Array, completion: @escaping FeedAgentManager.Completion)
    func requestRenamingTag(tagId: String, label: String, completion: @escaping FeedAgentManager.Completion)
    func requestBoards(completion: @escaping FeedAgentManager.Completion)
    func requestSearching(entries: FeedAgentManager.Dict, completion: @escaping FeedAgentManager.Completion)
    func requestAllSavedArticles(entries: FeedAgentManager.Dict, completion: @escaping FeedAgentManager.Completion)
    func requestUpdatingCategory(category: FeedAgentManager.Dict, categoryId: String, completion: @escaping FeedAgentManager.Completion)
    func requestAppendingFeedsToCategory(feeds: FeedAgentManager.DictInArray, categoryId: String, completion: @escaping FeedAgentManager.Completion)
    func requestRemovingFeedsToCategory(feeds: FeedAgentManager.DictInArray, categoryId: String, keepFeeds: Bool, completion: @escaping FeedAgentManager.Completion)
    func requestCategories(_ params: FeedAgentManager.Dict?, completion: @escaping FeedAgentManager.Completion)
    func requestRemovingCategory(categoryId: String, completion: @escaping FeedAgentManager.Completion)
    func uploadImage(path: String, params: FeedAgentManager.Dict?, attachment: FeedAgentManager.Attachment, id: String, completion: @escaping FeedAgentManager.Completion)
}

public class FeedAgent {
    let storage: Storage
    let cfg: FeedAgentManager.Dict
    let storageKey: String
    var props: StorageManager.Properties
    
    init(type: StorageManager.StorageType, configurations: FeedAgentManager.Dict) {
        self.storage = StorageManager.shared(type).storage
        self.cfg = configurations
        self.storageKey = cfg["storage_key"] as! String
        self.props = self.storage.loadProperties(key: self.storageKey) ?? [:]
    }
    
    func updateProperties(properties: StorageManager.Properties, needCreateAt: Bool = false) {
        props = props.merging(properties){$1}
        if needCreateAt {
            props["created_at"] = Date.timeIntervalSinceReferenceDate
        }
        self.storage.storeProperties(key: self.storageKey, dict: props)
    }
        
    func clearProperties() {
        props.removeAll()
        self.storage.storeProperties(key: self.storageKey, dict: props)
    }
    
    func clear(result: FeedAgentManager.FeedAgentResult?) {
        if let result = result {
            switch result {
            case .success(_):
                clearProperties()
            case .failure(_):
                break
            }
        }
    }
    
    func store(result: FeedAgentManager.FeedAgentResult?) {
        if let resut = result {
            switch resut {
            case .success(let dict):
                updateProperties(properties: dict as! StorageManager.Properties, needCreateAt: true)
            case .failure(_):
                break
            }
        }
    }
    
    func buildURLwithParams(url: String, params: FeedAgentManager.Dict) -> String {
        let params = params.toParameters(needEncoding: true)
        return url.appending("/?\(params)")
    }
    
    func generateBoundaryString() -> String {
        return "------------------------------\(UUID().uuidString)"
    }
    
    func generateMultipartData(boundary: String, params: FeedAgentManager.Dict?, attachmentName:String, attachment: FeedAgentManager.Attachment) -> Data {
        let lineBreak = "\r\n"
        var requestData = Data()
        
        requestData.append("--\(boundary + lineBreak)".data(using: .utf8)!)
        requestData.append("content-disposition: form-data; name=\"\(attachmentName)\" ; filename=\"\(attachment.filename)\"\(lineBreak)".data(using: .utf8)!)
//        requestData.append("content-type: \(attachment.mimetype)\(lineBreak)".data(using: .utf8)!)
        requestData.append("\(lineBreak)".data(using: .utf8)!)
        requestData.append(attachment.data)
        
        requestData.append("\(lineBreak)".data(using: .utf8)!)
        if let params = params {
            for (key, value) in params {
                requestData.append("--\(boundary + lineBreak)".data(using: .utf8)!)
                requestData.append("content-disposition: form-data; name=\"\(key)\"\(lineBreak + lineBreak)".data(using: .utf8)!)
                requestData.append("\(value)\(lineBreak)".data(using: .utf8)!)
            }
        }
        requestData.append("--\(boundary)--\(lineBreak)" .data(using: .utf8)!)
//        print(String(decoding: requestData, as: UTF8.self))
        return requestData
    }
}

//MARK: Feedly
public class Feedly: FeedAgent, Agent {
    public var attachmentName: String? = "cover"
    // configurations
    var clientId:String {cfg["client_id"] as! String}
    var clientSecret:String {cfg["client_secret"] as! String}
    var domain:String {cfg["domain"] as! String}
    var authenticationUrl:String {cfg["authentication_url"] as! String}
    var tokenUrl:String {cfg["token_url"] as! String}
    var logoutUrl:String {cfg["logout_url"] as! String}
    var responseType:String {cfg["response_type"] as! String}
    var scope:String {cfg["scope"] as! String}
    var redirectUrl:String {cfg["redirect_url"] as! String}
    var pageCount:Int {cfg["page_count"] as! Int}
    
    // properties
    public var accessToken:String? {props["access_token"] as? String}
    public var refreshToken:String? {props["refresh_token"] as? String}
    public var expiresIn:TimeInterval? {props["expires_in"] as? TimeInterval}
    public var createdAt:TimeInterval? {props["created_at"] as? TimeInterval}
    public var tokenType:String? {props["token_type"] as? String}
    public var bearerToken:String? {get {
        if let accessToken = accessToken, let tokenType = tokenType {
            return "\(tokenType.capitalized) \(accessToken)"
        }
        return nil
    }}
    public var userId:String? {props["id"] as? String}
    var continuation:String? = nil

    // response parameters
    var state: String { //TODO: not implemented yet
        get {
            if let params = redirectParams, let state = params["state"] as? String {
                return state
            } else if let state = props["state"] as? String {
                return state
            }
            return ""
        }
    }
    var code: String {
        get {
            if let params = redirectParams, let code = params["code"] as? String {
                return code
            }
            return ""
        }
    }
    var redirectParams: FeedAgentManager.Dict?

    public var endpoint_url: String {
        get {
            let url = "https://\(self.domain)/\(self.authenticationUrl)"
            let params:FeedAgentManager.Dict = [
                "client_id": "\(self.clientId)",
                "redirect_uri": "\(self.redirectUrl)",
                "response_type": "\(self.responseType)",
                "scope": "\(self.scope)",
                "state": "\(self.state)"
            ]

            return buildURLwithParams(url: url, params: params)
        }
    }
    
    public var access_token_url: String {
        "https://\(domain)/\(self.tokenUrl)"
    }
    
    public var logout_url: String {
        "https://\(domain)/\(self.logoutUrl)"
    }
    
    var tags_url: String {
        "https://\(domain)/v3/tags"
    }
    
    var boards_url: String {
        "https://\(domain)/v3/boards"
    }
    
    var categories_url: String {
        "https://\(domain)/v3/collections"
    }
    
    public var agentType: FeedAgentManager.AgentType =
        FeedAgentManager.AgentType.Feedly
    
    public var isExpired: Bool {
        guard let expiresIn = expiresIn, let createdAt = createdAt else {
            return true
        }
        return Date.timeIntervalSinceReferenceDate > createdAt + expiresIn
    }

    public func isRedirected() -> Bool {
        if let params = self.redirectParams {
            return params["error"] == nil
        }
        return false
    }
    
    public func handleURL(url: FeedAgentManager._URL) -> FeedAgentManager.FeedAgentResult {
        self.redirectParams = url.toDictionary()
        guard isRedirected() else {
            return Result.failure(FeedAgentManager.FeedError.parameterError)
        }
        return requestAccessToken()
    }
    
    public func requestAccessToken() -> FeedAgentManager.FeedAgentResult {
        let params:FeedAgentManager.Dict = [
            "client_id": "\(self.clientId)",
            "client_secret": "\(self.clientSecret)",
            "redirect_uri": "\(self.redirectUrl)",
            "code": "\(self.code)",
            "state": "\(self.state)",
            "grant_type": "authorization_code"
        ]
        var faResult: FeedAgentManager.FeedAgentResult?
        FeedAgentManager.post(
            url: URL(
                string: self.access_token_url)!, params: params.toParameters().data(using: .utf8), concurrentType: .Blocking) { result in
            faResult = result
        }
        store(result: faResult)
        return faResult!
    }

    public func requestNewAccessToken() -> FeedAgentManager.FeedAgentResult {
        let params:FeedAgentManager.Dict = [
            "client_id": "\(self.clientId)",
            "client_secret": "\(self.clientSecret)",
            "refresh_token": "\(self.refreshToken!)",
            "grant_type": "refresh_token",
        ]

        var faResult: FeedAgentManager.FeedAgentResult?
        FeedAgentManager.post(
            url: URL(
                string: self.access_token_url)!, params: params.toParameters().data(using: .utf8), concurrentType: .Blocking) { result in
            faResult = result
        }
        store(result: faResult)
        return faResult!
    }
    
    public func requestProfile() -> FeedAgentManager.FeedAgentResult {
        let profile_url: String =
            "https://\(domain)/v3/profile"
        var faResult: FeedAgentManager.FeedAgentResult?
        FeedAgentManager.get(
            url: URL(
                string: profile_url)!, concurrentType: .Blocking, accessToken: self.bearerToken) { result in
            faResult = result
        }
        store(result: faResult)
        return faResult!
    }

    public func logout(completion: @escaping FeedAgentManager.Completion) {
        FeedAgentManager.post(
            url: URL(
                string: self.logout_url)!, concurrentType: .NonBlocking, accessToken: self.bearerToken) { [weak self] result in
            switch result {
            case .success(_):
                self?.clear(result: result)
            case .failure(_):
                break
            }
            completion(result)
        }
    }

    public func requestAllArticlesByPage(unreadOnly: Bool = false, completion: @escaping FeedAgentManager.Completion) {
        let streamId = "user/\(userId!)/category/global.all"
        var streams_url: String =
            "https://\(domain)/v3/streams/contents"
        var params = [
            "streamId": streamId,
            "count": "\(self.pageCount)"]
        if unreadOnly == true {
            params["unreadOnly"] = "true"
        }
        if let continuation = continuation, continuation.isEmpty == false {
            params["continuation"] = continuation
        } else {
            //TODO: need preventNewerThan?
            if let newerThan = props["entries_newerThan"] as? Int64, newerThan > 0 {
                params["newerThan"] = "\(newerThan + 1)"
            }
        }
        //TODO: rank?
        streams_url = buildURLwithParams(url: streams_url, params: params)
        FeedAgentManager.get(
            url: URL(
                string: streams_url)!, concurrentType: .NonBlocking, accessToken: self.bearerToken) {result in
            switch result {
            case .success(let dict as FeedAgentManager.Dict):
                if let continuation = dict["continuation"] as? String {
                    self.continuation = continuation
                } else {
                    if let newerThan = dict["updated"] as? Int64 {
                        self.updateProperties(properties: ["entries_newerThan": newerThan])
                    }
                    self.continuation?.removeAll()
                }
            default:
                break
            }
            completion(result)
        }
    }
    
    public func requestMarking(entries: FeedAgentManager.Dict, type: FeedAgentManager.MarkingType, action: FeedAgentManager.MarkingAction, completion: @escaping FeedAgentManager.Completion) {
        let markers_url: String =
            "https://\(domain)/v3/markers"
        var params = FeedAgentManager.Dict()
        params = params.merging(entries){$1}
        params["action"] = action.rawValue
        params["type"] = type.rawValue
       
        let json:Data? = params.toJSON()

        FeedAgentManager.post(
            url: URL(
                string: markers_url)!, params: json, concurrentType: .NonBlocking, accessToken: self.bearerToken, contentType: .json) {result in
            completion(result)
        }
    }
    
    public func requestUpdatingBoard(board: FeedAgentManager.Dict, tagId: String = "", completion: @escaping FeedAgentManager.Completion) {
        let tagId = tagId
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let boards_url: String =
            "\(self.boards_url)/\(tagId)"

        let json = board.toJSON()

        FeedAgentManager.post(
            url: URL(
                string: boards_url)!, params: json, concurrentType: .NonBlocking, accessToken: self.bearerToken, contentType: .json) {result in
            completion(result)
        }
    }
    
    public func requestTagging(entries: FeedAgentManager.Dict, tagIds: FeedAgentManager.Array, completion: @escaping FeedAgentManager.Completion) {
        let tagIds =
            tagIds.joined(separator: ",")
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let tags_url: String =
            "\(self.tags_url)/\(tagIds)"

        let json = entries.toJSON()

        FeedAgentManager.put(
            url: URL(
                string: tags_url)!, params: json, concurrentType: .NonBlocking, accessToken: self.bearerToken, contentType: .json) {result in
            completion(result)
        }
    }
    
    public func requestUnTagging(entyIds: FeedAgentManager.Array?, tagIds: FeedAgentManager.Array, completion: @escaping FeedAgentManager.Completion) {
        let entyIds =
            entyIds?.joined(separator: ",")
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)! ?? ""
        let tagIds =
            tagIds.joined(separator: ",")
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let tags_url: String =
            "\(self.tags_url)/\(tagIds)/\(entyIds)"
                
        FeedAgentManager.delete(
            url: URL(
                string: tags_url)!, concurrentType: .NonBlocking, accessToken: self.bearerToken, contentType: .json) {result in
            completion(result)
        }

    }
    
    public func requestRenamingTag(tagId: String = "", label: String, completion: @escaping FeedAgentManager.Completion) {
        //CAUSION: set the tagId paramter to empty string, if you will create a new tag.
        let tags_url: String =
            "\(self.tags_url)/\(tagId.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)"
        let params:FeedAgentManager.Dict = ["label": label]
        
        let json = params.toJSON()

        FeedAgentManager.post(
            url: URL(
                string: tags_url)!, params: json, concurrentType: .NonBlocking, accessToken: self.bearerToken, contentType: .json) {result in
            completion(result)
        }

    }
    
    public func requestBoards(completion: @escaping FeedAgentManager.Completion) {
        FeedAgentManager.get(
            url: URL(
                string: boards_url)!, concurrentType: .NonBlocking, accessToken: self.bearerToken) {result in
            completion(result)
        }
    }
    
    public func requestUpdatingCategory(category: FeedAgentManager.Dict, categoryId: String = "", completion: @escaping FeedAgentManager.Completion) {
        let categoryId = categoryId
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let categories_url: String =
            "\(self.categories_url)/\(categoryId)"

        let json = category.toJSON()

        FeedAgentManager.post(
            url: URL(
                string: categories_url)!, params: json, concurrentType: .NonBlocking, accessToken: self.bearerToken, contentType: .json) {result in
            completion(result)
        }
    }
    
    public func requestAppendingFeedsToCategory(feeds: FeedAgentManager.DictInArray, categoryId: String, completion: @escaping FeedAgentManager.Completion) {
        let categoryId = categoryId
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let categories_url: String =
            "\(self.categories_url)/\(categoryId)/feeds/.mput"

        let json = feeds.toJSON()

        FeedAgentManager.post(
            url: URL(
                string: categories_url)!, params: json, concurrentType: .NonBlocking, accessToken: self.bearerToken, contentType: .json) {result in
            completion(result)
        }
    }
    
    public func requestRemovingFeedsToCategory(feeds: FeedAgentManager.DictInArray, categoryId: String, keepFeeds: Bool = false, completion: @escaping FeedAgentManager.Completion) {
        let categoryId = categoryId
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        var categories_url: String =
            "\(self.categories_url)/\(categoryId)/feeds/.mdelete"
        let params = ["keepOrphanFeeds": keepFeeds]
        categories_url = buildURLwithParams(url: categories_url, params: params)
        let json = feeds.toJSON()

        FeedAgentManager.delete(
            url: URL(
                string: categories_url)!, params: json, concurrentType: .NonBlocking, accessToken: self.bearerToken, contentType: .json) {result in
            completion(result)
        }

    }

    public func requestRemovingCategory(categoryId: String, completion: @escaping FeedAgentManager.Completion) {
        var category_url = "https://\(domain)/v3/categories"
        let categoryId = categoryId
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        category_url = "\(category_url)/\(categoryId)"

        FeedAgentManager.delete(
            url: URL(
                string: category_url)!, concurrentType: .NonBlocking, accessToken: self.bearerToken, contentType: .json) {result in
            completion(result)
        }
    }

    public func requestCategories(_ params: FeedAgentManager.Dict? = nil, completion: @escaping FeedAgentManager.Completion) {
        var categories_url = "\(self.categories_url)"
        if let params = params {
            categories_url = buildURLwithParams(url: categories_url, params: params)
        }

        FeedAgentManager.get(
            url: URL(
                string: categories_url)!, concurrentType: .NonBlocking, accessToken: self.bearerToken) {result in
            completion(result)
        }
    }
    
    public func uploadImage(path: String, params: FeedAgentManager.Dict?, attachment: FeedAgentManager.Attachment, id: String, completion: @escaping FeedAgentManager.Completion) {
        let id = id
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        let upload_url: String =
            "https://\(domain)/\(path)/\(id)"
        let boundary = generateBoundaryString()
        let multipleData = generateMultipartData(boundary: boundary, params: params, attachmentName: attachmentName!, attachment: attachment)

        FeedAgentManager.post(
            url: URL(
                string: upload_url)!, params: multipleData, concurrentType: .NonBlocking, accessToken: self.bearerToken, contentType: .multipart, boundary: boundary) {result in
            completion(result)
        }
    }
    
    public func requestSearching(entries: FeedAgentManager.Dict, completion: @escaping FeedAgentManager.Completion) {
        
    }
    
    public func requestAllSavedArticles(entries: FeedAgentManager.Dict, completion: @escaping FeedAgentManager.Completion) {
        
    }


}

//MARK: BUILTIN EXTENSIONS
extension FeedAgentManager._URL {
    func toDictionary() -> FeedAgentManager.Dict {
        var dict = FeedAgentManager.Dict()
        if let components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            if let items = components.queryItems {
                for item in items {
                    dict[item.name] = item.value!
                }
            }
            return dict
        }
        return dict
    }
}

extension FeedAgentManager.Dict {
    func toParameters(needEncoding: Bool = false) -> String {
        var params = [String]()
        self.forEach() {key, value in
            params.append("\(key)=\(value)")
        }
        if needEncoding {
            return params.joined(separator: "&")
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
        }
        return params.joined(separator: "&")
    }
    
    func toJSON() -> Data? {
        var json:Data? = nil
        do {
            json = try JSONSerialization.data(withJSONObject: self, options: [])
        } catch (_) {
            return nil
        }
        return json
    }
}

extension FeedAgentManager.DictInArray {
    func toJSON() -> Data? {
        var json:Data? = nil
        do {
            json = try JSONSerialization.data(withJSONObject: self, options: [])
        } catch (_) {
            return nil
        }
        return json
    }
}


