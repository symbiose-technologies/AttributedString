//
//  AttributedStringAttribute.swift
//  ┌─┐      ┌───────┐ ┌───────┐
//  │ │      │ ┌─────┘ │ ┌─────┘
//  │ │      │ └─────┐ │ └─────┐
//  │ │      │ ┌─────┘ │ ┌─────┘
//  │ └─────┐│ └─────┐ │ └─────┐
//  └───────┘└───────┘ └───────┘
//
//  Created by Lee on 2019/11/18.
//  Copyright © 2019 LEE. All rights reserved.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

public extension NSAttributedString.Key {
    static let macLink: NSAttributedString.Key = .init("macLink")
}

extension ASAttributedString {
    
    /// 属性
    public struct Attribute {
        let attributes: [NSAttributedString.Key: Any]
    }
    
    /// 包装模式
    public enum WrapMode {
        case embedding(ASAttributedString)        // 嵌入模式
        case override(ASAttributedString)         // 覆盖模式
        
        internal var value: ASAttributedString {
            switch self {
            case .embedding(let value):     return value
            case .override(let value):      return value
            }
        }
    }
}

extension ASAttributedString.Attribute {
    
    public static func custom(_ value: [NSAttributedString.Key: Any]) -> Self {
        return .init(attributes: value)
    }
    
    public static func font(_ value: ASFont) -> Self {
        return .init(attributes: [.font: value])
    }
    
    public static func foreground(_ value: ASColor) -> Self {
        return .init(attributes: [.foregroundColor: value])
    }
    
    public static func background(_ value: ASColor) -> Self {
        return .init(attributes: [.backgroundColor: value])
    }
    
    public static func ligature(_ value: Bool) -> Self {
        return .init(attributes: [.ligature: value ? 1 : 0])
    }
    
    public static func kern(_ value: CGFloat) -> Self {
        return .init(attributes: [.kern: value])
    }
    
    public static func strikethrough(_ style: NSUnderlineStyle, color: ASColor? = nil) -> Self {
        var temp: [NSAttributedString.Key: Any] = [:]
        temp[.strikethroughColor] = color
        temp[.strikethroughStyle] = style.rawValue
        return .init(attributes: temp)
    }
    
    public static func underline(_ style: NSUnderlineStyle, color: ASColor? = nil) -> Self {
        var temp: [NSAttributedString.Key: Any] = [:]
        temp[.underlineColor] = color
        temp[.underlineStyle] = style.rawValue
        return .init(attributes: temp)
    }
    
    public static func link(_ value: String) -> Self {
        guard let url = URL(string: value) else { return .init(attributes: [:])}
        
        return link(url)
    }
    public static func link(_ value: URL) -> Self {
        return .init(attributes: [.link: value])
    }
    public static func macLink(_ value: URL) -> Self {
        return .init(attributes: [.macLink: value])
    }
    
    
    public static func baselineOffset(_ value: CGFloat) -> Self {
        return .init(attributes: [.baselineOffset: value])
    }
    
    public static func shadow(_ value: NSShadow) -> Self {
        return .init(attributes: [.shadow: value])
    }
    
    public static func stroke(_ width: CGFloat = 0, color: ASColor? = nil) -> Self {
        var temp: [NSAttributedString.Key: Any] = [:]
        temp[.strokeColor] = color
        temp[.strokeWidth] = width
        return .init(attributes: temp)
    }
    
    public static func textEffect(_ value: String) -> Self {
        return .init(attributes: [.textEffect: value])
    }
    public static func textEffect(_ value: NSAttributedString.TextEffectStyle) -> Self {
        return textEffect(value.rawValue)
    }
    
    public static func obliqueness(_ value: CGFloat = 0.1) -> Self {
        return .init(attributes: [.obliqueness: value])
    }
    
    public static func expansion(_ value: CGFloat = 0.0) -> Self {
        return .init(attributes: [.expansion: value])
    }
    
    public static func writingDirection(_ value: [Int]) -> Self {
        return .init(attributes: [.writingDirection: value])
    }
    public static func writingDirection(_ value: WritingDirection) -> Self {
        return writingDirection(value.value)
    }
    
    public static func verticalGlyphForm(_ value: Bool) -> Self {
        return .init(attributes: [.verticalGlyphForm: value ? 1 : 0])
    }
}

#if os(macOS)

extension ASAttributedString.Attribute {
    
    public static func cursor(_ value: NSCursor) -> Self {
        return .init(attributes: [.cursor: value])
    }
    
    public static func markedClauseSegment(_ value: Int) -> Self {
        return .init(attributes: [.markedClauseSegment: value])
    }
    
    public static func spellingState(_ value: SpellingState) -> Self {
        return .init(attributes: [.spellingState: value.rawValue])
    }
    
    public static func superscript(_ value: Int) -> Self {
        return .init(attributes: [.superscript: value])
    }
    
    public static func textAlternatives(_ value: NSTextAlternatives) -> Self {
        return .init(attributes: [.textAlternatives: value])
    }
    
    public static func toolTip(_ value: String) -> Self {
        return .init(attributes: [.toolTip: value])
    }
}

extension ASAttributedString.Attribute {
    
    /**
         This enum controls the display of the spelling and grammar indicators on text,
         highlighting portions of the text that are flagged for spelling or grammar issues.
         This should be used with `Attribute.spellingState`.
     */
    public enum SpellingState: Int {

        /// The spelling error indicator.
        case spelling = 1

        /// The grammar error indicator.
        case grammar = 2
    }
}

#endif

extension ASAttributedString.Attribute {
    
    public enum WritingDirection {
        case LRE
        case RLE
        case LRO
        case RLO
        
        fileprivate var value: [Int] {
            switch self {
            case .LRE:  return [NSWritingDirection.leftToRight.rawValue | NSWritingDirectionFormatType.embedding.rawValue]
                
            case .RLE:  return [NSWritingDirection.rightToLeft.rawValue | NSWritingDirectionFormatType.embedding.rawValue]
                
            case .LRO:  return [NSWritingDirection.leftToRight.rawValue | NSWritingDirectionFormatType.override.rawValue]
                
            case .RLO:  return [NSWritingDirection.rightToLeft.rawValue | NSWritingDirectionFormatType.override.rawValue]
            }
        }
    }
}

extension ASAttributedStringInterpolation {
    
    public typealias Attribute = ASAttributedString.Attribute
    public typealias WrapMode = ASAttributedString.WrapMode
    
    public mutating func appendInterpolation<T>(_ value: T, _ attributes: Attribute...) {
        appendInterpolation(value, with: attributes)
    }
    public mutating func appendInterpolation<T>(_ value: T, with attributes: [Attribute]) {
        self.value.append(ASAttributedString("\(value)", with: attributes).value)
    }
    
    public mutating func appendInterpolation(_ value: NSAttributedString, _ attributes: Attribute...) {
        appendInterpolation(value, with: attributes)
    }
    public mutating func appendInterpolation(_ value: NSAttributedString, with attributes: [Attribute]) {
        self.value.append(ASAttributedString(value, with: attributes).value)
    }
    
    public mutating func appendInterpolation(_ value: ASAttributedString, _ attributes: Attribute...) {
        appendInterpolation(value, with: attributes)
    }
    public mutating func appendInterpolation(_ value: ASAttributedString, with attributes: [Attribute]) {
        self.value.append(ASAttributedString(value, with: attributes).value)
    }
    
    // 嵌套包装
    public mutating func appendInterpolation(wrap string: ASAttributedString, _ attributes: Attribute...) {
        appendInterpolation(wrap: string, with: attributes)
    }
    public mutating func appendInterpolation(wrap string: ASAttributedString, with attributes: [Attribute]) {
        self.value.append(ASAttributedString(string, with: attributes).value)
    }
    
    public mutating func appendInterpolation(wrap mode: WrapMode, _ attributes: Attribute...) {
        appendInterpolation(wrap: mode, with: attributes)
    }
    public mutating func appendInterpolation(wrap mode: WrapMode, with attributes: [Attribute]) {
        self.value.append(ASAttributedString(wrap: mode, with: attributes).value)
    }
}
