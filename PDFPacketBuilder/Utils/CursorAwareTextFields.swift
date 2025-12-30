import SwiftUI
import UIKit

/// Clamp NSRange to valid bounds within a string
func clampNSRange(_ range: NSRange, in text: String) -> NSRange {
    let length = (text as NSString).length
    let loc = min(max(0, range.location), length)
    let maxLen = max(0, length - loc)
    let len = min(max(0, range.length), maxLen)
    return NSRange(location: loc, length: len)
}

/// UITextField wrapper that tracks cursor position for token insertion
struct CursorAwareTextField: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    var placeholder: String
    var onBeginEditing: (() -> Void)?

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        field.borderStyle = .roundedRect
        field.placeholder = placeholder
        field.autocapitalizationType = .sentences
        field.autocorrectionType = .default
        field.addTarget(context.coordinator, action: #selector(Coordinator.textDidChange), for: .editingChanged)
        field.delegate = context.coordinator
        return field
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        guard uiView.isFirstResponder else { return }
        let clamped = clampNSRange(selection, in: text)
        if let start = uiView.position(from: uiView.beginningOfDocument, offset: clamped.location),
           let end = uiView.position(from: start, offset: clamped.length),
           let range = uiView.textRange(from: start, to: end) {
            uiView.selectedTextRange = range
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        private let parent: CursorAwareTextField

        init(_ parent: CursorAwareTextField) {
            self.parent = parent
        }

        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.onBeginEditing?()
            updateSelection(from: textField)
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            updateSelection(from: textField)
        }

        @objc func textDidChange(_ textField: UITextField) {
            parent.text = textField.text ?? ""
            updateSelection(from: textField)
        }

        private func updateSelection(from textField: UITextField) {
            guard let range = textField.selectedTextRange else { return }
            let start = textField.offset(from: textField.beginningOfDocument, to: range.start)
            let end = textField.offset(from: textField.beginningOfDocument, to: range.end)
            parent.selection = NSRange(location: max(0, start), length: max(0, end - start))
        }
    }
}

/// UITextView wrapper that tracks cursor position for token insertion
struct CursorAwareTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var selection: NSRange
    var onBeginEditing: (() -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(frame: .zero)
        view.isScrollEnabled = true
        view.backgroundColor = .systemBackground
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.delegate = context.coordinator
        view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        view.layer.cornerRadius = 8
        view.layer.masksToBounds = true
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        guard uiView.isFirstResponder else { return }
        let clamped = clampNSRange(selection, in: text)
        if uiView.selectedRange != clamped {
            uiView.selectedRange = clamped
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        private let parent: CursorAwareTextView

        init(_ parent: CursorAwareTextView) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onBeginEditing?()
            parent.selection = textView.selectedRange
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selection = textView.selectedRange
        }
    }
}
