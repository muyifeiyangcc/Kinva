import Foundation

enum BPackageCryptoError: LocalizedError {
    case bPackageInvalidKeyOrIV, bPackageInvalidHex, bPackageCryptFailed(Int32), bPackageInvalidUTF8
    var errorDescription: String? {
        switch self {
        case .bPackageInvalidKeyOrIV: return "AES key/iv 必须各为 16 字节"
        case .bPackageInvalidHex: return "服务端密文不是合法十六进制字符串"
        case .bPackageCryptFailed(let bPackageStatus): return "AES 运算失败：\(bPackageStatus)"
        case .bPackageInvalidUTF8: return "解密结果不是 UTF-8"
        }
    }
}

struct BPackageCrypto {
    let bPackageKey: Data
    let bPackageIV: Data

    init(bPackageKey: String, bPackageIV: String) throws {
        self.bPackageKey = Data(bPackageKey.utf8)
        self.bPackageIV = Data(bPackageIV.utf8)
        guard self.bPackageKey.count == kCCKeySizeAES128, self.bPackageIV.count == kCCBlockSizeAES128 else {
            throw BPackageCryptoError.bPackageInvalidKeyOrIV
        }
    }

    func bPackageEncrypt(_ bPackagePlaintext: String) throws -> String {
        try bPackageCrypt(Data(bPackagePlaintext.utf8), bPackageOperation: CCOperation(kCCEncrypt)).bPackageHexString
    }

    func bPackageDecrypt(_ bPackageCipherHex: String) throws -> String {
        guard let bPackageData = Data(bPackageStrictHex: bPackageCipherHex) else { throw BPackageCryptoError.bPackageInvalidHex }
        let bPackageClear = try bPackageCrypt(bPackageData, bPackageOperation: CCOperation(kCCDecrypt))
        guard let bPackageValue = String(data: bPackageClear, encoding: .utf8) else { throw BPackageCryptoError.bPackageInvalidUTF8 }
        return bPackageValue
    }

    private func bPackageCrypt(_ bPackageInput: Data, bPackageOperation: CCOperation) throws -> Data {
        var bPackageOutput = Data(count: bPackageInput.count + kCCBlockSizeAES128)
        let bPackageOutputCapacity = bPackageOutput.count
        var bPackageMoved = 0
        let bPackageStatus = bPackageOutput.withUnsafeMutableBytes { bPackageOut in
            bPackageInput.withUnsafeBytes { bPackageSource in
                bPackageKey.withUnsafeBytes { bPackageKeyBytes in
                    bPackageIV.withUnsafeBytes { bPackageIVBytes in
                        CCCrypt(bPackageOperation, CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                bPackageKeyBytes.baseAddress, bPackageKey.count, bPackageIVBytes.baseAddress,
                                bPackageSource.baseAddress, bPackageInput.count, bPackageOut.baseAddress,
                                bPackageOutputCapacity, &bPackageMoved)
                    }
                }
            }
        }
        guard bPackageStatus == kCCSuccess else { throw BPackageCryptoError.bPackageCryptFailed(bPackageStatus) }
        bPackageOutput.removeSubrange(bPackageMoved..<bPackageOutput.count)
        return bPackageOutput
    }
}

private extension Data {
    var bPackageHexString: String { map { String(format: "%02x", $0) }.joined() }

    init?(bPackageStrictHex: String) {
        guard bPackageStrictHex.count.isMultiple(of: 2), bPackageStrictHex.allSatisfy({ $0.isHexDigit }) else { return nil }
        self.init()
        reserveCapacity(bPackageStrictHex.count / 2)
        var bPackageIndex = bPackageStrictHex.startIndex
        while bPackageIndex < bPackageStrictHex.endIndex {
            let bPackageEnd = bPackageStrictHex.index(bPackageIndex, offsetBy: 2)
            guard let bPackageByte = UInt8(bPackageStrictHex[bPackageIndex..<bPackageEnd], radix: 16) else { return nil }
            append(bPackageByte)
            bPackageIndex = bPackageEnd
        }
    }
}

