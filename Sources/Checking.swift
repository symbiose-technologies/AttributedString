//
//  Checking.swift
//  ┌─┐      ┌───────┐ ┌───────┐
//  │ │      │ ┌─────┘ │ ┌─────┘
//  │ │      │ └─────┐ │ └─────┐
//  │ │      │ ┌─────┘ │ ┌─────┘
//  │ └─────┐│ └─────┐ │ └─────┐
//  └───────┘└───────┘ └───────┘
//
//  Created by Lee on 2020/6/22.
//  Copyright © 2020 LEE. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

extension ASAttributedString {
        
    public enum Checking: Hashable {
        /// represents a custom range of characters within the attributed string
        case range(NSRange)
        /// represents a regular expression pattern that should be matched in the attributed string
        case regex(String)
        #if os(iOS) || os(macOS)
        ///  represents an action that should be performed when the user interacts with a specific part of the attributed string (only available on iOS and macOS)
        case action
        #endif
        #if !os(watchOS)
        /// represents an attachment that should be displayed as part of the attributed string (not available on watchOS)
        case attachment
        #endif
        case date
        case link
        case address
        case phoneNumber
        case transitInformation
        case macLink
    }
}

extension ASAttributedString.Checking {
    
    public enum Result {
        /// represents an attributed substring that corresponds to a custom range of characters in the original attributed string
        case range(NSAttributedString)
        /// represents an attributed substring that corresponds to a regular expression pattern that was matched in the original attributed string
        case regex(NSAttributedString)
        #if os(iOS) || os(macOS)
        case action([ASAttributedString.Action])
        #endif
        #if !os(watchOS)
        case attachment(NSTextAttachment)
        #endif
        case date(Date)
        case link(URL)
        case address(Address)
        case phoneNumber(String)
        case transitInformation(TransitInformation)
        case macLink(URL)
    }
}

#if os(iOS) || os(macOS)

extension ASAttributedString.Checking {
    
    public struct Action {
        public typealias Trigger = ASAttributedString.Action.Trigger
        public typealias Highlight = ASAttributedString.Action.Highlight
        
        /// represents the type of interaction that should trigger the action
        let trigger: Trigger
        /// represents an array of highlight properties that should be applied to the attributed string when the action is triggered.
        let highlights: [Highlight]
        /// represents the closure that should be called when the action is triggered. The closure takes a Result argument, which represents the result of the check that was performed on the attributed string.
        let callback: (Result) -> Void
        
        public init(_ trigger: Trigger = .click, highlights: [Highlight] = .defalut, with callback: @escaping (Result) -> Void) {
            self.trigger = trigger
            self.highlights = highlights
            self.callback = callback
        }
    }
}

#endif

extension ASAttributedString.Checking.Result {
    
    public struct Date {
        let date: Foundation.Date?
        let duration: TimeInterval
        let timeZone: TimeZone?
    }
    
    public struct Address {
        let name: String?
        let jobTitle: String?
        let organization: String?
        let street: String?
        let city: String?
        let state: String?
        let zip: String?
        let country: String?
        let phone: String?
    }
    
    public struct TransitInformation {
        let airline: String?
        let flight: String?
    }
}

extension ASAttributedStringWrapper {
    
    public typealias Checking = ASAttributedString.Checking
}

public extension Array where Element == ASAttributedString.Checking {
    
    #if os(iOS) || os(macOS)
    static var defalut: [ASAttributedString.Checking] = [.date, .link, .address, .phoneNumber, .transitInformation, .action, .macLink]
    #else
    static var defalut: [ASAttributedString.Checking] = [.date, .link, .address, .phoneNumber, .transitInformation]
    #endif
    
    static let empty: [ASAttributedString.Checking] = []
}

extension ASAttributedString {
    
    public mutating func add(attributes: [Attribute], checkings: [Checking] = .defalut) {
        guard !attributes.isEmpty, !checkings.isEmpty else { return }
        
        #if os(iOS) || os(macOS)
        // 合并多个Action
        let attributes = attributes.mergedAction()

        #endif
        
        var temp: [NSAttributedString.Key: Any] = [:]
        attributes.forEach { temp.merge($0.attributes, uniquingKeysWith: { $1 }) }
        
        let matched = matching(checkings)
        let string = NSMutableAttributedString(attributedString: value)
        matched.forEach { string.addAttributes(temp, range: $0.0) }
        value = string
    }
    
    public mutating func set(attributes: [Attribute], checkings: [Checking] = .defalut) {
        guard !attributes.isEmpty, !checkings.isEmpty else { return }
        
        #if os(iOS) || os(macOS)
        // 合并多个Action
        let attributes = attributes.mergedAction()

        #endif
        
        var temp: [NSAttributedString.Key: Any] = [:]
        attributes.forEach { temp.merge($0.attributes, uniquingKeysWith: { $1 }) }
        
        let matched = matching(checkings)
        let string = NSMutableAttributedString(attributedString: value)
        matched.forEach { string.setAttributes(temp, range: $0.0) }
        value = string
    }
}

extension ASAttributedString {
    
    /// Matching checks (keys will not override, with priority in range > action > regex > other)
    /// - Parameter checkings: The checking types.
    /// - Returns: The matching results (range, checking type, checking result).
    func matching(_ checkings: [Checking]) -> [NSRange: (Checking, Checking.Result)] {
        guard !checkings.isEmpty else {
            return [:]
        }
        
        let checkings = checkings.filtered(duplication: \.self).sorted { $0.order < $1.order }
        var result: [NSRange: (Checking, Checking.Result)] = [:]
        
        func contains(_ range: NSRange) -> Bool {
            guard !result.keys.isEmpty else {
                return false
            }
            guard result[range] != nil else {
                return false
            }
            return result.keys.contains(where: { $0.overlap(range) })
        }
        
        checkings.forEach { (checking) in
            switch checking {
            case .range(let range) where !contains(range):
                let substring = value.attributedSubstring(from: range)
                result[range] = (checking, .range(substring))
                
            case .regex(let string):
                guard let regex = try? NSRegularExpression(pattern: string, options: .caseInsensitive) else { return }
                
                let matches = regex.matches(
                    in: value.string,
                    options: .init(),
                    range: .init(location: 0, length: value.length)
                )
                
                for match in matches where !contains(match.range) {
                    let substring = value.attributedSubstring(from: match.range)
                    result[match.range] = (checking, .regex(substring))
                }
                
            #if os(iOS) || os(macOS)
            case .action:
                let ranges: [NSRange: [Action]] = value.get(.action)
                for range in ranges where !contains(range.key) {
                    let actions = range.value.filter({ $0.isExternal })
                    result[range.key] = (.action, .action(actions))
                }
            #endif

            #if !os(watchOS)
            case .attachment:
                let attachments: [NSRange: NSTextAttachment] = value.get(.attachment)
                func allow(_ range: NSRange, _ attachment: NSTextAttachment) -> Bool {
                    #if os(iOS)
                    return !contains(range) && !(attachment is ViewAttachment)
                    #else
                    return !contains(range)
                    #endif
                }
                for attachment in attachments where allow(attachment.key, attachment.value) {
                    result[attachment.key] = (.attachment, .attachment(attachment.value))
                }
            #endif
            
            case .link:
                // Prioritize getting the value of the Link attribute
                let links: [NSRange: URL] = value.get(.link)
                for link in links where !contains(link.key) {
                    result[link.key] = (.link, .link(link.value))
                }
                fallthrough
            case .macLink:
                let links: [NSRange: URL] = value.get(.macLink)
                for link in links where !contains(link.key) {
                    result[link.key] = (.macLink, .macLink(link.value))
                }
            case .date, .address, .phoneNumber, .transitInformation:
                guard let detector = try? NSDataDetector(types: NSTextCheckingAllTypes) else { return }
                
                let matches = detector.matches(
                    in: value.string,
                    options: .init(),
                    range: .init(location: 0, length: value.length)
                )
                
                for match in matches where !contains(match.range) {
                    guard let type = match.resultType.map() else { continue }
                    guard checkings.contains(type) else { continue }
                    guard let mapped = match.map() else { continue }
                    result[match.range] = (type, mapped)
                }
                
            default:
                break
            }
        }
        
        return result
    }
}

fileprivate extension ASAttributedString.Checking {
    
    var order: Int {
        switch self {
        case .range:    return 0
        case .regex:    return 1
        #if os(iOS) || os(macOS)
        case .action:   return 2
        #endif
        default:        return 3
        }
    }
}

fileprivate extension ASAttributedString.Checking {
    
    func map() -> NSTextCheckingResult.CheckingType? {
        switch self {
        case .date:
            return .date
        
        case .link:
            return .link
        
        case .address:
            return .address
            
        case .phoneNumber:
            return .phoneNumber
            
        case .transitInformation:
            return .transitInformation
            
        default:
            return nil
        }
    }
}

fileprivate extension NSTextCheckingResult.CheckingType {
    
    func map() -> ASAttributedString.Checking? {
        switch self {
        case .date:
            return .date
        
        case .link:
            return .link
        
        case .address:
            return .address
            
        case .phoneNumber:
            return .phoneNumber
            
        case .transitInformation:
            return .transitInformation
            
        default:
            return nil
        }
    }
}

fileprivate extension NSTextCheckingResult {
    
    func map() -> ASAttributedString.Checking.Result? {
        switch resultType {
        case .date:
            return .date(
                .init(
                    date: date,
                    duration: duration,
                    timeZone: timeZone
                )
            )
        
        case .link:
            guard let url = url else { return nil }
            return .link(url)
        
        case .address:
            guard let components = addressComponents else { return nil }
            return .address(
                .init(
                    name: components[.name],
                    jobTitle: components[.jobTitle],
                    organization: components[.organization],
                    street: components[.street],
                    city: components[.city],
                    state: components[.state],
                    zip: components[.zip],
                    country: components[.country],
                    phone: components[.phone]
                )
            )
            
        case .phoneNumber:
            guard let number = phoneNumber else { return nil }
            return .phoneNumber(number)
            
        case .transitInformation:
            guard let components = components else { return nil }
            return .transitInformation(
                .init(
                    airline: components[.airline],
                    flight: components[.flight]
                )
            )
            
        default:
            return nil
        }
    }
}

fileprivate extension NSRange {
    
    func overlap(_ other: NSRange) -> Bool {
        guard
            let lhs = Range(self),
            let rhs = Range(other) else {
            return false
        }
        return lhs.overlaps(rhs)
    }
}
