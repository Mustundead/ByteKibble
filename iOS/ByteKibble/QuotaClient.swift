import Foundation

/// Ephemeral, bounded GET. Never executes or persists subscription configuration.
final class QuotaClient: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<QuotaReading, Error>?
    private var session: URLSession?
    private var body = Data()
    private var redirects = 0
    private var cancelled = false

    func fetch(_ url: URL, protocolClasses: [AnyClass]? = nil) async throws -> QuotaReading {
        guard SubscriptionLink.https(url.absoluteString) != nil else { throw QuotaError.invalidLink }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if cancelled { lock.unlock(); continuation.resume(throwing: CancellationError()); return }
                self.continuation = continuation
                let config = URLSessionConfiguration.ephemeral
                config.protocolClasses = protocolClasses
                config.timeoutIntervalForRequest = 10
                config.timeoutIntervalForResource = 20
                config.httpCookieStorage = nil
                config.urlCache = nil
                config.requestCachePolicy = .reloadIgnoringLocalCacheData
                let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
                self.session = session
                var request = URLRequest(url: url)
                request.setValue("clash-verge/1.7.7", forHTTPHeaderField: "User-Agent")
                let task = session.dataTask(with: request)
                lock.unlock()
                task.resume()
            }
        } onCancel: {
            self.lock.lock(); self.cancelled = true; self.lock.unlock()
            self.finish(.failure(CancellationError()))
        }
    }
    private func finish(_ result: Result<QuotaReading, Error>) {
        lock.lock()
        let continuation = self.continuation; self.continuation = nil
        let session = self.session; self.session = nil
        lock.unlock()
        session?.invalidateAndCancel()
        continuation?.resume(with: result)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse else {
            completionHandler(.cancel); finish(.failure(QuotaError.invalidResponse)); return
        }
        guard (200..<300).contains(response.statusCode) else {
            completionHandler(.cancel); finish(.failure(QuotaError.http(response.statusCode))); return
        }
        if let header = response.value(forHTTPHeaderField: "subscription-userinfo") {
            let result = Result { try QuotaParser.parse(header: header, body: Data()) }
            completionHandler(.cancel); finish(result); return
        }
        guard response.expectedContentLength <= QuotaParser.maximumBodyBytes else {
            completionHandler(.cancel); finish(.failure(QuotaError.tooLarge)); return
        }
        completionHandler(.allow)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard data.count <= QuotaParser.maximumBodyBytes - body.count else {
            finish(.failure(QuotaError.tooLarge)); return
        }
        body.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil { finish(.failure(QuotaError.connection)) }
        else { finish(Result { try QuotaParser.parse(header: nil, body: body) }) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard redirects < 5, let from = response.url, let to = request.url,
              SubscriptionLink.allowsRedirect(from: from, to: to) else {
            completionHandler(nil); finish(.failure(QuotaError.unsafeRedirect)); return
        }
        redirects += 1; completionHandler(request)
    }
}
