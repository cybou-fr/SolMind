import Foundation

enum Base58 {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")

    static func encode(_ input: [UInt8]) -> String {
        var bytes = input
        let leadingZeros = bytes.prefix(while: { $0 == 0 }).count
        var result: [UInt8] = []
        while bytes.count > leadingZeros {
            var remainder = 0
            var newBytes: [UInt8] = []
            for byte in bytes {
                let cur = remainder * 256 + Int(byte)
                let q = cur / 58
                remainder = cur % 58
                if !newBytes.isEmpty || q != 0 { newBytes.append(UInt8(q)) }
            }
            bytes = newBytes
            result.append(UInt8(remainder))
        }
        result += Array(repeating: UInt8(0), count: leadingZeros)
        return String(result.reversed().map { alphabet[Int($0)] })
    }

    static func decode(_ s: String) -> [UInt8]? {
        let map: [Character: Int] = Dictionary(
            uniqueKeysWithValues: alphabet.enumerated().map { ($0.element, $0.offset) }
        )
        let leadingZeros = s.prefix(while: { $0 == "1" }).count
        var bytes: [UInt8] = [0]
        for ch in s {
            guard let val = map[ch] else { return nil }
            var carry = val
            for i in stride(from: bytes.count - 1, through: 0, by: -1) {
                carry += Int(bytes[i]) * 58
                bytes[i] = UInt8(carry & 0xFF)
                carry >>= 8
            }
            while carry > 0 {
                bytes.insert(UInt8(carry & 0xFF), at: 0)
                carry >>= 8
            }
        }
        while bytes.first == 0 { bytes.removeFirst() }
        return Array(repeating: 0, count: leadingZeros) + bytes
    }

    static func isValidAddress(_ s: String) -> Bool {
        guard let b = decode(s) else { return false }
        return b.count == 32
    }
}
