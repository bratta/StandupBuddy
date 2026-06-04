import Foundation

enum StrftimeFormatter {
    static func format(_ date: Date, _ fmt: String) -> String {
        var time = time_t(date.timeIntervalSince1970)
        var tm = tm()
        localtime_r(&time, &tm)
        let bufSize = 256
        var buf = [CChar](repeating: 0, count: bufSize)
        strftime(&buf, bufSize, fmt, &tm)
        return String(cString: buf)
    }
}
