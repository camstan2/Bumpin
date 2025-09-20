# Pull Request

## Description
<!-- Describe your changes in detail -->

## Type of Change
<!-- Mark relevant items with an x -->
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] This change requires a documentation update

## Quality Checklist
<!-- Mark completed items with an x -->

### Code Quality
- [ ] Changes follow ServiceTemplate.swift/ViewTemplate.swift patterns
- [ ] SwiftLint passes with no warnings
- [ ] Build check script passes (`./scripts/build-check.sh`)
- [ ] Complex views are broken down into components
- [ ] Error handling is implemented properly
- [ ] Analytics are integrated where appropriate

### Testing
- [ ] Manual testing completed on iPhone simulator
- [ ] Manual testing completed on iPad simulator (if applicable)
- [ ] Edge cases and error scenarios tested
- [ ] Performance impact considered and tested

### Documentation
- [ ] Code is self-documenting and follows naming conventions
- [ ] Comments added for complex logic
- [ ] Documentation updated (README, guides, etc.)
- [ ] API documentation updated (if applicable)

### Error Prevention
- [ ] Error logging implemented for new features/changes
- [ ] No new compiler warnings introduced
- [ ] No SwiftUI view complexity warnings
- [ ] No force unwrapping or implicitly unwrapped optionals

### Dependencies
- [ ] All imports are necessary and follow CommonImports.swift
- [ ] No circular dependencies introduced
- [ ] Third-party dependencies properly attributed

## Testing Steps
<!-- List steps to test your changes -->
1. 
2. 
3. 

## Related Issues
<!-- Link to related issues -->
Fixes #

## Screenshots/Videos
<!-- If applicable, add screenshots or videos -->

## Additional Notes
<!-- Add any other context about the PR here -->

## Pre-merge Checklist
- [ ] Branch is up to date with main
- [ ] All discussions resolved
- [ ] All review comments addressed
- [ ] CI/CD checks pass
- [ ] Documentation updated
- [ ] Version numbers updated (if needed)

## Post-merge Tasks
- [ ] Delete branch after merging
- [ ] Update project board
- [ ] Notify relevant team members
- [ ] Monitor error logs after deployment
