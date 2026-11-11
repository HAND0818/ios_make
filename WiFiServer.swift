import Foundation
import Network
import UIKit

/// 외부 라이브러리 없이 Network 프레임워크만 쓰는 작은 HTTP 서버.
/// 같은 Wi-Fi의 PC/폰 브라우저에서 http://<아이폰 IP>:8080 을 열어 파일을 업로드하면
/// Documents에 저장되고 라이브러리에 자동 반영됩니다.
final class WiFiServer: ObservableObject {
    @Published var isRunning = false
    @Published var address = ""
    var onUploaded: (() -> Void)?

    static let port: UInt16 = 8080
    fileprivate let queue = DispatchQueue(label: "retropod.wifi")
    private var listener: NWListener?
    private var conns: [ObjectIdentifier: Conn] = [:]

    func start() {
        guard listener == nil, let port = NWEndpoint.Port(rawValue: Self.port) else { return }
        do {
            let l = try NWListener(using: .tcp, on: port)
            l.newConnectionHandler = { [weak self] c in self?.accept(c) }
            l.stateUpdateHandler = { [weak self] s in
                if case .failed = s { DispatchQueue.main.async { self?.stop() } }
            }
            l.start(queue: queue)
            listener = l
            isRunning = true
            address = Self.localIP().map { "http://\($0):\(Self.port)" } ?? ""
            UIApplication.shared.isIdleTimerDisabled = true   // 전송 중 화면 잠금 방지
        } catch {
            isRunning = false
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        queue.async { [self] in
            conns.values.forEach { $0.close() }
            conns.removeAll()
        }
        isRunning = false
        UIApplication.shared.isIdleTimerDisabled = false
    }

    private func accept(_ c: NWConnection) {
        let conn = Conn(c, server: self)
        conns[ObjectIdentifier(conn)] = conn
        conn.start()
    }

    fileprivate func remove(_ conn: Conn) { conns[ObjectIdentifier(conn)] = nil }

    /// Wi-Fi(en0) 또는 개인 핫스팟(bridge100)의 IPv4 주소
    static func localIP() -> String? {
        var result: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let i = ptr.pointee
            guard let sa = i.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET),
                  ["en0", "bridge100"].contains(String(cString: i.ifa_name)) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
            result = String(cString: host)
            if String(cString: i.ifa_name) == "en0" { break }
        }
        return result
    }
}

/// 연결 하나를 처리: 헤더 파싱 → GET / 은 업로드 페이지, POST /upload?name=… 은 본문을 파일로 스트리밍 저장
private final class Conn {
    let c: NWConnection
    let server: WiFiServer
    var buf = Data()
    var headerDone = false
    var finished = false
    var remaining = 0
    var file: FileHandle?
    var tmp: URL?
    var dest: URL?

    init(_ c: NWConnection, server: WiFiServer) {
        self.c = c
        self.server = server
    }

    func start() {
        c.stateUpdateHandler = { [weak self] s in
            switch s {
            case .failed, .cancelled: self?.close()
            default: break
            }
        }
        c.start(queue: server.queue)
        receive()
    }

    func close() {
        try? file?.close()
        file = nil
        if let t = tmp, remaining > 0 { try? FileManager.default.removeItem(at: t) }   // 중간에 끊긴 업로드 정리
        c.cancel()
        server.remove(self)
    }

    func receive() {
        c.receive(minimumIncompleteLength: 1, maximumLength: 256 * 1024) { [self] data, _, isDone, error in
            if let d = data, !d.isEmpty { handle(d) }
            if error != nil || (isDone && !finished) { close(); return }
            if !finished { receive() }
        }
    }

    func handle(_ d: Data) {
        if headerDone { feed(d); return }
        buf.append(d)
        guard let r = buf.range(of: Data("\r\n\r\n".utf8)) else {
            if buf.count > 64 * 1024 { respond("431 Request Header Fields Too Large", "text/plain", "too large") }
            return
        }
        let head = String(decoding: buf[..<r.lowerBound], as: UTF8.self)
        let body = Data(buf[r.upperBound...])
        buf = Data()
        headerDone = true
        route(head, body)
    }

    func route(_ head: String, _ body: Data) {
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines[0].split(separator: " ")
        guard parts.count >= 2 else { return respond("400 Bad Request", "text/plain", "bad request") }
        let method = String(parts[0]), target = String(parts[1])
        var headers: [String: String] = [:]
        for l in lines.dropFirst() {
            if let i = l.firstIndex(of: ":") {
                headers[String(l[..<i]).lowercased()] = String(l[l.index(after: i)...]).trimmingCharacters(in: .whitespaces)
            }
        }

        if method == "GET", target == "/" || target.hasPrefix("/?") {
            return respond("200 OK", "text/html; charset=utf-8", WiFiServer.page)
        }

        if method == "POST", target.hasPrefix("/upload"), let len = Int(headers["content-length"] ?? ""), len >= 0 {
            guard let comps = URLComponents(string: "http://x" + target),
                  let raw = comps.queryItems?.first(where: { $0.name == "name" })?.value else {
                return respond("400 Bad Request", "text/plain", "missing name")
            }
            let name = URL(fileURLWithPath: raw).lastPathComponent      // 경로 조작 방지
            let ext = (name as NSString).pathExtension.lowercased()
            guard !name.isEmpty, !name.hasPrefix("."),
                  PlayerStore.audioExt.contains(ext) || PlayerStore.videoExt.contains(ext) || ext == "lrc" else {
                return respond("400 Bad Request", "text/plain", "unsupported file")
            }
            dest = PlayerStore.docs.appendingPathComponent(name)
            let t = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            FileManager.default.createFile(atPath: t.path, contents: nil)
            file = try? FileHandle(forWritingTo: t)
            tmp = t
            remaining = len
            if len == 0 { return finishUpload() }
            feed(body)
            return
        }
        respond("404 Not Found", "text/plain", "not found")
    }

    func feed(_ d: Data) {
        guard remaining > 0 else { return }
        let chunk = d.count > remaining ? d.prefix(remaining) : d
        try? file?.write(contentsOf: chunk)
        remaining -= chunk.count
        if remaining == 0 { finishUpload() }
    }

    func finishUpload() {
        try? file?.close()
        file = nil
        if let t = tmp, let dst = dest {
            try? FileManager.default.removeItem(at: dst)
            do { try FileManager.default.moveItem(at: t, to: dst) }
            catch { return respond("500 Internal Server Error", "text/plain", "save failed") }
            DispatchQueue.main.async { self.server.onUploaded?() }
        }
        respond("200 OK", "application/json", "{\"ok\":true}")
    }

    func respond(_ status: String, _ type: String, _ body: String) {
        finished = true
        let b = Data(body.utf8)
        var out = Data("HTTP/1.1 \(status)\r\nContent-Type: \(type)\r\nContent-Length: \(b.count)\r\nConnection: close\r\n\r\n".utf8)
        out.append(b)
        c.send(content: out, completion: .contentProcessed { [self] _ in c.cancel() })
    }
}

extension WiFiServer {
    static let page = #"""
    <!doctype html><html><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>RetroPod Wi-Fi Transfer</title>
    <style>
    body{font-family:-apple-system,"Apple SD Gothic Neo","Malgun Gothic",sans-serif;max-width:560px;margin:24px auto;padding:0 16px}
    #drop{border:2px dashed #888;border-radius:12px;padding:32px 16px;text-align:center}
    #drop.on{background:#8883}
    .row{margin:10px 0;font-size:14px;word-break:break-all}
    .bar{height:6px;background:#8884;border-radius:3px;margin-top:4px}
    .bar i{display:block;height:100%;width:0;background:#2f7bf0;border-radius:3px}
    </style></head><body>
    <h2>RetroPod Wi-Fi Transfer</h2>
    <div id="drop"><p id="msg"></p><input id="f" type="file" multiple accept="audio/*,video/*,.lrc,.flac,.mp3,.m4a,.aac,.wav,.aiff,.mp4,.mov,.m4v"></div>
    <div id="list"></div>
    <script>
    const ko=navigator.language.startsWith("ko");
    msg.textContent=ko?"음악, MV, .lrc 파일을 여기에 끌어다 놓거나 선택하세요":"Drop music, MV or .lrc files here, or choose them";
    function up(file){return new Promise(function(res){
      const row=document.createElement("div");row.className="row";
      row.innerHTML="<div></div><div class='bar'><i></i></div>";
      row.firstChild.textContent=file.name;list.prepend(row);
      const x=new XMLHttpRequest();
      x.open("POST","/upload?name="+encodeURIComponent(file.name));
      x.upload.onprogress=function(e){if(e.lengthComputable)row.querySelector("i").style.width=(e.loaded/e.total*100)+"%"};
      x.onload=function(){row.firstChild.textContent=(x.status==200?"✓ ":"✗ ")+file.name;res()};
      x.onerror=function(){row.firstChild.textContent="✗ "+file.name;res()};
      x.send(file);
    })}
    async function go(files){for(const f of files)await up(f)}
    f.onchange=function(e){go(e.target.files)};
    drop.ondragover=function(e){e.preventDefault();drop.classList.add("on")};
    drop.ondragleave=function(){drop.classList.remove("on")};
    drop.ondrop=function(e){e.preventDefault();drop.classList.remove("on");go(e.dataTransfer.files)};
    </script></body></html>
    """#
}
