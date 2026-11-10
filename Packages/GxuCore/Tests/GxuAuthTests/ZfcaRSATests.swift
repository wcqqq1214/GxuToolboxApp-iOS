import Foundation
import Testing
@testable import GxuAuth

struct ZfcaRSATests {
    /// 向量由 RN `RSAUtils` 算法的 Python 参照实现生成（随机 1024 位模数，e = 0x10001，密码 "Ab1!xyz"）
    private let modulus = "a170b33839263059f28c105d1fb17c2390c192cfd3ac94af0f21ddb66cad4a268d116ece1738f7d93d9c172411e20b8f6b0d549b6f03675a1600a35a099950d836f675cc81e74ef5e8e25d940ed904759531985d5d9dc9f81818e811892f902bd23f0824128b2f330c5c7fd0a6a3a4506513270e269e0d37f2a74de452e6b439"
    private let expected = "0cc37298fc9df70560200d41315f33834c7a5b6be79d828e8883fc5876296a8d69109639d56975de493466cb4e615a295516527e842cbd93382ae34fea2feb91b3df7fa1ae8e96604daa75e7a05cbec73abd435bcdeb401b627f36030ad3ce0b6f3ca98b0e2bd56f57b9c18fcc04803ab4dc7cac9b74b2eae469c25cc710c6f5"

    @Test func matchesReferenceVector() throws {
        #expect(try ZfcaRSA.encrypt(password: "Ab1!xyz", exponentHex: "010001", modulusHex: modulus) == expected)
    }

    @Test func hexDigitsDropsLeadingZeroDigitsOnly() {
        #expect(ZfcaRSA.hexDigits(Data([0, 0, 0x0c, 0xc3])) == "0cc3")
        #expect(ZfcaRSA.hexDigits(Data([0x0c, 0xc3])) == "0cc3")
    }

    @Test func rejectsBadKey() {
        #expect(throws: (any Error).self) { try ZfcaRSA.encrypt(password: "x", exponentHex: "zz", modulusHex: modulus) }
        #expect(throws: (any Error).self) { try ZfcaRSA.encrypt(password: "x", exponentHex: "010001", modulusHex: "00") }
    }
}
