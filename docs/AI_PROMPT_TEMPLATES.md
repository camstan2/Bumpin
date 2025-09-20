# AI Prompt Templates for Bumpin Development

## Overview
These templates help maintain consistency when using AI assistance for development. They are designed to minimize errors and maintain code quality.

## 1. Error Fixing Template

```markdown
I have a Swift compilation error in [FILE_NAME]:

ERROR: [EXACT_ERROR_MESSAGE]
LINE: [LINE_NUMBER]

CONTEXT:
[5-10 lines of code around the error]

Requirements:
1. Fix only this specific error
2. Don't change unrelated code
3. Follow existing patterns
4. Use minimal changes

Additional Context:
- File is part of [FEATURE] module
- Using [RELEVANT_FRAMEWORKS]
- Related to [FUNCTIONALITY]
```

## 2. New Feature Template

```markdown
I need to add [FEATURE] to Bumpin app.

Requirements:
1. Follow existing patterns
2. Use CommonImports.swift
3. Follow ServiceTemplate.swift/ViewTemplate.swift
4. Break complex views into components
5. Add proper error handling
6. Include analytics

Constraints:
- Don't modify existing working code
- Follow established architecture
- Use consistent naming
- Add necessary documentation

Current Context:
[RELEVANT_EXISTING_CODE]
```

## 3. Code Review Template

```markdown
Please review this code for potential issues:

[CODE_BLOCK]

Check for:
1. Import statements
2. Error handling
3. SwiftUI best practices
4. Service pattern compliance
5. View complexity
6. Analytics integration

Focus on preventing:
- Type-checking errors
- Missing imports
- Complex view bodies
- Inconsistent patterns
```

## 4. Refactoring Template

```markdown
Help me refactor this [VIEW/SERVICE] to follow our templates:

[CODE_BLOCK]

Goals:
1. Match ViewTemplate.swift/ServiceTemplate.swift
2. Break down complex logic
3. Improve maintainability
4. Keep functionality identical

Constraints:
- Preserve all features
- Maintain existing APIs
- Keep analytics
- Don't break dependencies
```

## 5. Bug Investigation Template

```markdown
I'm seeing this error in Bumpin:

ERROR: [ERROR_DESCRIPTION]

Context:
- File: [FILE_NAME]
- Feature: [FEATURE_NAME]
- Related Services: [SERVICES]
- Recent Changes: [CHANGES]

Please help:
1. Identify potential causes
2. Suggest debugging steps
3. Propose solutions
4. Prevent future occurrences
```

## Best Practices

1. **Always Include Context:**
   - File names
   - Error messages
   - Related code
   - Recent changes

2. **Be Specific:**
   - Exact error messages
   - Line numbers
   - Expected behavior
   - Current behavior

3. **Set Constraints:**
   - What shouldn't change
   - Required patterns
   - Performance requirements
   - Compatibility needs

4. **Request Explanations:**
   - Why changes are needed
   - How solutions work
   - Potential impacts
   - Future considerations

## Using with Different AI Models

### Claude 3.5 Sonnet (Recommended)
- Best for complex refactoring
- Great at understanding context
- Excellent for fixing errors
- Strong pattern recognition

### Other Models
- Adjust templates based on model capabilities
- Be more explicit with requirements
- Break down complex requests
- Verify suggestions carefully

## Example Usage

```markdown
I have a Swift compilation error in PartyView.swift:

ERROR: "The compiler is unable to type-check this expression in reasonable time"
LINE: 245

CONTEXT:
[Complex view body code]

Requirements:
1. Break down view using ViewTemplate.swift
2. Keep all functionality
3. Maintain analytics
4. Use existing patterns

Additional Context:
- Part of Party feature
- Uses SwiftUI and Firebase
- Related to real-time updates
```
