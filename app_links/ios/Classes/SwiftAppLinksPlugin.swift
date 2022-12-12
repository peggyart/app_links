import Flutter
import UIKit

public class SwiftAppLinksPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  fileprivate var eventSink: FlutterEventSink?

  fileprivate var initialLink: String?
  fileprivate var latestLink: String?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "com.llfbandit.app_links/messages", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "com.llfbandit.app_links/events", binaryMessenger: registrar.messenger())

    let instance = SwiftAppLinksPlugin()

    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    eventChannel.setStreamHandler(instance)
    registrar.addApplicationDelegate(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
      case "getInitialAppLink":
        result(initialLink)
        break
      case "getLatestAppLink":
        result(latestLink)
        break      
      default:
        result(FlutterMethodNotImplemented)
        break
    }
  }

  // Universal Links
  public func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([Any]) -> Void) -> Bool {
      let clickTrackerStr: String = "clicks.peggy.com"
      if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
        let url = userActivity.webpageURL {
          if url.absoluteString.contains(clickTrackerStr) {
            let r = Redirect()
            r.makeRequest(url: url, callback: { (location) in
              guard let locationURL = location else {return}
              self.handleLink(url: locationURL)
            })
          } else {
            handleLink(url: url)
          }
      }
      return false
  }

  // Custom URL schemes
  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    
    handleLink(url: url)
    return false
  }
    
  public func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink) -> FlutterError? {

    self.eventSink = events
    return nil
  }
    
  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  fileprivate func handleLink(url: URL) -> Void {
    let link = url.absoluteString

    debugPrint("iOS handleLink: \(link)")

    latestLink = link

    if (initialLink == nil) {
      initialLink = link
    }
    
    guard let _eventSink = eventSink, latestLink != nil else {
      return
    }

    _eventSink(latestLink)
  }
}

class Redirect : NSObject {
    var session: URLSession?
    
    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    func makeRequest(url: URL, callback: @escaping (URL?) -> ()) {
        let task = self.session?.dataTask(with: url) {(data, response, error) in
            guard error == nil else {
                print(error!)
                return
            }
            
            guard response != nil else {
                return
            }
            if let response = response as? HTTPURLResponse {
                if let l = (response.allHeaderFields as NSDictionary)["Location"] as? String {
                    callback(URL(string: l))
                }    
            }
        }
        task?.resume()
    }
}

extension Redirect: URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Stops the redirection, and returns (internally) the response body.
        completionHandler(nil)
    }
}

