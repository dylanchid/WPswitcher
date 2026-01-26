# Contributing

Thanks for contributing! Keep changes small, well-scoped, and easy to review.

## Workflow

1. Create a branch for your change.
2. Make focused edits.
3. Run tests when you change code.
4. Open a PR with a clear summary and testing notes.

## Testing

- Xcode: Product → Test (⌘U)
- CLI: `xcodebuild test -project WPswitcher.xcodeproj -scheme WPswitcher`

## Style

- Prefer SwiftUI views that are composed from small, focused subviews.
- Keep service/persistence logic out of views and in `Services` or `Persistence`.
- Name files to match their primary type.
