import Foundation

/// 姿势枚举与形象分支对齐：`stand` / `lift` / `busy`。
/// `talking` 仍单独表示说话；开心脸走 `flashSmile`，不占姿势位。
enum PetPose: String, Equatable {
    case stand
    case talking
    case busy
    case lift
}

enum PetExpression {
    /// 日记写完后发这个通知；形象分支可观察并调用 `flashSmile()`。
    static let smileNotification = Notification.Name("bottt.expression.smile")

    /// `bottt say` 收到这句时也会在说完后触发开心表情。
    static let diarySavedLine = "Diary saved."

    static func postSmile(reason: String) {
        NotificationCenter.default.post(
            name: smileNotification,
            object: nil,
            userInfo: ["reason": reason]
        )
        SpeechLog.write("expression smile reason=\(reason)")
    }
}
