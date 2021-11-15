import Foundation

public class FeedAgentManager {
    public static var nonblocking_interval = 25.0
    private static var feedManager: FeedAgentManager?
    public let agent: Agent
    private init(_ agentType: FeedAgentManager.AgentType = FeedAgentManager.AgentType.Feedly,
                 _ storage: StorageManager.StorageType = StorageManager.StorageType.KeyChains) {
        func getConfigurations(
            type: FeedAgentManager.AgentType = FeedAgentManager.AgentType.Feedly) -> Dict? {
            guard let url = Bundle.module.url(forResource: "Configurations", withExtension: "plist") else {return nil}
            
            let data = try! Data(contentsOf: url)
            guard let plist = try! PropertyListSerialization.propertyList(from: data, options: .mutableContainers, format: nil) as? Dict else {return nil}
            switch type {
            default:
                let agents = plist["Agents"] as! Dict
                let configurantions = agents[type.rawValue] as! Dict
                return configurantions
            }
        }
        let configurations = getConfigurations(type: agentType)!
        switch agentType {
        case .Feedly:
            agent = Feedly(storageType: storage, configurations: configurations)
        default:
            agent = Feedly(storageType: storage, configurations: configurations)
        }
     }
    
    public static func shared(_ agentType: FeedAgentManager.AgentType = FeedAgentManager.AgentType.Feedly,
                              _ storage: StorageManager.StorageType = StorageManager.StorageType.KeyChains) -> FeedAgentManager {
        if let feedManager: FeedAgentManager = FeedAgentManager.feedManager, feedManager.agent.agentType == agentType {
           return feedManager
        }
        FeedAgentManager.feedManager = FeedAgentManager(agentType, storage)
        return FeedAgentManager.feedManager!
    }
    
    public static func removeFeedManage() {
        FeedAgentManager.feedManager = nil
    }
    
    public static func passedAuthentication(type: StorageManager.StorageType = .KeyChains, storageKey: String? = nil) -> Bool {
        let storageKey = Bundle.main.bundleIdentifier ?? storageKey ?? StorageManager.defaultServiceName
        let storage = StorageManager.shared(type, storageKey).storage
        guard Self.hasAppCredentials(), let props = storage.loadProperties(key: storageKey), let agentType = props["agent_type"] as? String, !agentType.isEmpty else {
            return false
        }
        return true
    }
    
    public static func hasAppCredentials(type: StorageManager.StorageType = .KeyChains, storageKey: String? = nil) -> Bool {
        let storageKey = Bundle.main.bundleIdentifier ?? storageKey ?? StorageManager.defaultServiceName
        let storage = StorageManager.shared(type, storageKey).storage
        let props = storage.loadProperties(key: storageKey) ?? [:]
        guard let client_id = props["client_id"] as? String, !client_id.isEmpty, let client_secret = props["client_secret"] as? String, !client_secret.isEmpty else {
            return false
        }
        return true
    }
    
    public static func setAppCredentials(credentials: (String, String), storageType: StorageManager.StorageType = .KeyChains, storageKey: String? = nil) {
        var props: StorageManager.Properties = [:]
        let storageKey = Bundle.main.bundleIdentifier ?? StorageManager.defaultServiceName
        let storage = StorageManager.shared(storageType, storageKey).storage
        props["client_id"] = credentials.0
        props["client_secret"] = credentials.1
        storage.storeProperties(key: storageKey, dict: props)
    }

    public static func setAgentType( agent_type: FeedAgentManager.AgentType, storageType: StorageManager.StorageType = .KeyChains, storageKey: String? = nil) {
        let storageKey = Bundle.main.bundleIdentifier ?? StorageManager.defaultServiceName
        let storage = StorageManager.shared(storageType, storageKey).storage
        var props = storage.loadProperties(key: storageKey) ?? [:]
        props["agent_type"] = agent_type.rawValue
        storage.storeProperties(key: storageKey, dict: props)
    }

    public static func getCurrentAgentType(type: StorageManager.StorageType = .KeyChains, storageKey: String? = nil) -> FeedAgentManager.AgentType {
        let storageKey = Bundle.main.bundleIdentifier ?? storageKey ?? StorageManager.defaultServiceName
        let storage = StorageManager.shared(type, storageKey).storage
        let props = storage.loadProperties(key: storageKey) ?? [:]
        guard let agent_type = props["agent_type"] as? String else {
            return .None
        }
        switch agent_type {
        case AgentType.Feedly.rawValue:
            return AgentType.Feedly
        case AgentType.Other.rawValue:
            return AgentType.Other
        default:
            return AgentType.None
        }
    }
}



//MARK: constants
extension FeedAgentManager {
    public enum ArticleType {
        case all
        case id(String)
        case ignoreNewerThan
    }

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
        data: Data, responseHeader: URLResponse?, error: Error?, rawData: Bool = false, completion: @escaping Completion) {
        do {
            if let responseHeader = responseHeader, isValidResponse(responseHeader: responseHeader) {
                if data.isEmpty {
                    completion(.success([:]))
                    return
                }
            }
            if rawData {
                completion(.success(data))
                return
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
        url: URL, params: Data? = nil, method: HttpMethod = .POST, concurrentType: ConcurrentType = .NonBlocking ,accessToken: String? = nil, contentType: FeedAgentManager.ContentType = .none, boundary: String? = nil, rawData: Bool = false, completion: @escaping Completion) {
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
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        
        let urlsession = URLSession(configuration: config)
        switch concurrentType {
        case .NonBlocking:
            urlsession.dataTask(with: request) { data, response, error in
                let data = data ?? Data()
                FeedAgentManager.process(data: data, responseHeader: response, error: error, rawData: rawData, completion: completion)
            }.resume()
        case .Blocking:
            let semaphore = DispatchSemaphore(value: 0)
            urlsession.dataTask(with: request) { data, response, error in
                let data = data ?? Data()
                FeedAgentManager.process(data: data, responseHeader: response, error: error, rawData: rawData, completion: completion)
                semaphore.signal()
            }.resume()
            if semaphore.wait(timeout: .now() + Self.nonblocking_interval) == .timedOut {
                completion(.failure(.connectionError("timeout")))
            }
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
        url: URL, params: Data? = nil, concurrentType: ConcurrentType = .NonBlocking, accessToken: String? = nil, contentType: ContentType = .none, rawData: Bool = false, completion: @escaping Completion) {
        FeedAgentManager.request(
            url: url, params: params, method: .GET, concurrentType: concurrentType, accessToken: accessToken, contentType:contentType, rawData: rawData, completion: completion)
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
    
    func getArticleId(_ articleType: FeedAgentManager.ArticleType) -> String
    func requestAccessToken() -> FeedAgentManager.FeedAgentResult
    func requestNewAccessToken() -> FeedAgentManager.FeedAgentResult
    func requestProfile() -> FeedAgentManager.FeedAgentResult
    func logout(clearForcing: Bool, completion: @escaping FeedAgentManager.Completion)
    func requestAllArticlesByPage(unreadOnly:Bool, concurrentType: FeedAgentManager.ConcurrentType,  articleType: FeedAgentManager.ArticleType, completion: @escaping FeedAgentManager.Completion)
    func requestMarking(entries: FeedAgentManager.Dict, type: FeedAgentManager.MarkingType, action: FeedAgentManager.MarkingAction, completion: @escaping FeedAgentManager.Completion)
    func requestUpdatingBoard(board: FeedAgentManager.Dict, tagId: String, completion: @escaping FeedAgentManager.Completion)
    func requestTagging(entries: FeedAgentManager.Dict, tagIds: FeedAgentManager.Array, completion: @escaping FeedAgentManager.Completion)
    func requestUnTagging(entryIds: FeedAgentManager.Array?, tagIds: FeedAgentManager.Array, completion: @escaping FeedAgentManager.Completion)
    func requestRenamingTag(tagId: String, label: String, completion: @escaping FeedAgentManager.Completion)
    func requestBoards(completion: @escaping FeedAgentManager.Completion)
    func requestSearching(params: FeedAgentManager.Dict, completion: @escaping FeedAgentManager.Completion)
    func requestAllSavedArticles(entries: FeedAgentManager.Dict, completion: @escaping FeedAgentManager.Completion)
    func initializeAgentProperties()
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
    
    init(storageType: StorageManager.StorageType, configurations: FeedAgentManager.Dict) {
        self.cfg = configurations
        let cfg_storageKey = cfg["storage_key"] as? String
        self.storageKey = Bundle.main.bundleIdentifier ?? cfg_storageKey ?? StorageManager.defaultServiceName
        self.storage = StorageManager.shared(storageType, self.storageKey).storage
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
        self.storage.clearStorage(key: self.storageKey)
    }
    
    func clear() {
        clearProperties()
        FeedAgentManager.removeFeedManage()
    }
    
    func store(result: FeedAgentManager.FeedAgentResult?) {
        if let result = result {
            switch result {
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
    var domain:String {cfg["domain"] as! String}
    var authenticationUrl:String {cfg["authentication_url"] as! String}
    var tokenUrl:String {cfg["token_url"] as! String}
    var logoutUrl:String {cfg["logout_url"] as! String}
    var responseType:String {cfg["response_type"] as! String}
    var scope:String {cfg["scope"] as! String}
    var redirectUrl:String {cfg["redirect_url"] as! String}
    var pageCount:Int {cfg["page_count"] as! Int}
    
    // properties
    public var clientId:String {props["client_id"] as! String}
    public var clientSecret:String {props["client_secret"] as! String}
    private var _accessToken:String? = nil
    public var accessToken:String? {
        get {_accessToken ?? props["access_token"] as? String} set {_accessToken = newValue}}
    public var refreshToken:String? {props["refresh_token"] as? String}
    private var _expiresIn:TimeInterval? = nil
    public var expiresIn:TimeInterval? {
        get {_expiresIn ?? props["expires_in"] as? TimeInterval} set {_expiresIn = newValue}}
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
    
    public func initializeAgentProperties() {
        continuation?.removeAll()
    }

    public func getArticleId(_ articleType: FeedAgentManager.ArticleType = .all) -> String {
        switch articleType {
        case .id(let identifier):
            return identifier
        default:
            return "user/\(userId!)/category/global.all"
        }
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
        if case .success(_) = faResult {
            store(result: faResult)
        } else {
            self.clear()
        }
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
        if case let .success(data) = faResult, let data = data as? StorageManager.Properties {
            let access_token = data["access_token"] as? String
            let expires_in = data["expires_in"] as? TimeInterval
            if let access_token = access_token, let expires_in = expires_in {
                    
                let newToken = ["access_token": access_token, "expires_in": expires_in] as [String : Any]
                store(result: FeedAgentManager.FeedAgentResult.success(newToken))
                self.accessToken = access_token
                self.expiresIn = expires_in
            }
        }
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

    public func logout(clearForcing: Bool = false, completion: @escaping FeedAgentManager.Completion) {
        FeedAgentManager.post(
            url: URL(
                string: self.logout_url)!, concurrentType: .NonBlocking, accessToken: self.bearerToken) { [weak self] result in
            switch result {
            case .success(_):
                self?.clear()
            case .failure(_):
                if clearForcing {
                    self?.clear()
                }
            }
            completion(result)
        }
    }

    public func requestAllArticlesByPage(unreadOnly: Bool = false, concurrentType: FeedAgentManager.ConcurrentType = .NonBlocking, articleType: FeedAgentManager.ArticleType = .all, completion: @escaping FeedAgentManager.Completion) {
        let streamId = getArticleId(articleType)
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
            if case .all = articleType {
                if let newerThan = props["entries_newerThan"] as? Int64, newerThan > 0 {
                    params["newerThan"] = "\(newerThan + 1)"
                }
            }
        }
        //TODO: rank?
        streams_url = buildURLwithParams(url: streams_url, params: params)
        FeedAgentManager.get(
            url: URL(
                string: streams_url)!, concurrentType: concurrentType, accessToken: self.bearerToken) {result in
            switch result {
            case .success(let dict as FeedAgentManager.Dict):
                if let continuation = dict["continuation"] as? String {
                    self.continuation = continuation
                } else {
                    if let newerThan = dict["updated"] as? Int64 {
                        if case .all = articleType {
                            self.updateProperties(properties: ["entries_newerThan": newerThan])
                        }
                    }
                    self.initializeAgentProperties()
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
    
    public func requestUnTagging(entryIds: FeedAgentManager.Array?, tagIds: FeedAgentManager.Array, completion: @escaping FeedAgentManager.Completion) {
        // https://stackoverflow.com/questions/41561853/couldnt-encode-plus-character-in-url-swift
        let entyIds =
            entryIds?.joined(separator: ",")
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!.replacingOccurrences(of: "&", with: "%26").replacingOccurrences(of: "+", with: "%2B") ?? ""
        let tagIds =
            tagIds.joined(separator: ",")
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!.replacingOccurrences(of: "&", with: "%26").replacingOccurrences(of: "+", with: "%2B")
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
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!.replacingOccurrences(of: "&", with: "%26").replacingOccurrences(of: "+", with: "%2B")
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
                .addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!.replacingOccurrences(of: "&", with: "%26").replacingOccurrences(of: "+", with: "%2B")
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
    
    public func requestSearching(params: FeedAgentManager.Dict, completion: @escaping FeedAgentManager.Completion) {
        let search_url = "https://\(domain)/v3/search/feeds"
        let search_with_params_url = buildURLwithParams(url: search_url, params: params)
        FeedAgentManager.get(
            url: URL(
                string: search_with_params_url)!, concurrentType: .NonBlocking, accessToken: self.bearerToken) {result in
            completion(result)
        }
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


