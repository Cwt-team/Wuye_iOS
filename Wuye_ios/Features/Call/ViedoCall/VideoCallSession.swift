// VideoCallSession.swift
import Foundation

/// 视频通话会话模型，保存当前视频通话的关键信息
struct VideoCallSession {
    let callId: String
    let remoteUser: String
    let startTime: Date
    var isActive: Bool
    var isMuted: Bool
    var isCameraOn: Bool
}
