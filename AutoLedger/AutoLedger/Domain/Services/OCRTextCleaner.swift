import Foundation

/// OCR 文本预清洗：去除噪声、缩短 token，提升端侧模型推理速度
enum OCRTextCleaner {

    /// 清洗 OCR 原始文本，保留与交易相关的信息
    static func clean(_ text: String) -> String {
        var result = text

        // 1. 统一换行符
        result = result.replacingOccurrences(of: "\r\n", with: "\n")

        // 2. 合并连续空行为单个换行
        result = result.replacingOccurrences(
            of: #"\n{3,}"#, with: "\n\n", options: .regularExpression
        )

        // 3. 去除纯装饰行（连续特殊符号行，如 ------、======、******）
        result = result.replacingOccurrences(
            of: #"(?m)^[\-=\*·•─━]{3,}$"#, with: "", options: .regularExpression
        )

        // 4. 去除常见广告/推荐噪声短语
        let noisePatterns = [
            #"(?:查看|点击|领取)更多(?:优惠|红包|团购|活动)"#,
            #"(?:下载|打开)\s*(?:APP|App|app)"#,
            #"(?:广告|推广|推荐商品|猜你喜欢|为你推荐)"#,
            #"(?:回复|评价).*(?:可获|送|赠|领)"#,
        ]
        for pattern in noisePatterns {
            result = result.replacingOccurrences(
                of: pattern, with: "", options: .regularExpression
            )
        }

        // 5. 压缩连续空白（保留换行结构）
        result = result.replacingOccurrences(
            of: #"[^\S\n]{2,}"#, with: " ", options: .regularExpression
        )

        // 6. 截断上限（端侧 2B 模型建议 ≤ 1500 字符）
        let maxLength = 1500
        if result.count > maxLength {
            result = String(result.prefix(maxLength))
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
