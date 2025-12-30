import XCTest
@testable import PDFPacketBuilder

final class RecipientTests: XCTestCase {
    
    // MARK: - Case-Insensitive Lookup
    
    func testValueForKey_CaseInsensitive() {
        let recipient = Recipient(
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com",
            customFields: ["Company": "Acme Inc"]
        )
        
        // Should find "Company" with different cases
        XCTAssertEqual(recipient.value(forKey: "company"), "Acme Inc")
        XCTAssertEqual(recipient.value(forKey: "COMPANY"), "Acme Inc")
        XCTAssertEqual(recipient.value(forKey: "Company"), "Acme Inc")
    }
    
    // MARK: - Built-in Field Lookup
    
    func testValueForKey_FirstName() {
        let recipient = Recipient(
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com"
        )
        
        XCTAssertEqual(recipient.value(forKey: "first_name"), "John")
        XCTAssertEqual(recipient.value(forKey: "First Name"), "John")
        XCTAssertEqual(recipient.value(forKey: "firstName"), "John")
        XCTAssertEqual(recipient.value(forKey: "givenName"), "John")
    }
    
    func testValueForKey_LastName() {
        let recipient = Recipient(
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com"
        )
        
        XCTAssertEqual(recipient.value(forKey: "last_name"), "Doe")
        XCTAssertEqual(recipient.value(forKey: "Last Name"), "Doe")
        XCTAssertEqual(recipient.value(forKey: "lastName"), "Doe")
        XCTAssertEqual(recipient.value(forKey: "surname"), "Doe")
    }
    
    func testValueForKey_FullName() {
        let recipient = Recipient(
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com"
        )
        
        XCTAssertEqual(recipient.value(forKey: "full_name"), "John Doe")
        XCTAssertEqual(recipient.value(forKey: "fullName"), "John Doe")
        XCTAssertEqual(recipient.value(forKey: "name"), "John Doe")
    }
    
    func testValueForKey_Email() {
        let recipient = Recipient(
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com"
        )
        
        XCTAssertEqual(recipient.value(forKey: "email"), "john@example.com")
        XCTAssertEqual(recipient.value(forKey: "Email"), "john@example.com")
        XCTAssertEqual(recipient.value(forKey: "EMAIL"), "john@example.com")
        XCTAssertEqual(recipient.value(forKey: "email_address"), "john@example.com")
    }
    
    func testValueForKey_Phone() {
        let recipient = Recipient(
            firstName: "John",
            lastName: "Doe",
            email: "",
            phoneNumber: "555-1234"
        )
        
        XCTAssertEqual(recipient.value(forKey: "phone"), "555-1234")
        XCTAssertEqual(recipient.value(forKey: "phone_number"), "555-1234")
        XCTAssertEqual(recipient.value(forKey: "mobile"), "555-1234")
        XCTAssertEqual(recipient.value(forKey: "tel"), "555-1234")
    }
    
    // MARK: - Custom Field Fallback
    
    func testValueForKey_CustomFieldExactMatch() {
        let recipient = Recipient(
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com",
            customFields: [
                "Title": "Manager",
                "Department": "Sales"
            ]
        )
        
        XCTAssertEqual(recipient.value(forKey: "Title"), "Manager")
        XCTAssertEqual(recipient.value(forKey: "Department"), "Sales")
    }
    
    func testValueForKey_CustomFieldCaseInsensitive() {
        let recipient = Recipient(
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com",
            customFields: ["Title": "Manager"]
        )
        
        XCTAssertEqual(recipient.value(forKey: "title"), "Manager")
        XCTAssertEqual(recipient.value(forKey: "TITLE"), "Manager")
    }
    
    // MARK: - Unknown Keys
    
    func testValueForKey_UnknownKeyReturnsNil() {
        let recipient = Recipient(
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com"
        )
        
        XCTAssertNil(recipient.value(forKey: "unknown_field"))
        XCTAssertNil(recipient.value(forKey: "nonexistent"))
    }
    
    // MARK: - Empty Values
    
    func testValueForKey_EmptyValueReturnsEmpty() {
        let recipient = Recipient(
            firstName: "",
            lastName: "Doe",
            email: "",
            customFields: ["Notes": ""]
        )
        
        XCTAssertEqual(recipient.value(forKey: "first_name"), "")
        XCTAssertEqual(recipient.value(forKey: "email"), "")
        XCTAssertEqual(recipient.value(forKey: "notes"), "")
    }
    
    // MARK: - Whitespace Handling
    
    func testValueForKey_WhitespaceInKey() {
        let recipient = Recipient(
            firstName: "John",
            lastName: "Doe",
            email: "john@example.com",
            customFields: ["Custom Field": "Value"]
        )
        
        // Key with whitespace should still match
        XCTAssertEqual(recipient.value(forKey: "  first_name  "), "John")
        XCTAssertEqual(recipient.value(forKey: "Custom Field"), "Value")
    }
}
