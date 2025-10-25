//
//  Created by Alex.M on 16.06.2022.
//

import Foundation
//import ExyteMediaPicker

public enum AttachmentType: String, Codable, Sendable {
    case image
    case video
    case customUI  // 新增：自定义UI标记类型

    public var title: String {
        switch self {
        case .image:
            return "Image"
        case .customUI:
            return "Custom UI"
        default:
            return "Video"
        }
    }

//    public init(mediaType: MediaType) {
//        switch mediaType {
//        case .image:
//            self = .image
//        default:
//            self = .video
//        }
//    }
}

public struct Attachment: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let thumbnail: URL
    public let full: URL
    public let type: AttachmentType
    public let thumbnailCacheKey: String?
    public let fullCacheKey: String?
    public let customData: [String: String]  // 新增：自定义数据

    public init(id: String, thumbnail: URL, full: URL, type: AttachmentType, thumbnailCacheKey: String? = nil, fullCacheKey: String? = nil, customData: [String: String] = [:]) {
        self.id = id
        self.thumbnail = thumbnail
        self.full = full
        self.type = type
        self.thumbnailCacheKey = thumbnailCacheKey
        self.fullCacheKey = fullCacheKey
        self.customData = customData
    }

    public init(id: String, url: URL, type: AttachmentType, cacheKey: String? = nil, customData: [String: String] = [:]) {
        self.init(id: id, thumbnail: url, full: url, type: type, thumbnailCacheKey: cacheKey, fullCacheKey: cacheKey, customData: customData)
    }
}
