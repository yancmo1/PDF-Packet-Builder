import XCTest
@testable import PDFPacketBuilder

final class MessageTemplateRendererTests: XCTestCase {
    
    // MARK: - Token Extraction
    
    func testExtractTokens() {
        let text = "Hello {{first_name}}, welcome to {{company}}!"
        let tokens = MessageTemplateRenderer.extractTokens(from: text)
        
        XCTAssertEqual(tokens, ["first_name", "company"])
    }
    
    func testExtractTokensWithWhitespace() {
        let text = "Hello {{ first_name }}, welcome!"
        let tokens = MessageTemplateRenderer.extractTokens(from: text)
        
        XCTAssertEqual(tokens, ["first_name"])
    }
    
    func testExtractTokensEmpty() {
        let text = "No tokens here."
        let tokens = MessageTemplateRenderer.extractTokens(from: text)
        
        XCTAssertTrue(tokens.isEmpty)
    }
    
    // MARK: - Valid Token Replacement
    
    func testRenderValidTokens() {
        let template = MessageTemplate(
            subject: "Hello {{first_name}}",
            body: "Welcome!",
            isEnabled: true
        )
        let allowedTokens: Set<String> = ["first_name"]
        let resolvedValues: [String: String] = ["first_name": "John"]
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: allowedTokens,
            resolvedValues: resolvedValues
        )
        
        XCTAssertEqual(result.subject, "Hello John")
    }
    
    func testRenderMultipleTokens() {
        let template = MessageTemplate(
            subject: "Dear {{first_name}} {{last_name}}",
            body: "Your email is {{email}}.",
            isEnabled: true
        )
        let allowedTokens: Set<String> = ["first_name", "last_name", "email"]
        let resolvedValues: [String: String] = [
            "first_name": "Jane",
            "last_name": "Smith",
            "email": "jane@example.com"
        ]
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: allowedTokens,
            resolvedValues: resolvedValues
        )
        
        XCTAssertEqual(result.subject, "Dear Jane Smith")
        XCTAssertEqual(result.body, "Your email is jane@example.com.")
    }
    
    // MARK: - Unknown Tokens (Preserved)
    
    func testUnknownTokensPreserved() {
        let template = MessageTemplate(
            subject: "Hello {{unknown_token}}",
            body: "Welcome!",
            isEnabled: true
        )
        let allowedTokens: Set<String> = ["first_name"] // unknown_token not allowed
        let resolvedValues: [String: String] = [:]
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: allowedTokens,
            resolvedValues: resolvedValues
        )
        
        // Unknown tokens should be preserved in output
        XCTAssertEqual(result.subject, "Hello {{unknown_token}}")
        XCTAssertTrue(result.validation.unknownTokens.contains("unknown_token"))
    }
    
    // MARK: - Unresolved Tokens (Empty Value)
    
    func testUnresolvedTokensEmpty() {
        let template = MessageTemplate(
            subject: "Phone: {{phone}}",
            body: "",
            isEnabled: true
        )
        let allowedTokens: Set<String> = ["phone"]
        let resolvedValues: [String: String] = ["phone": ""] // Known but empty
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: allowedTokens,
            resolvedValues: resolvedValues
        )
        
        // Token is known but value is empty
        XCTAssertEqual(result.subject, "Phone: ")
        XCTAssertTrue(result.validation.unresolvedTokens.contains("phone"))
    }
    
    // MARK: - System Tokens
    
    func testSystemTokenSenderName() {
        let template = MessageTemplate(
            subject: "From: {{sender_name}}",
            body: "",
            isEnabled: true
        )
        let allowedTokens = MessageTemplateRenderer.systemTokens
        let resolvedValues: [String: String] = ["sender_name": "Alice Sender"]
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: allowedTokens,
            resolvedValues: resolvedValues
        )
        
        XCTAssertEqual(result.subject, "From: Alice Sender")
    }
    
    func testSystemTokenSenderEmail() {
        let template = MessageTemplate(
            subject: "Reply to: {{sender_email}}",
            body: "",
            isEnabled: true
        )
        let allowedTokens = MessageTemplateRenderer.systemTokens
        let resolvedValues: [String: String] = ["sender_email": "sender@example.com"]
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: allowedTokens,
            resolvedValues: resolvedValues
        )
        
        XCTAssertEqual(result.subject, "Reply to: sender@example.com")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyTemplate() {
        let template = MessageTemplate(
            subject: "",
            body: "",
            isEnabled: true
        )
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: [],
            resolvedValues: [:]
        )
        
        XCTAssertEqual(result.subject, "")
        XCTAssertEqual(result.body, "")
    }
    
    func testNoTokensInTemplate() {
        let template = MessageTemplate(
            subject: "Static Subject",
            body: "This is a static message with no tokens.",
            isEnabled: true
        )
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: [],
            resolvedValues: [:]
        )
        
        XCTAssertEqual(result.subject, "Static Subject")
        XCTAssertEqual(result.body, "This is a static message with no tokens.")
    }
    
    func testMalformedTokensUnchanged() {
        let template = MessageTemplate(
            subject: "Hello {{incomplete",
            body: "And {{also_broken",
            isEnabled: true
        )
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: ["incomplete", "also_broken"],
            resolvedValues: [:]
        )
        
        // Malformed tokens (no closing }}) should be left as-is
        XCTAssertEqual(result.subject, "Hello {{incomplete")
        XCTAssertEqual(result.body, "And {{also_broken")
    }
    
    // MARK: - Validation
    
    func testValidationDetectsUnknownTokens() {
        let template = MessageTemplate(
            subject: "Hello {{known}} and {{unknown}}",
            body: "",
            isEnabled: true
        )
        let allowedTokens: Set<String> = ["known"]
        let resolvedValues: [String: String] = ["known": "Value"]
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: allowedTokens,
            resolvedValues: resolvedValues
        )
        
        XCTAssertTrue(result.validation.unknownTokens.contains("unknown"))
        XCTAssertFalse(result.validation.unknownTokens.contains("known"))
    }
    
    func testValidationDetectsUnresolvedTokens() {
        let template = MessageTemplate(
            subject: "Hello {{first_name}}",
            body: "",
            isEnabled: true
        )
        let allowedTokens: Set<String> = ["first_name"]
        let resolvedValues: [String: String] = ["first_name": "  "] // Whitespace only = unresolved
        
        let result = MessageTemplateRenderer.render(
            template: template,
            allowedTokens: allowedTokens,
            resolvedValues: resolvedValues
        )
        
        XCTAssertTrue(result.validation.unresolvedTokens.contains("first_name"))
    }
}
