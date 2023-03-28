//
//  NSTextFieldExtension.swift
//  AttributedString
//
//  Created by Lee on 2020/4/8.
//  Copyright © 2020 LEE. All rights reserved.
//

#if os(macOS)

import AppKit

private var NSGestureRecognizerKey: Void?
private var NSEventMonitorKey: Void?
private var NSTextFieldTouchedKey: Void?
private var NSTextFieldActionsKey: Void?
private var NSTextFieldObserversKey: Void?
private var NSTextFieldMouseInsideKey: Void?


extension NSTextField: ASAttributedStringCompatible {
    
}



extension ASAttributedStringWrapper where Base: NSTextField {

    public var string: ASAttributedString {
        get { base.touched?.0 ?? .init(base.attributedStringValue) }
        set {
            // Determine if the current state is in touch and if the content has changed.
            if var current = base.touched, current.0.isContentEqual(to: newValue) {
                current.0 = newValue
                base.touched = current
                
                // Overlay the current highlight attribute onto the new text
                // Replace the displayed text.
                let temp = NSMutableAttributedString(attributedString: newValue.value)
                let ranges = current.1.keys.sorted(by: { $0.length > $1.length })
                for range in ranges {
                    base.attributedStringValue.get(range).forEach { (range, attributes) in
                        temp.setAttributes(attributes, range: range)
                    }
                }
                base.attributedStringValue = temp
                
            } else {
                base.attributedStringValue = ASAttributedString(
                    newValue.value,
                    .font(base.font ?? .systemFont(ofSize: 13)),
                    .paragraph(
                        .alignment(base.alignment),
                        .baseWritingDirection(base.baseWritingDirection)
                    )
                ).value
            }
            
            // Set actions and gestures.
            setupActions(newValue)
            setupGestureRecognizers()
        }
    }
    
    public var placeholder: ASAttributedString? {
        get { ASAttributedString(base.placeholderAttributedString) }
        set { base.placeholderAttributedString = newValue?.value }
    }
}

extension ASAttributedStringWrapper where Base: NSTextField {
    
    /// Add listener.
    /// - Parameters:
    ///   - checking: Type of checking
    ///   - action: Checking action
    public func observe(_ checking: Checking, with action: Checking.Action) {
        var temp = base.observers
        if var value = temp[checking] {
            value.append(action)
            temp[checking] = value
            
        } else {
            temp[checking] = [action]
        }
        base.observers = temp
    }
    
    /// Add listener
    /// - Parameters:
    ///   - checking: Type of checking
    ///   - highlights: Highlight styles
    ///   - callback: Callback triggered
    public func observe(_ checking: Checking,
                        highlights: [Highlight] = .defalut,
                        with callback: @escaping (Checking.Result) -> Void) {
        observe(checking, with: .init(.click, highlights: highlights, with: callback))
    }
    
    /// Add listener
    /// - Parameters:
    ///   - checkings: Types of checking
    ///   - highlights: Highlight styles
    ///   - callback: Callback triggered
    public func observe(_ checkings: [Checking] = .defalut,
                        highlights: [Highlight] = .defalut,
                        with callback: @escaping (Checking.Result) -> Void) {
        checkings.forEach {
            observe($0, highlights: highlights, with: callback)
        }
    }
    

    /// Remove listener
    /// - Parameter checking: Type of checking
    public func remove(checking: Checking) {
        base.observers.removeValue(forKey: checking)
    }
    
    /// Remove listener
    /// - Parameter checkings: Types of checking
    public func remove(checkings: [Checking]) {
        checkings.forEach { base.observers.removeValue(forKey: $0) }
    }
}

extension ASAttributedStringWrapper where Base: NSTextField {
    
    
    
    private(set) var gestures: [NSGestureRecognizer] {
        get { base.associated.get(&NSGestureRecognizerKey) ?? [] }
        set { base.associated.set(retain: &NSGestureRecognizerKey, newValue) }
    }
    
    private(set) var monitors: [Any] {
        get { base.associated.get(&NSEventMonitorKey) ?? [] }
        set { base.associated.set(retain: &NSEventMonitorKey, newValue) }
    }
    
    /// Set actions
    private func setupActions(_ string: ASAttributedString?) {
        // Clear original action records
        base.actions = [:]
        
        guard let string = string else {
            return
        }
        // Get current actions
        base.actions = string.value.get(.action)
        // Get matching checking and add checking action
        let observers = base.observers
        string.matching(.init(observers.keys)).forEach { (range, checking) in
            let (type, result) = checking
            if var temp = base.actions[range] {
                for action in observers[type] ?? [] {
                    temp.append(
                        .init(
                            action.trigger,
                            action.highlights
                        ) { _ in
                            action.callback(result)
                        }
                    )
                }
                base.actions[range] = temp
                
            } else {
                base.actions[range] = observers[type]?.map { action in
                    .init(
                        action.trigger,
                        action.highlights
                    ) { _ in
                        action.callback(result)
                    }
                }
            }
        }
        
        // Add handle closure to all actions
        base.actions = base.actions.reduce(into: [:]) {
            let result: Action.Result = string.value.get($1.key)
            let actions: [Action] = $1.value.reduce(into: []) {
                var temp = $1
                temp.handle = {
                    temp.callback(result)
                }
                $0.append(temp)
            }
            $0[$1.key] = actions
        }
    }
    
    /// Set gesture recognition
    private func setupGestureRecognizers() {
        gestures.forEach { base.removeGestureRecognizer($0) }
        gestures = []
        
        let triggers = base.actions.values.flatMap({ $0 }).map({ $0.trigger })
        Set(triggers).forEach {
            switch $0 {
            case .click:
                let gesture = NSClickGestureRecognizer(target: base, action: #selector(Base.attributedAction))
                base.addGestureRecognizer(gesture)
                gestures.append(gesture)
                
            case .press:
                let gesture = NSPressGestureRecognizer(target: base, action: #selector(Base.attributedAction))
                base.addGestureRecognizer(gesture)
                gestures.append(gesture)
            }
        }
        
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
        guard base.isActionEnabled else { return }
//        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .mouseEntered, handler: { (event) in
//            print("[NSTextFieldExtension] mouseEntered")
//            return event
//        }) {
//            monitors.append(monitor)
//        }
//        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .mouseExited, handler: { (event) in
//            print("[NSTextFieldExtension] mouseExited")
//            return event
//        }) {
//            monitors.append(monitor)
//        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { (event) in
            self.base.attributed_mouseMoved(with: event)
            return event
        }) {
            monitors.append(monitor)
        }
        
        
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown, handler: { (event) -> NSEvent? in
            self.base.attributed_mouseDown(with: event)
            return event
        }) {
            monitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp, handler: { (event) -> NSEvent? in
            self.base.attributed_mouseUp(with: event)
            return event
        }) {
            monitors.append(monitor)
        }
    }
}

extension NSTextField {
    
    fileprivate typealias Action = ASAttributedString.Action
    fileprivate typealias Checking = ASAttributedString.Checking
    fileprivate typealias Highlight = ASAttributedString.Action.Highlight
    fileprivate typealias Observers = [Checking: [Checking.Action]]
    
    /// Whether Action is enabled
    fileprivate var isActionEnabled: Bool {
        return !attributed.gestures.isEmpty && (!isEditable)
//        return !attributed.gestures.isEmpty && (!isEditable && !isSelectable)
    }
    
    var mouseInside: Bool {
        get { associated.get(&NSTextFieldMouseInsideKey) ?? false }
        set { associated.set(retain: &NSTextFieldMouseInsideKey, newValue) }
        
    }
    
    
    /// Touch information
    fileprivate var touched: (ASAttributedString, [NSRange: [Action]])? {
        get { associated.get(&NSTextFieldTouchedKey) }
        set { associated.set(retain: &NSTextFieldTouchedKey, newValue) }
    }
    /// All actions
    fileprivate var actions: [NSRange: [Action]] {
        get { associated.get(&NSTextFieldActionsKey) ?? [:] }
        set { associated.set(retain: &NSTextFieldActionsKey, newValue) }
    }
    /// Observer information
    fileprivate var observers: Observers {
        get { associated.get(&NSTextFieldObserversKey) ?? [:] }
        set { associated.set(retain: &NSTextFieldObserversKey, newValue) }
    }
    
    @objc
    func attributed_mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), window == event.window else {
            if mouseInside {
                mouseInside = false
            }
            return
        }
        if !mouseInside {
            mouseInside = true
        }
        guard isActionEnabled else { return }
        
    }
    
    @objc
    func attributed_mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard bounds.contains(point), window == event.window else { return }
        guard isActionEnabled else { return }
        let results = matching(point)
        guard !results.isEmpty else { return }
        let string = attributed.string
        // Backup current information
        touched = (string, results)
        // Set highlight styles
        let ranges = results.keys.sorted(by: { $0.length > $1.length })
        for range in ranges {
            var temp: [NSAttributedString.Key: Any] = [:]
            results[range]?.first?.highlights.forEach {
                temp.merge($0.attributes, uniquingKeysWith: { $1 })
            }
            attributedStringValue = attributedStringValue.reset(range: range) { (attributes) in
                attributes.merge(temp, uniquingKeysWith: { $1 })
            }
        }
    }
    
    @objc
    func attributed_mouseUp(with event: NSEvent) {
        guard isActionEnabled else { return }
        DispatchQueue.main.async {
            guard let current = self.touched else { return }
            self.touched = nil
            self.attributedStringValue = current.0.value
        }
    }
}

fileprivate extension NSTextField {
    
    @objc
    func attributedAction(_ sender: NSGestureRecognizer) {
        guard sender.state == .ended else { return }
        guard isActionEnabled else { return }
        guard let touched = self.touched else { return }
        let actions = touched.1.flatMap({ $0.value })
        for action in actions where action.trigger.matching(sender) {
            action.handle?()
        }
    }
    
    func matching(_ point: CGPoint) -> [NSRange: [Action]] {
        let attributedString = ASAttributedString(attributedStringValue)
        
        // Build TextKit settings synchronized with Label
        let textStorage = NSTextStorage(attributedString: attributedString.value)
        let textContainer = NSTextContainer(size: bounds.size)
        let layoutManager = NSLayoutManager()
        textContainer.lineBreakMode = lineBreakMode
        textContainer.lineFragmentPadding = 0.0
        textContainer.maximumNumberOfLines = usesSingleLineMode ? 1 : 0
        layoutManager.usesFontLeading = false // Do not use the font header because non-system fonts may cause issues
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        // Ensure layout
        layoutManager.ensureLayout(for: textContainer)
        
        // Get glyph index
        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        // Get character index
        let index = layoutManager.characterIndexForGlyph(at: glyphIndex)
        // Determine if the glyph is within range based on the distance through the glyph
        guard fraction > 0, fraction < 1 else {
            return [:]
        }
        // Get range of string tapped and associated callback events
        let ranges = actions.keys.filter({ $0.contains(index) })
        return ranges.reduce(into: [:]) {
            $0[$1] = actions[$1]
        }
    }
}

#endif
