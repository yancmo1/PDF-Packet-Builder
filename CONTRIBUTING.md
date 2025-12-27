# Contributing to PDF Packet Sender

First off, thank you for considering contributing to PDF Packet Sender! It's people like you that make this tool better for everyone.

## Code of Conduct

This project and everyone participating in it is governed by respect and professionalism. Please be kind and considerate.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

**Bug Report Template:**
```
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Go to '...'
2. Click on '....'
3. See error

**Expected behavior**
What you expected to happen.

**Screenshots**
If applicable, add screenshots.

**Environment:**
 - Device: [e.g. iPhone 14 Pro]
 - iOS Version: [e.g. 16.0]
 - App Version: [e.g. 1.0]

**Additional context**
Any other context about the problem.
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Clear title and description** of the enhancement
- **Use cases** - why would this be useful?
- **Possible implementation** - if you have ideas

### Pull Requests

1. **Fork the repo** and create your branch from `main`
2. **Make your changes**
3. **Test thoroughly**
4. **Update documentation** if needed
5. **Submit a pull request**

**Pull Request Template:**
```
**Description**
Brief description of changes.

**Motivation and Context**
Why is this change required? What problem does it solve?

**How Has This Been Tested?**
Describe tests you ran.

**Types of changes**
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)

**Checklist:**
- [ ] My code follows the code style of this project
- [ ] I have updated the documentation accordingly
- [ ] I have added tests to cover my changes
- [ ] All new and existing tests passed
```

## Development Setup

See [SETUP.md](SETUP.md) for detailed setup instructions.

Quick setup:
1. Clone the repository
2. Open in Xcode
3. Configure bundle identifier
4. Build and run

## Coding Style

### Swift Style Guide

We follow Apple's Swift API Design Guidelines:

**Naming:**
```swift
// Good
func calculateTotalPrice(for items: [Item]) -> Double
var isUserLoggedIn: Bool
let maximumRetryCount = 3

// Avoid
func calcTotPrice(items: [Item]) -> Double
var userLoggedIn: Bool
let MAX_RETRY = 3
```

**Comments:**
```swift
// Use comments to explain WHY, not WHAT
// Good
// Retry network request because API is unreliable
retryRequest()

// Avoid - comment states the obvious
// Call retry request
retryRequest()
```

**Code Organization:**
- Group related functionality with `// MARK: -`
- One type per file (except small helper types)
- Organize files by feature, not by type

### SwiftUI Conventions

**View Structure:**
```swift
struct MyView: View {
    // MARK: - Properties
    @State private var someState = false
    @EnvironmentObject var appState: AppState
    
    // MARK: - Body
    var body: some View {
        // View hierarchy
    }
    
    // MARK: - Computed Properties
    private var computedValue: String {
        // Implementation
    }
    
    // MARK: - Methods
    private func handleAction() {
        // Implementation
    }
}

// MARK: - Preview
struct MyView_Previews: PreviewProvider {
    static var previews: some View {
        MyView()
    }
}
```

## Git Commit Messages

Format:
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, missing semicolons, etc.
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding missing tests
- `chore`: Maintain

**Examples:**
```
feat: Add PDF encryption support

Implement AES-256 encryption for generated PDFs. Users can now
set a password when generating personalized documents.

Closes #123
```

```
fix: Correct CSV parsing for quoted fields

Fields containing commas were incorrectly split. Now properly
handles quoted values like "Last, First".

Fixes #456
```

## Testing

### Manual Testing
- Test on both simulator and device
- Test with various PDF formats
- Test with large recipient lists
- Test all IAP flows

### Automated Testing (Future)
- Write unit tests for services
- Write UI tests for critical flows
- Maintain >80% code coverage

## Documentation

When adding features:
- Update README.md with user-facing changes
- Update ARCHITECTURE.md with technical details
- Add inline code comments for complex logic
- Update DEVELOPER_GUIDE.md if needed

## Project Structure

Maintain the current structure:
```
PDFPacketSender/
├── Models/          # Data models
├── Views/           # UI components
├── Services/        # Business logic
├── IAP/            # In-app purchases
├── Utils/          # Utilities
└── Resources/      # Assets, configs
```

## Adding Dependencies

We prefer to minimize dependencies. Before adding a new dependency:

1. **Check if it's necessary** - Can we implement it ourselves?
2. **Evaluate alternatives** - Are there lighter options?
3. **Check license** - Is it compatible?
4. **Consider maintenance** - Is it actively maintained?
5. **Discuss in issue** - Get team feedback

If approved, use Swift Package Manager:
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/...", from: "1.0.0")
]
```

## Performance Guidelines

- Use background threads for heavy operations
- Show progress indicators for long tasks
- Optimize list rendering for large datasets
- Profile with Instruments before optimizing
- Keep app binary size under 50MB

## Security Guidelines

- Never commit secrets or API keys
- Validate all user input
- Use secure coding practices
- Handle errors gracefully
- Respect user privacy

## Review Process

1. **Submit PR** with clear description
2. **Automated checks** run (if configured)
3. **Code review** by maintainer
4. **Address feedback** if needed
5. **Merge** when approved

## Questions?

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for technical details
- Read [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) for dev info
- Open an issue for questions
- Tag with `question` label

## Recognition

Contributors will be listed in the README. Significant contributions may warrant special recognition.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to PDF Packet Sender! 🎉
