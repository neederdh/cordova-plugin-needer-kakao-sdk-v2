import Foundation
import KakaoSDKAuth
import KakaoSDKCommon
import KakaoSDKShare
import KakaoSDKTemplate
import KakaoSDKUser
import SafariServices

// @objc(KakaoAuthV2Utils)
// class KakaoAuthV2Utils: NSObject {
//     @objc(initSdk)
//     class func initSdk() {
//         let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") as? String
//         if let key = key {
//             KakaoSDK.initSDK(appKey: key)
//         }
//     }
//     @objc(attach:)
//     class func attach(_url: NSURL) -> Bool {
//         if let _url = _url.absoluteString {
//             if let url = URL(string: _url) {
//                 if AuthApi.isKakaoTalkLoginUrl(url) {
//                     return AuthController.handleOpenUrl(url: url)
//                 }
//             }
//         }
        
//         return false
//     }
// }

class KakaoCordovaSDKV2: CDVPlugin {
    var safariViewController: SFSafariViewController?
    var rootViewController: UIViewController?
    override func pluginInitialize() {
        let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_APP_KEY") as? String
        if let key = key {
            KakaoSDK.initSDK(appKey: key)
        }
    }

    override func handleOpenURL(_ notification: Notification!) {
        if let _url = notification.object as? NSURL {
            if let _url = _url.absoluteString {
                if let url = URL(string: _url) {
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        AuthController.handleOpenUrl(url: url)
                    }
                }
            }
        }
    }
    
    @objc(login:) func login(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async {
            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: {
                    oauthToken, error in
                    self.loginCallback(oauthToken: oauthToken, error: error, callbackId: command.callbackId)
                })
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: {
                    oauthToken, error in
                    self.loginCallback(oauthToken: oauthToken, error: error, callbackId: command.callbackId)
                })
            }
        }
    }

    func loginCallback(oauthToken: OAuthToken?, error: Error?, callbackId: String) {
        if error != nil {
            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error?.localizedDescription)
            commandDelegate.send(result, callbackId: callbackId)
            
        } else if let oauthToken = oauthToken {
            UserApi.shared.me {
                user, error in
                if error != nil {
                    let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error?.localizedDescription)
                    self.commandDelegate.send(result, callbackId: callbackId)
                } else {
                    let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: [
                        "id": user!.id!,
                        "result": true,
                        "email": user!.kakaoAccount!.email!,
                        "accessToken": oauthToken.accessToken
                    ])
                    self.commandDelegate.send(result, callbackId: callbackId)
                }
            }
        }
    }
    
    @objc(sendLinkFeed:) func sendLinkFeed(command: CDVInvokedUrlCommand) {
        if let dict = command.arguments.last as? NSDictionary {
            let buttons = createButtons(dict: dict)
            let buttonTitle = (dict["buttonTitle"] as? String)
            let content = dict["content"] as! NSDictionary
            var serverCallbackArgs: [String: String] = [:]
            if let arg = content["serverCallbackArgs"] as? NSDictionary {
                let keys = arg.allKeys.compactMap { $0 as? String }
                for key in keys {
                    let keyValue = arg.value(forKey: key)
                    if let keyValue = keyValue as? [String: Any] {
                        let obj = try? JSONSerialization.data(withJSONObject: keyValue)
                        if let obj = obj {
                            serverCallbackArgs[key] = String(data: obj, encoding: .utf8)
                        }
                    } else {
                        serverCallbackArgs[key] = String(describing: keyValue!)
                    }
                }
            }
            
            let feedTemplate = FeedTemplate(content: createContent(dict: content), social: createSocial(dict: dict), buttonTitle: buttonTitle, buttons: buttons)
            if let feedTemplateJsonData = (try? SdkJSONEncoder.custom.encode(feedTemplate)) {
                if let templateJsonObject = SdkUtils.toJsonObject(feedTemplateJsonData) {
                    shareDefaultTemplate(templateObject: templateJsonObject, serverCallbackArgs: serverCallbackArgs) { result, error in
                        if let error = error {
                            let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error.localizedDescription)
                            self.commandDelegate.send(result, callbackId: command.callbackId)
                        } else {
                            let result = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: result)
                            self.commandDelegate.send(result, callbackId: command.callbackId)
                        }
                    }
                }
            }
        }
    }

    private func openLinkWebview(url: URL, callback: @escaping (Bool, Error?) -> Void) {
        DispatchQueue.main.async {
            self.safariViewController = SFSafariViewController(url: url)
            self.safariViewController?.modalPresentationStyle = .pageSheet

            self.rootViewController = UIApplication.shared.delegate?.window??.rootViewController
            self.rootViewController?.dismiss(animated: false, completion: {
                let appDelegate = UIApplication.shared.delegate
                appDelegate?.window??.rootViewController?.present(self.safariViewController!, animated: true, completion: {
                    callback(true, nil)
                })
            })
        }
    }

    private func shareDefaultTemplate(templateObject: [String: Any], serverCallbackArgs: [String: String], callback: @escaping (Bool, Error?) -> Void) {
        if ShareApi.isKakaoTalkSharingAvailable() == true {
            ShareApi.shared.shareDefault(templateObject: templateObject, serverCallbackArgs: serverCallbackArgs) { linkResult, error in
                if let error = error {
                    callback(false, error)
                } else {
                    // do something
                    guard let linkResult = linkResult else { return }
                    UIApplication.shared.open(linkResult.url, options: [:], completionHandler: nil)
                    callback(true, nil)
                }
            }
        } else {
            if let url = ShareApi.shared.makeDefaultUrl(templateObject: templateObject) {
                openLinkWebview(url: url, callback: callback)
            }
        }
    }

    private func createSocial(dict: NSDictionary) -> Social? {
        if let socialDict = dict["social"] {
            let sDict = socialDict as! NSDictionary
            let commentCount = (sDict["commentCount"] as? Int)
            let likeCount = (sDict["likeCount"] as? Int)
            let sharedCount = (sDict["sharedCount"] as? Int)
            let subscriberCount = (sDict["subscriberCount"] as? Int)
            let viewCount = (sDict["viewCount"] as? Int)
            return Social(likeCount: likeCount, commentCount: commentCount, sharedCount: sharedCount, viewCount: viewCount, subscriberCount: subscriberCount)
        }
        return nil
    }
    
    private func createContent(dict: NSDictionary) -> Content {
        let title = dict["title"] != nil ? (dict["title"] as! String) : ""
        let imageUrl = dict["imageURL"] != nil ? createURL(dict: dict, key: "imageURL")! : URL(string: "")!
        let link = createLink(dict: dict, key: "link")
        let description = (dict["desc"] as? String)
        let imageWidth = (dict["imageWidth"] as? Int)
        let imageHeight = (dict["imageHeight"] as? Int)
        return Content(title: title, imageUrl: imageUrl, imageWidth: imageWidth, imageHeight: imageHeight, description: description, link: link)
    }

    private func createURL(dict: NSDictionary, key: String) -> URL? {
        if let value = dict[key] {
            return URL(string: value as! String)
        }
        return nil
    }

    private func createExecutionParams(dict: NSDictionary, key: String) -> [String: String]? {
        if let dictArr = dict[key] {
            var returnDict: [String: String] = [:]
            for item in dictArr as! NSArray {
                if let returnKey = (item as! NSDictionary)["key"], let returnValue = (item as! NSDictionary)["value"] {
                    returnDict[returnKey as! String] = (returnValue as! String)
                }
            }
            return returnDict
        }
        return nil
    }

    private func createLink(dict: NSDictionary, key: String) -> Link {
        if let linkDict = dict[key] {
            let lDict = (linkDict as! NSDictionary)
            let webUrl = createURL(dict: lDict, key: "webURL")
            let mobileWebUrl = createURL(dict: lDict, key: "mobileWebURL")
//                let iosExecutionParams = createExecutionParams(dict: lDict, key: "iosExecutionParams")
//                let androidExecutionParams = createExecutionParams(dict: lDict, key: "androidExecutionParams")
            return Link(webUrl: webUrl, mobileWebUrl: mobileWebUrl
                // ,androidExecutionParams: androidExecutionParams, iosExecutionParams: iosExecutionParams
            )
        }
        return Link(webUrl: nil, mobileWebUrl: nil, androidExecutionParams: nil, iosExecutionParams: nil)
    }

    private func createButton(dict: NSDictionary) -> Button {
        let title = dict["title"] != nil ? dict["title"] : ""
        let link = createLink(dict: dict, key: "link")
        return Button(title: title as! String, link: link)
    }

    private func createButtons(dict: NSDictionary) -> [Button]? {
        if let dictArr = dict["buttons"] {
            var buttons: [Button] = []
            for item in dictArr as! NSArray {
                buttons.append(createButton(dict: item as! NSDictionary))
            }
            return buttons
        }
        return nil
    }
}
