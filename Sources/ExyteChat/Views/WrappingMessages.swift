//
//  SwiftUIView.swift
//  
//
//  Created by Alisa Mylnikova on 06.12.2023.
//

import SwiftUI

extension ChatView {

    nonisolated static func mapMessages(_ messages: [Message], chatType: ChatType, replyMode: ReplyMode, preserveOriginalOrder: Bool = false, disableDateGrouping: Bool = false) -> [MessagesSection] {
        guard messages.hasUniqueIDs() else {
            fatalError("Messages can not have duplicate ids, please make sure every message gets a unique id")
        }

        let result: [MessagesSection]
        
        // 如果要求保持原始顺序，使用无分组的简化版本
        if preserveOriginalOrder {
            result = mapMessagesWithoutGrouping(messages, chatType: chatType, replyMode: replyMode)
        } else {
            switch replyMode {
            case .quote:
                result = mapMessagesQuoteModeReplies(messages, chatType: chatType, replyMode: replyMode, preserveOriginalOrder: preserveOriginalOrder)
            case .answer:
                result = mapMessagesCommentModeReplies(messages, chatType: chatType, replyMode: replyMode, preserveOriginalOrder: preserveOriginalOrder)
            }
        }

        return result
    }

    /// 无分组版本：所有消息放在一个section中，完全保持原始顺序
    nonisolated static func mapMessagesWithoutGrouping(_ messages: [Message], chatType: ChatType, replyMode: ReplyMode) -> [MessagesSection] {
        // 对于quote模式：直接按原始顺序处理所有消息
        if replyMode == .quote {
            let wrappedMessages = wrapSectionMessages(messages, chatType: chatType, replyMode: replyMode, isFirstSection: true, isLastSection: true)
            return [MessagesSection(date: Date(), rows: wrappedMessages)]
        }
        
        // 对于answer模式：需要处理回复层级，但仍保持整体顺序
        let firstLevelMessages = messages.filter { $0.replyMessage == nil }
        var allMessages: [Message] = []
        
        // 按照原始顺序处理一级消息和它们的回复
        for firstLevelMessage in firstLevelMessages {
            if chatType == .conversation {
                allMessages.append(firstLevelMessage)
            }
            
            // 添加这个一级消息的所有回复（保持原始顺序）
            let replies = getRepliesFor(id: firstLevelMessage.id, messages: messages)
            allMessages.append(contentsOf: replies)
            
            if chatType == .comments {
                allMessages.append(firstLevelMessage)
            }
        }
        
        let wrappedMessages = wrapSectionMessages(allMessages, chatType: chatType, replyMode: replyMode, isFirstSection: true, isLastSection: true)
        return [MessagesSection(date: Date(), rows: wrappedMessages)]
    }

    nonisolated static func mapMessagesQuoteModeReplies(_ messages: [Message], chatType: ChatType, replyMode: ReplyMode, preserveOriginalOrder: Bool) -> [MessagesSection] {
        let dates = Set(messages.map({ $0.createdAt.startOfDay() }))
        let sortedDates = preserveOriginalOrder ? dates.sorted() : dates.sorted().reversed()
        var result: [MessagesSection] = []

        for date in sortedDates {
            let dayMessages = messages.filter({ $0.createdAt.isSameDay(date) })
            let wrappedMessages = wrapSectionMessages(dayMessages, chatType: chatType, replyMode: replyMode, isFirstSection: false, isLastSection: false)
            
            let section = MessagesSection(
                date: date,
                // use fake isFirstSection/isLastSection because they are not needed for quote replies
                rows: preserveOriginalOrder ? wrappedMessages : wrappedMessages.reversed()
            )
            result.append(section)
        }

        return result
    }

    nonisolated static func mapMessagesCommentModeReplies(_ messages: [Message], chatType: ChatType, replyMode: ReplyMode, preserveOriginalOrder: Bool) -> [MessagesSection] {
        let firstLevelMessages = messages.filter { m in
            m.replyMessage == nil
        }

        let dates = Set(firstLevelMessages.map({ $0.createdAt.startOfDay() }))
        let sortedDates = preserveOriginalOrder ? dates.sorted() : dates.sorted().reversed()
        var result: [MessagesSection] = []

        for date in sortedDates {
            let dayFirstLevelMessages = firstLevelMessages.filter({ $0.createdAt.isSameDay(date) })
            var dayMessages = [Message]() // insert second level in between first level
            for m in dayFirstLevelMessages {
                var replies = getRepliesFor(id: m.id, messages: messages)
                if !preserveOriginalOrder {
                    replies.sort { $0.createdAt < $1.createdAt }
                }
                if chatType == .conversation {
                    dayMessages.append(m)
                }
                dayMessages.append(contentsOf: replies)
                if chatType == .comments {
                    dayMessages.append(m)
                }
            }

            let isFirstSection = sortedDates.first == date
            let isLastSection = sortedDates.last == date
            let sectionRows = wrapSectionMessages(dayMessages, chatType: chatType, replyMode: replyMode, isFirstSection: isFirstSection, isLastSection: isLastSection)
            let finalRows = preserveOriginalOrder ? sectionRows : sectionRows.reversed()
            result.append(MessagesSection(date: date, rows: finalRows))
        }

        return result
    }

    nonisolated static private func getRepliesFor(id: String, messages: [Message]) -> [Message] {
        messages.compactMap { m in
            if m.replyMessage?.id == id {
                return m
            }
            return nil
        }
    }

    nonisolated static private func wrapSectionMessages(_ messages: [Message], chatType: ChatType, replyMode: ReplyMode, isFirstSection: Bool, isLastSection: Bool) -> [MessageRow] {
        messages
            .enumerated()
            .map {
                let index = $0.offset
                let message = $0.element
                let nextMessage = chatType == .conversation ? messages[safe: index + 1] : messages[safe: index - 1]
                let prevMessage = chatType == .conversation ? messages[safe: index - 1] : messages[safe: index + 1]

                let nextMessageExists = nextMessage != nil
                let prevMessageExists = prevMessage != nil
                let nextMessageIsSameUser = nextMessage?.user.id == message.user.id
                let prevMessageIsSameUser = prevMessage?.user.id == message.user.id

                let positionInUserGroup: PositionInUserGroup
                if nextMessageExists, nextMessageIsSameUser, prevMessageIsSameUser {
                    positionInUserGroup = .middle
                } else if !nextMessageExists || !nextMessageIsSameUser, !prevMessageIsSameUser {
                    positionInUserGroup = .single
                } else if nextMessageExists, nextMessageIsSameUser {
                    positionInUserGroup = .first
                } else {
                    positionInUserGroup = .last
                }

                let positionInMessagesSection: PositionInMessagesSection
                if messages.count == 1 {
                    positionInMessagesSection = .single
                } else if !prevMessageExists {
                    positionInMessagesSection = .first
                } else if !nextMessageExists {
                    positionInMessagesSection = .last
                } else {
                    positionInMessagesSection = .middle
                }

                if replyMode == .quote {
                    return MessageRow(
                        message: $0.element, positionInUserGroup: positionInUserGroup,
                        positionInMessagesSection: positionInMessagesSection, commentsPosition: nil)
                }

                let nextMessageIsAReply = nextMessage?.replyMessage != nil
                let nextMessageIsFirstLevel = nextMessage?.replyMessage == nil
                let prevMessageIsFirstLevel = prevMessage?.replyMessage == nil

                let positionInComments: PositionInCommentsGroup
                if message.replyMessage == nil && !nextMessageIsAReply {
                    positionInComments = .singleFirstLevelPost
                } else if message.replyMessage == nil && nextMessageIsAReply {
                    positionInComments = .firstLevelPostWithComments
                } else if nextMessageIsFirstLevel {
                    positionInComments = .lastComment
                } else if prevMessageIsFirstLevel {
                    positionInComments = .firstComment
                } else {
                    positionInComments = .middleComment
                }

                let positionInSection: PositionInSection
                if !prevMessageExists, !nextMessageExists {
                    positionInSection = .single
                } else if !prevMessageExists {
                    positionInSection = .first
                } else if !nextMessageExists {
                    positionInSection = .last
                } else {
                    positionInSection = .middle
                }

                let positionInChat: PositionInChat
                if !isFirstSection, !isLastSection {
                    positionInChat = .middle
                } else if !prevMessageExists, !nextMessageExists, isFirstSection, isLastSection {
                    positionInChat = .single
                } else if !prevMessageExists, isFirstSection {
                    positionInChat = .first
                } else if !nextMessageExists, isLastSection {
                    positionInChat = .last
                } else {
                    positionInChat = .middle
                }

                let commentsPosition = CommentsPosition(
                    inCommentsGroup: positionInComments, inSection: positionInSection,
                    inChat: positionInChat)

                return MessageRow(
                    message: $0.element, positionInUserGroup: positionInUserGroup,
                    positionInMessagesSection: positionInMessagesSection,
                    commentsPosition: commentsPosition)
            }
            .reversed()
    }
}

