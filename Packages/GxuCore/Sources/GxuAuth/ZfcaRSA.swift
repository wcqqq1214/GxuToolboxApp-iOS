import Foundation
import GxuFoundation
import Security

/// 统一认证（zfca）登录页用的 RSA：与 RN `RSAUtils.encryptedString` 逐字节一致。
/// 算法：密码反转 → 按字节小端当作大整数（零填充到 `chunkSize` 的整数倍）→ 裸 RSA（无填充）→ 以 16 位为单位输出小写十六进制，多个分块用空格连接。
public enum ZfcaRSA {
    public static func encrypt(password: String, exponentHex: String, modulusHex: String) throws -> String {
        let modulus = Self.stripLeadingZeros(try bytes(fromHex: modulusHex))
        let exponent = Self.stripLeadingZeros(try bytes(fromHex: exponentHex))
        guard modulus.count >= 4, !exponent.isEmpty else { throw GxuError.invalidData("统一认证公钥无效") }
        let digitCount = (modulus.count + 1) / 2          // 16 位为一个 digit
        let chunkSize = 2 * (digitCount - 1)
        guard let key = makeKey(modulus: modulus, exponent: exponent) else { throw GxuError.invalidData("统一认证公钥无效") }

        var plain = Array(password.utf16.reversed()).map { UInt8(truncatingIfNeeded: $0) }
        while plain.count % chunkSize != 0 { plain.append(0) }

        var blocks: [String] = []
        for start in stride(from: 0, to: plain.count, by: chunkSize) {
            // 小端字节 → 大端；左侧补零到密钥长度
            let bigEndian = Array(plain[start..<start + chunkSize].reversed())
            let input = Data(repeating: 0, count: modulus.count - chunkSize) + Data(bigEndian)
            var error: Unmanaged<CFError>?
            guard let out = SecKeyCreateEncryptedData(key, .rsaEncryptionRaw, input as CFData, &error) as Data? else {
                throw GxuError.invalidData("统一认证密码加密失败")
            }
            blocks.append(Self.hexDigits(out))
        }
        return blocks.joined(separator: " ")
    }

    // MARK: Internals

    /// 去掉最高位全零的 16 位 digit，其余每个 digit 输出 4 个十六进制字符
    static func hexDigits(_ data: Data) -> String {
        var bytes = [UInt8](data)
        if bytes.count % 2 == 1 { bytes.insert(0, at: 0) }
        while bytes.count >= 2, bytes[0] == 0, bytes[1] == 0 { bytes.removeFirst(2) }
        if bytes.isEmpty { return "0000" }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func bytes(fromHex hex: String) throws -> [UInt8] {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.count % 2 == 1 { hex = "0" + hex }
        var result: [UInt8] = []
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { throw GxuError.invalidData("统一认证公钥无效") }
            result.append(byte)
            index = next
        }
        return result
    }

    static func stripLeadingZeros(_ bytes: [UInt8]) -> [UInt8] {
        Array(bytes.drop { $0 == 0 })
    }

    private static func makeKey(modulus: [UInt8], exponent: [UInt8]) -> SecKey? {
        func integer(_ bytes: [UInt8]) -> [UInt8] {
            let body = (bytes.first ?? 0) & 0x80 != 0 ? [0] + bytes : bytes
            return [0x02] + length(body.count) + body
        }
        func length(_ n: Int) -> [UInt8] {
            if n < 0x80 { return [UInt8(n)] }
            let bytes = withUnsafeBytes(of: UInt32(n).bigEndian, Array.init).drop { $0 == 0 }
            return [0x80 | UInt8(bytes.count)] + bytes
        }
        let body = integer(modulus) + integer(exponent)
        let der = Data([0x30] + length(body.count) + body)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: modulus.count * 8,
        ]
        return SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil)
    }
}
