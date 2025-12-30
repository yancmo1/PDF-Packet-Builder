import XCTest
@testable import PDFPacketBuilder

final class CSVServiceTests: XCTestCase {
    
    private let csvService = CSVService()
    
    // MARK: - Basic Parsing (parsePreview)
    
    func testParsePreviewSimpleCSV() {
        let csv = "Name,Email\nJohn,john@example.com\nJane,jane@example.com"
        let result = csvService.parsePreview(data: csv)
        
        XCTAssertEqual(result.headers, ["Name", "Email"])
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0], ["John", "john@example.com"])
        XCTAssertEqual(result.rows[1], ["Jane", "jane@example.com"])
    }
    
    // MARK: - Quoted Fields
    
    func testParseQuotedFieldsWithCommas() {
        let csv = "Name,Address\nJohn,\"123 Main St, Apt 4\""
        let result = csvService.parsePreview(data: csv)
        
        XCTAssertEqual(result.rows[0][1], "123 Main St, Apt 4")
    }
    
    func testParseQuotedFieldsWithNewlines() {
        let csv = "Name,Note\nJohn,\"Line 1\nLine 2\""
        let result = csvService.parsePreview(data: csv)
        
        XCTAssertEqual(result.rows[0][1], "Line 1\nLine 2")
    }
    
    // MARK: - Escaped Quotes
    
    func testParseEscapedQuotes() {
        let csv = "Name,Quote\nJohn,\"He said \"\"Hello\"\"\""
        let result = csvService.parsePreview(data: csv)
        
        XCTAssertEqual(result.rows[0][1], "He said \"Hello\"")
    }
    
    // MARK: - Mixed Line Endings
    
    func testParseMixedLineEndings_LF() {
        let csv = "Name,Email\nJohn,john@example.com\nJane,jane@example.com"
        let result = csvService.parsePreview(data: csv)
        
        XCTAssertEqual(result.rows.count, 2)
    }
    
    func testParseMixedLineEndings_CRLF() {
        let csv = "Name,Email\r\nJohn,john@example.com\r\nJane,jane@example.com"
        let result = csvService.parsePreview(data: csv)
        
        XCTAssertEqual(result.rows.count, 2)
    }
    
    func testParseMixedLineEndings_Mixed() {
        let csv = "Name,Email\r\nJohn,john@example.com\nJane,jane@example.com\r\n"
        let result = csvService.parsePreview(data: csv)
        
        XCTAssertEqual(result.rows.count, 2)
    }
    
    // MARK: - Missing Values
    
    func testParseMissingValues() {
        let csv = "Name,Email,Phone\nJohn,,555-1234\n,jane@example.com,"
        let result = csvService.parsePreview(data: csv)
        
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0][0], "John")
        XCTAssertEqual(result.rows[0][1], "")
        XCTAssertEqual(result.rows[0][2], "555-1234")
        XCTAssertEqual(result.rows[1][0], "")
        XCTAssertEqual(result.rows[1][1], "jane@example.com")
    }
    
    func testParseEmptyCSV() {
        let csv = ""
        let result = csvService.parsePreview(data: csv)
        
        XCTAssertTrue(result.headers.isEmpty)
        XCTAssertTrue(result.rows.isEmpty)
    }
    
    func testParseHeadersOnly() {
        let csv = "Name,Email,Phone"
        let result = csvService.parsePreview(data: csv)
        
        XCTAssertEqual(result.headers, ["Name", "Email", "Phone"])
        XCTAssertTrue(result.rows.isEmpty)
    }
    
    // MARK: - Whitespace Handling
    
    func testParseTrimsWhitespace() {
        let csv = "  Name  ,  Email  \n  John  ,  john@example.com  "
        let result = csvService.parsePreview(data: csv)
        
        // Headers should be trimmed
        XCTAssertEqual(result.headers, ["Name", "Email"])
        // Values should be trimmed
        XCTAssertEqual(result.rows[0][0], "John")
        XCTAssertEqual(result.rows[0][1], "john@example.com")
    }
    
    // MARK: - Recipient Parsing (parseCSV)
    
    func testParseCSVCreatesRecipients() {
        let csv = "First Name,Last Name,Email\nJohn,Doe,john@example.com\nJane,Smith,jane@example.com"
        let recipients = csvService.parseCSV(data: csv)
        
        XCTAssertEqual(recipients.count, 2)
        XCTAssertEqual(recipients[0].firstName, "John")
        XCTAssertEqual(recipients[0].lastName, "Doe")
        XCTAssertEqual(recipients[0].email, "john@example.com")
        XCTAssertEqual(recipients[1].firstName, "Jane")
        XCTAssertEqual(recipients[1].lastName, "Smith")
    }
    
    func testParseCSVWithCustomFields() {
        let csv = "First Name,Last Name,Email,Company,Title\nJohn,Doe,john@example.com,Acme Inc,Manager"
        let recipients = csvService.parseCSV(data: csv)
        
        XCTAssertEqual(recipients.count, 1)
        XCTAssertEqual(recipients[0].customFields["Company"], "Acme Inc")
        XCTAssertEqual(recipients[0].customFields["Title"], "Manager")
    }
}
