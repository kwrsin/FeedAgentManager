import Foundation

public class FeedAgentManager {
    private static var feedManager: FeedAgentManager?
    public let agent: Agent
    private init(_ type: FeedAgentManager.AgentType = FeedAgentManager.AgentType.Feedly,
                 _ strage: StrageManager.StrageType = StrageManager.StrageType.UserDefaults,
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
            agent = Feedly(type: strage, configurations: configurations)
        default:
            agent = Feedly(type: strage, configurations: configurations)
        }
     }
    
    public static func shared(_ type: FeedAgentManager.AgentType = FeedAgentManager.AgentType.Feedly,
                              _ strage: StrageManager.StrageType = StrageManager.StrageType.UserDefaults,
                              _ clientId: String? = nil,
                              _ clientSecret: String? = nil) -> FeedAgentManager {
        if let feedManager: FeedAgentManager = FeedAgentManager.feedManager, feedManager.agent.agentType == type {
           return feedManager
        }
        FeedAgentManager.feedManager = FeedAgentManager(
            type, strage, clientId, clientSecret)
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
    
}

//MARK: utilities
extension FeedAgentManager {
    public typealias Dict = [String: Any]
    public typealias FeedAgentResult = Result<Any, FeedAgentManager.FeedError>
    public typealias Completion = (FeedAgentResult) -> Void

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
        url: URL, params: Data? = nil, method: HttpMethod = .POST, concurrentType: ConcurrentType = .NonBlocking ,accessToken: String? = nil, completion: @escaping Completion) {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if method == .GET {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken = accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }
        request.httpMethod = method.rawValue
        request.httpBody = params
//        request.httpBody = params.data(using: String.Encoding.utf8)//TODO: 変更 GETの場合？
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
            _ = semaphore.wait(wallTimeout: .distantFuture)//TODO: 時間指定が必要かも・・
        }
    }
    
    public static func post(
        url: URL, params: Data? = nil, concurrentType: ConcurrentType = .NonBlocking, accessToken: String? = nil, completion: @escaping Completion) {
        FeedAgentManager.request(
            url: url, params: params, method: .POST, concurrentType: concurrentType, accessToken: accessToken, completion: completion)
    }

    public static func get(
        url: URL, params: Data? = nil, concurrentType: ConcurrentType = .NonBlocking, accessToken: String? = nil, completion: @escaping Completion) {
        FeedAgentManager.request(
            url: url, params: params, method: .GET, concurrentType: concurrentType, accessToken: accessToken, completion: completion)
    }

}

//MARK: Agents
public protocol Agent {
    var agentType: FeedAgentManager.AgentType {get set}
    func handleURL(url: URL) -> FeedAgentManager.FeedAgentResult
    func isValidResponse() -> Bool
    var endpoint_url: String {get}
    var access_token_url: String {get}
    var accessToken:String? {get}
    var bearerToken:String? {get}
    var refreshToken:String? {get}
    var expiresIn:TimeInterval? {get}
    var isExpired: Bool {get}
    var userId:String? {get}
    
    func requestAccessToken() -> FeedAgentManager.FeedAgentResult
    func requestNewAccessToken() -> FeedAgentManager.FeedAgentResult
    func requestProfile() -> FeedAgentManager.FeedAgentResult
    func logout(completion: @escaping FeedAgentManager.Completion)
}

public class FeedAgent {
    let strage: Strage
    let cfg: FeedAgentManager.Dict
    let strageKey: String
    var props: StrageManager.Properties
    
    init(type: StrageManager.StrageType, configurations: FeedAgentManager.Dict) {
        self.strage = StrageManager.shared(type).strage
        self.cfg = configurations
        self.strageKey = cfg["strage_key"] as! String
        self.props = self.strage.loadProperties(key: self.strageKey) ?? [:]
    }
    
    func updateProperties(properties: StrageManager.Properties, needCreateAt: Bool = false) {
        props = props.merging(properties){$1}
        if needCreateAt {props["created_at"] = Date.timeIntervalSinceReferenceDate}
        self.strage.storeProperties(key: self.strageKey, dict: props)
    }
        
    func clearProperties() {
        props.removeAll()
        self.strage.storeProperties(key: self.strageKey, dict: props)
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
                updateProperties(properties: dict as! StrageManager.Properties, needCreateAt: true)
            case .failure(_):
                break
            }
        }
    }
}

//MARK: Feedly
public class Feedly: FeedAgent, Agent {
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
    
    // response parameters
    var state: String { //TODO: 未定
        get {
            if let params = params, let state = params["state"] as? String {
                return state
            } else if let state = props["state"] as? String {
                return state
            }
            return ""
        }
    }
    var code: String {
        get {
            if let params = params, let code = params["code"] as? String {
                return code
            }
            return ""
        }
    }
    var params: FeedAgentManager.Dict?

    var access_token_params: String {
        "client_id=\(self.clientId)&client_secret=\(self.clientSecret)" +
        "&redirect_uri=\(self.redirectUrl)&code=\(self.code)&state=\(self.state)&grant_type=authorization_code"
    }
    
    var refresh_token_params: String {
        "client_id=\(self.clientId)&client_secret=\(self.clientSecret)" +
        "&refresh_token=\(self.refreshToken!)&grant_type=refresh_token"
    }
    
    public var endpoint_url: String {
        "https://\(self.domain)/\(self.authenticationUrl)?client_id=\(self.clientId)" +
        "&redirect_uri=\(self.redirectUrl)&response_type=\(self.responseType)&scope=\(self.scope)&state=\(self.state)"
    }
    
    public var access_token_url: String {
        "https://\(self.domain)/\(self.tokenUrl)"
    }
    
    public var logout_from_feedly_url: String {
        "https://\(self.domain)/\(self.logoutUrl)"
    }
    
    var personal_collections_url: String {
        "https://\(self.domain)/v3/collections"
    }
    
    var mget_url: String {
        "https://\(self.domain)/v3/entries/.mget"
    }
    
//    var streams_url: String {
//        "https://\(self.domain)/v3/streams/contents?streamId=\(self.streamId)&count=\(self.pageCount)"
//    }
    
    var profile_url: String {
        "https://\(self.domain)/v3/profile"
    }
    

    public var agentType: FeedAgentManager.AgentType =
        FeedAgentManager.AgentType.Feedly
    
    public var isExpired: Bool {
        guard let expiresIn = expiresIn, let createdAt = createdAt else {
            return true
        }
        return Date.timeIntervalSinceReferenceDate > createdAt + expiresIn
    }

    public func isValidResponse() -> Bool {
        if let params = self.params {
            return params["error"] == nil
        }
        return false
    }
    
    public func handleURL(url: URL) -> FeedAgentManager.FeedAgentResult {
        self.params = url.params()
        guard isValidResponse() else {
            return Result.failure(FeedAgentManager.FeedError.parameterError)
        }
        return requestAccessToken()
    }
    
    public func requestAccessToken() -> FeedAgentManager.FeedAgentResult {
        var faResult: FeedAgentManager.FeedAgentResult?
        FeedAgentManager.post(
            url: URL(
                string: self.access_token_url)!, params: self.access_token_params.data(using: .utf8), concurrentType: .Blocking) { result in
            faResult = result
        }
        store(result: faResult)
        return faResult!
    }

    public func requestNewAccessToken() -> FeedAgentManager.FeedAgentResult {
        var faResult: FeedAgentManager.FeedAgentResult?
        FeedAgentManager.post(
            url: URL(
                string: self.access_token_url)!, params: self.refresh_token_params.data(using: .utf8), concurrentType: .Blocking) { result in
            faResult = result
        }
        store(result: faResult)
        return faResult!
    }
    
    public func requestProfile() -> FeedAgentManager.FeedAgentResult {
        var faResult: FeedAgentManager.FeedAgentResult?
        FeedAgentManager.get(
            url: URL(
                string: self.profile_url)!, concurrentType: .Blocking, accessToken: self.bearerToken) { result in
            faResult = result
        }
        store(result: faResult)
        return faResult!
    }

    public func logout(completion: @escaping FeedAgentManager.Completion) {
        FeedAgentManager.post(
            url: URL(
                string: self.logout_from_feedly_url)!, concurrentType: .NonBlocking, accessToken: self.bearerToken) { [weak self] result in
            switch result {
            case .success(_):
                self?.clear(result: result)
            case .failure(_):
                break
            }
            completion(result)
        }
    }
}

//MARK: BUILTIN EXTENSIONS
extension URL {
    func params() -> FeedAgentManager.Dict {
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


