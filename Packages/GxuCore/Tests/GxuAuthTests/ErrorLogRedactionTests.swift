import Foundation
import GxuFoundation
import GxuNetworking
import GxuStorage
import GxuTestSupport
import Synchronization
import Testing
@testable import GxuAuth

struct ErrorLogRedactionTests {
    @Test func commonSecretFormatsAreMasked() {
        let cases: [(input: String, secret: String)] = [
            (#"{"password":"S3cretPw"}"#, "S3cretPw"),
            (#"{"accessToken":"AAAtokenBBB"}"#, "AAAtokenBBB"),
            ("access_token=AAAtokenBBB", "AAAtokenBBB"),
            ("refreshToken=RRR123abc", "RRR123abc"),
            ("password=ab;cdLEAK1", "cdLEAK1"),
            ("password=ab,cdLEAK2", "cdLEAK2"),
            ("Cookie: JSESSIONID=aaa; route=LEAKROUTE; other=LEAKOTHER", "LEAKROUTE"),
            ("Set-Cookie: route=LEAKROUTE2; Path=/", "LEAKROUTE2"),
            ("密码：LEAKCN", "LEAKCN"),
            ("password: my LEAKSPACE pass", "LEAKSPACE"),
            ("手机 138-0013-8000 LEAKPHONE", "138-0013-8000"),
            ("手机 138 0013 8000", "0013"),
            ("Authorization: Bearer abc.def.ghi", "abc.def.ghi"),
        ]
        for (input, secret) in cases {
            let output = ErrorLog.redact(input)
            #expect(!output.contains(secret), "「\(input)」脱敏后仍含「\(secret)」：\(output)")
        }
    }
}
