# Common Error Patterns and Solutions

## Overview
This document outlines common error patterns in the Bumpin app and their solutions. Use this as a reference when encountering build errors.

## 1. Import Errors

### Pattern: "Cannot find 'X' in scope"
```swift
❌ Error: Cannot find 'TopicChat' in scope
```
**Solution:**
1. Add import to CommonImports.swift if widely used
2. Add specific import to the file
3. Check if the type is in the correct module

### Pattern: "No such module 'X'"
```swift
❌ Error: No such module 'FirebaseFirestore'
```
**Solution:**
1. Check Podfile/SPM dependencies
2. Clean build folder and rebuild
3. Check target membership

## 2. Type Errors

### Pattern: "Type 'X' does not conform to protocol 'Y'"
```swift
❌ Error: Type 'MyView' does not conform to protocol 'View'
```
**Solution:**
1. Use ViewTemplate.swift as reference
2. Break large views into smaller components
3. Check for missing required properties

### Pattern: "Cannot convert value of type 'X' to 'Y'"
```swift
❌ Error: Cannot convert value of type 'String' to expected argument type 'Int'
```
**Solution:**
1. Check parameter types in method calls
2. Use proper type conversion
3. Verify API documentation

## 3. SwiftUI View Errors

### Pattern: "Unable to type-check this expression"
```swift
❌ Error: The compiler is unable to type-check this expression in reasonable time
```
**Solution:**
1. Break view into smaller components using ViewTemplate.swift
2. Extract complex logic to computed properties
3. Move business logic to ViewModel

### Pattern: "Ambiguous reference to member 'X'"
```swift
❌ Error: Ambiguous reference to member 'frame'
```
**Solution:**
1. Specify parameter labels
2. Check method overloads
3. Use type annotations

## 4. Service Errors

### Pattern: "Value of type 'X' has no member 'Y'"
```swift
❌ Error: Value of type 'AnalyticsService' has no member 'logEvent'
```
**Solution:**
1. Follow ServiceTemplate.swift pattern
2. Check for typos in method names
3. Verify service initialization

## 5. Firebase Errors

### Pattern: "No document exists at path"
```swift
❌ Error: No document exists at specified path
```
**Solution:**
1. Check Firestore rules
2. Verify document paths
3. Handle optional data properly

## Best Practices

1. **Always Run Build Check:**
   ```bash
   ./scripts/build-check.sh
   ```

2. **Follow Templates:**
   - Use CommonImports.swift
   - Follow ServiceTemplate.swift
   - Use ViewTemplate.swift

3. **Break Down Complex Views:**
   - Keep view bodies simple
   - Extract subviews
   - Use computed properties

4. **Handle Errors Properly:**
   - Use BumpinError enum
   - Implement error handling protocol
   - Show user-friendly messages

## When to Ask for Help

1. Multiple errors appearing together
2. Errors after merging code
3. Unexpected behavior with no errors
4. Performance issues

## Resources

1. SwiftUI Documentation
2. Firebase Documentation
3. Internal Templates
4. Build Scripts
