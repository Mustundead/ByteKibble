import Foundation

/// Delegate-based streaming handles headers before any body byte arrives.
/// The lock covers cancellation racing with start/completion; delegate callbacks
/// run on URLSession's serial delegate queue.
final class QuotaRequest: NSObject, URLSessionDataDelegate {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<QuotaSample, Error>?
    private var cancelled = false
    private var session: URLSession?
    private var data = Data()
    private var redirects = 0

    func run(_ request: URLRequest, configuration: URLSessionConfiguration) async throws -> QuotaSample {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                if cancelled {
                    lock.unlock()
                    continuation.resume(throwing: CancellationError())
                    return
                }
                self.continuation = continuation
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
                self.session = session
                let task = session.dataTask(with: request)
                lock.unlock()
                task.resume()
            }
        } onCancel: {
            self.lock.lock()
            self.cancelled = true
            self.lock.unlock()
            self.finish(.failure(CancellationError()))
        }
    }

    private func finish(_ result: Result<QuotaSample, Error>) {
        lock.lock()
        let continuation = self.continuation
        self.continuation = nil
        let session = self.session
        self.session = nil
        lock.unlock()
        session?.invalidateAndCancel()
        continuation?.resume(with: result)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        do {
            guard let http = response as? HTTPURLResponse else { throw Fetcher.Failure(message: L10n.t("订阅服务器返回了无效响应。")) }
            guard (200..<300).contains(http.statusCode) else {
                throw Fetcher.Failure(message: L10n.f("订阅服务器返回 HTTP %@。请检查链接或联系服务商。", String(http.statusCode)), priority: 3)
            }
            if let header = http.value(forHTTPHeaderField: "Subscription-Userinfo") {
                let sample = try Fetcher.parse(header: header)
                finish(.success(sample))
                completionHandler(.cancel)
                return
            }
            guard response.expectedContentLength <= Int64(Fetcher.maximumBodyBytes) else { throw Fetcher.oversizedResponse() }
            completionHandler(.allow)
        } catch {
            finish(.failure(error))
            completionHandler(.cancel)
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive chunk: Data) {
        guard chunk.count <= Fetcher.maximumBodyBytes - data.count else {
            finish(.failure(Fetcher.oversizedResponse()))
            return
        }
        data.append(chunk)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { finish(.failure(error)) }
        else { finish(Result { try Fetcher.parseSIP008(data: data) }) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        redirects += 1
        guard redirects <= 10, Fetcher.redirectAllowed(from: task.originalRequest?.url, to: request.url) else {
            finish(.failure(Fetcher.Failure(message: L10n.t("订阅重定向已被阻止。请添加服务商提供的最终 HTTPS 地址。"), priority: 3)))
            completionHandler(nil)
            return
        }
        completionHandler(request)
    }
}
