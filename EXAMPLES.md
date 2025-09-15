# 💡 Examples & Workflows

Real-world examples and workflows for **zeke.nvim** to boost your productivity.

## 📖 Table of Contents

- [🚀 Quick Start Examples](#-quick-start-examples)
- [👨‍💻 Development Workflows](#-development-workflows)
- [🔍 Code Review Workflows](#-code-review-workflows)
- [📚 Learning Workflows](#-learning-workflows)
- [🛠️ Debugging Workflows](#️-debugging-workflows)
- [🏗️ Refactoring Workflows](#️-refactoring-workflows)
- [📝 Documentation Workflows](#-documentation-workflows)
- [🎯 Language-Specific Examples](#-language-specific-examples)
- [⚙️ Advanced Integration Examples](#️-advanced-integration-examples)

## 🚀 Quick Start Examples

### First Chat

```lua
-- Open Zeke and ask a question
:ZekeToggleChat
-- Type: "How do I implement a binary search in Rust?"
-- Press Ctrl+S to send
```

### Quick Code Explanation

```lua
-- 1. Open a code file
-- 2. Position cursor on complex function
-- 3. Explain it
:ZekeExplain

-- Result: Get explanation in floating window
```

### Instant Code Edit

```lua
-- 1. Open file with function needing improvement
-- 2. Edit with instruction
:ZekeEdit "Add error handling and improve performance"

-- 3. Review changes in diff view
-- Press 'a' to accept or 'r' to reject
```

### Context-Aware Help

```lua
-- 1. Add current file to context
:ZekeAddCurrent

-- 2. Ask context-aware question
:ZekeChat "What does this module do and how can I extend it?"
```

## 👨‍💻 Development Workflows

### New Feature Development

```lua
-- Workflow: Adding authentication to a web app

-- 1. Research phase
:ZekeToggleChat
-- Ask: "What are the best practices for JWT authentication in Node.js?"

-- 2. Architecture planning
:ZekeAddCurrent  -- Add main app file
:ZekeChat "How should I structure authentication middleware for this Express app?"

-- 3. Implementation
:ZekeCreate "JWT middleware for Express with error handling"
-- Review generated code in preview, save as auth.js

-- 4. Integration
:ZekeAddFile  -- Add new auth.js file to context
:ZekeEdit "Integrate this JWT middleware into the existing routes"

-- 5. Testing
:ZekeCreate "Unit tests for JWT authentication middleware"
-- Save as auth.test.js

-- 6. Documentation
:ZekeCreate "README section explaining how to use the authentication system"
```

### Bug Fixing Workflow

```lua
-- Workflow: Fixing a performance issue

-- 1. Add problematic file to context
:ZekeAddCurrent

-- 2. Analyze the issue
:ZekeAnalyze performance

-- 3. Get specific improvement suggestions
:ZekeChat "This function is running slowly with large datasets. How can I optimize it?"

-- 4. Apply improvements
:ZekeEdit "Optimize this function for better performance with large datasets"

-- 5. Verify fix
:ZekeAnalyze performance  -- Run analysis again
:ZekeChat "Is this optimization correct? Are there any edge cases I should consider?"
```

### API Development Workflow

```lua
-- Workflow: Building a REST API

-- 1. Design phase
:ZekeChat "Design a RESTful API for a task management system with CRUD operations"

-- 2. Create base structure
:ZekeCreate "Express.js server with basic routing structure for task API"

-- 3. Add individual endpoints
:ZekeAddCurrent  -- Add main server file
:ZekeCreate "GET /tasks endpoint with filtering and pagination"
:ZekeCreate "POST /tasks endpoint with validation"
:ZekeCreate "PUT /tasks/:id endpoint with error handling"
:ZekeCreate "DELETE /tasks/:id endpoint"

-- 4. Add middleware
:ZekeCreate "Validation middleware for task API endpoints"
:ZekeCreate "Error handling middleware for the API"

-- 5. Add tests
:ZekeCreate "Integration tests for task API endpoints"
```

## 🔍 Code Review Workflows

### Self Code Review

```lua
-- Workflow: Reviewing your own code before commit

-- 1. Add all changed files to context
:ZekeAddCurrent
:ZekeSearch "models"     -- Add related model files
:ZekeSearch "test"       -- Add test files

-- 2. Run comprehensive analysis
:ZekeAnalyze security
:ZekeAnalyze performance
:ZekeAnalyze quality

-- 3. Get overall assessment
:ZekeChat "Review this code for any issues, improvements, or bugs. Focus on maintainability and best practices."

-- 4. Check specific concerns
:ZekeChat "Are there any potential security vulnerabilities in this code?"
:ZekeChat "Is the error handling comprehensive enough?"
```

### Team Code Review

```lua
-- Workflow: Reviewing someone else's pull request

-- 1. Fetch the PR branch
-- git checkout pr-branch-name

-- 2. Add changed files to context
:ZekeAddCurrent
:ZekeAddFile path/to/changed/file.js
:ZekeAddFile path/to/test/file.test.js

-- 3. Understand the changes
:ZekeChat "Explain what this pull request does and the approach taken"

-- 4. Look for issues
:ZekeAnalyze security
:ZekeChat "Are there any code style issues or violations of best practices?"
:ZekeChat "Is this implementation efficient? Are there better alternatives?"

-- 5. Check test coverage
:ZekeChat "Is the test coverage adequate for these changes?"
```

### Legacy Code Review

```lua
-- Workflow: Understanding and improving legacy code

-- 1. Add legacy files to context
:ZekeAddCurrent
:ZekeSearch "util"       -- Add utility files
:ZekeSearch "config"     -- Add configuration

-- 2. Understand the system
:ZekeChat "Explain the architecture and data flow in this legacy codebase"

-- 3. Identify issues
:ZekeAnalyze quality
:ZekeChat "What are the main technical debt issues in this code?"

-- 4. Plan improvements
:ZekeChat "What's the safest way to refactor this code without breaking existing functionality?"

-- 5. Incremental improvements
:ZekeEdit "Improve this function while maintaining backward compatibility"
```

## 📚 Learning Workflows

### Learning New Language

```lua
-- Workflow: Learning Rust coming from JavaScript

-- 1. Start with basics
:ZekeChat "I'm a JavaScript developer learning Rust. Explain ownership and borrowing with examples"

-- 2. Compare concepts
:ZekeChat "How does Rust's module system compare to JavaScript's import/export?"

-- 3. Practice with examples
:ZekeCreate "Simple HTTP client in Rust using reqwest, with error handling"

-- 4. Learn patterns
:ZekeChat "What are the most important Rust patterns I should learn coming from JavaScript?"

-- 5. Build something real
:ZekeCreate "CLI tool in Rust that reads JSON files and filters data"
:ZekeAddCurrent
:ZekeChat "How can I improve this Rust code to be more idiomatic?"
```

### Understanding Complex Algorithms

```lua
-- Workflow: Learning how a complex algorithm works

-- 1. Get high-level explanation
:ZekeChat "Explain the A* pathfinding algorithm in simple terms with visual examples"

-- 2. See implementation
:ZekeCreate "A* pathfinding algorithm implementation in Python with comments"

-- 3. Understand step by step
:ZekeAddCurrent
:ZekeChat "Walk me through this A* implementation step by step"

-- 4. Try variations
:ZekeEdit "Modify this A* implementation to work with weighted graphs"

-- 5. Test understanding
:ZekeCreate "Unit tests for the A* algorithm with various test cases"
```

### Framework Learning

```lua
-- Workflow: Learning React hooks

-- 1. Understand concepts
:ZekeChat "Explain React hooks - useState, useEffect, useContext with examples"

-- 2. See practical examples
:ZekeCreate "React component using useState and useEffect to fetch and display user data"

-- 3. Learn best practices
:ZekeAddCurrent
:ZekeChat "What are the best practices for using hooks in this component?"

-- 4. Advanced patterns
:ZekeCreate "Custom React hook for API data fetching with loading and error states"

-- 5. Optimization
:ZekeChat "How can I optimize this React component's performance?"
```

## 🛠️ Debugging Workflows

### Runtime Error Investigation

```lua
-- Workflow: Debugging a crash in production

-- 1. Add error context
:ZekeAddCurrent          -- File where error occurs
:ZekeAddSelection        -- Select the problematic function

-- 2. Analyze the error
:ZekeChat "This function is throwing 'TypeError: Cannot read property of undefined'. Help me debug it."

-- 3. Add related files
:ZekeSearch "model"      -- Add data model files
:ZekeSearch "service"    -- Add service files

-- 4. Trace the issue
:ZekeChat "Trace through the data flow to find where this undefined value is coming from"

-- 5. Implement fix
:ZekeEdit "Fix this TypeError by adding proper null checks and validation"

-- 6. Prevent future issues
:ZekeEdit "Add TypeScript types or JSDoc annotations to prevent similar errors"
```

### Performance Investigation

```lua
-- Workflow: Investigating slow database queries

-- 1. Add database-related files
:ZekeAddCurrent          -- Main query file
:ZekeSearch "model"      -- Add ORM models
:ZekeSearch "migration"  -- Add database migrations

-- 2. Analyze performance
:ZekeAnalyze performance
:ZekeChat "This database query is slow. Analyze the query and suggest optimizations"

-- 3. Understand the data
:ZekeChat "Given this database schema, what indexes should I add to optimize these queries?"

-- 4. Optimize queries
:ZekeEdit "Optimize these database queries for better performance"

-- 5. Add monitoring
:ZekeCreate "Database query performance monitoring and logging"
```

### Memory Leak Investigation

```lua
-- Workflow: Finding memory leaks in JavaScript

-- 1. Add suspicious files
:ZekeAddCurrent
:ZekeSearch "event"      -- Event handling files
:ZekeSearch "service"    -- Service files

-- 2. Analyze for leaks
:ZekeChat "Analyze this code for potential memory leaks. Look for event listeners, closures, and circular references"

-- 3. Identify patterns
:ZekeChat "What are common memory leak patterns in JavaScript and how can I avoid them?"

-- 4. Fix issues
:ZekeEdit "Fix potential memory leaks in this code by properly cleaning up resources"

-- 5. Add safeguards
:ZekeCreate "Utility functions for safe event listener management and cleanup"
```

## 🏗️ Refactoring Workflows

### Extract Component/Module

```lua
-- Workflow: Breaking down a large component

-- 1. Analyze current structure
:ZekeAddCurrent
:ZekeAnalyze quality
:ZekeChat "This component is too large. How should I break it down into smaller components?"

-- 2. Plan the extraction
:ZekeChat "What should be extracted into separate components and what should remain?"

-- 3. Create new components
:ZekeCreate "UserProfile component extracted from the main Dashboard component"
:ZekeCreate "UserStats component for displaying user statistics"

-- 4. Update main component
:ZekeEdit "Refactor Dashboard component to use the new UserProfile and UserStats components"

-- 5. Update tests
:ZekeSearch "test"
:ZekeEdit "Update tests to work with the refactored component structure"
```

### Modernize Legacy Code

```lua
-- Workflow: Modernizing jQuery code to vanilla JS

-- 1. Understand current implementation
:ZekeAddCurrent
:ZekeChat "Explain what this jQuery code does and how it works"

-- 2. Plan modernization
:ZekeChat "How can I convert this jQuery code to modern vanilla JavaScript?"

-- 3. Convert step by step
:ZekeEdit "Convert this jQuery code to modern vanilla JavaScript with ES6+ features"

-- 4. Improve patterns
:ZekeEdit "Refactor this code to use modern JavaScript patterns like modules and classes"

-- 5. Add modern features
:ZekeEdit "Add async/await for API calls and improve error handling"
```

### Database Schema Refactoring

```lua
-- Workflow: Normalizing a database schema

-- 1. Analyze current schema
:ZekeAddCurrent          -- Migration files
:ZekeSearch "model"      -- ORM models
:ZekeAnalyze quality

-- 2. Identify issues
:ZekeChat "Analyze this database schema for normalization issues and suggest improvements"

-- 3. Plan migrations
:ZekeChat "What's the safest way to migrate this data to a normalized schema without downtime?"

-- 4. Create migrations
:ZekeCreate "Database migration to normalize user and profile tables"

-- 5. Update application code
:ZekeEdit "Update ORM models and queries to work with the new normalized schema"
```

## 📝 Documentation Workflows

### API Documentation

```lua
-- Workflow: Creating comprehensive API docs

-- 1. Add API files to context
:ZekeAddCurrent          -- Main API file
:ZekeSearch "route"      -- Route files
:ZekeSearch "controller" -- Controller files

-- 2. Generate overview
:ZekeCreate "OpenAPI/Swagger specification for this REST API"

-- 3. Document each endpoint
:ZekeChat "Generate detailed documentation for each API endpoint including examples"

-- 4. Add usage examples
:ZekeCreate "API usage examples in multiple programming languages"

-- 5. Create getting started guide
:ZekeCreate "Getting started guide for developers using this API"
```

### Code Documentation

```lua
-- Workflow: Adding comprehensive code documentation

-- 1. Document functions
:ZekeAddCurrent
:ZekeEdit "Add comprehensive JSDoc comments to all functions in this file"

-- 2. Add type information
:ZekeEdit "Add TypeScript type definitions for better IDE support"

-- 3. Create module documentation
:ZekeCreate "README.md file explaining this module's purpose and usage"

-- 4. Add examples
:ZekeEdit "Add usage examples to the function documentation"

-- 5. Generate docs
:ZekeChat "How can I set up automated documentation generation for this codebase?"
```

### Architecture Documentation

```lua
-- Workflow: Documenting system architecture

-- 1. Add key files to context
:ZekeAddCurrent
:ZekeSearch "config"
:ZekeSearch "service"
:ZekeSearch "model"

-- 2. Generate overview
:ZekeCreate "System architecture document explaining the overall design"

-- 3. Document data flow
:ZekeChat "Create a data flow diagram explanation for this system"

-- 4. Document patterns
:ZekeChat "Document the design patterns and architectural decisions used in this codebase"

-- 5. Add deployment docs
:ZekeCreate "Deployment and infrastructure documentation"
```

## 🎯 Language-Specific Examples

### Rust Examples

```lua
-- Error handling patterns
:ZekeCreate "Rust function demonstrating proper error handling with Result and Option types"

-- Async programming
:ZekeCreate "Async Rust HTTP client using tokio and reqwest with proper error handling"

-- Memory safety
:ZekeChat "Explain Rust ownership rules and show examples of borrowing vs moving"

-- Performance optimization
:ZekeAddCurrent
:ZekeEdit "Optimize this Rust code for better performance using zero-cost abstractions"
```

### Python Examples

```lua
-- Data processing
:ZekeCreate "Python script for processing CSV data with pandas and error handling"

-- API development
:ZekeCreate "FastAPI application with authentication, validation, and database integration"

-- Machine learning
:ZekeCreate "Simple machine learning pipeline using scikit-learn with proper data validation"

-- Async programming
:ZekeCreate "Asynchronous Python web scraper using aiohttp and asyncio"
```

### JavaScript/TypeScript Examples

```lua
-- React patterns
:ZekeCreate "React component using modern patterns: hooks, context, and TypeScript"

-- Node.js API
:ZekeCreate "Express.js API with TypeScript, validation, and comprehensive error handling"

-- Frontend optimization
:ZekeAddCurrent
:ZekeAnalyze performance
:ZekeEdit "Optimize this React component for better rendering performance"

-- Testing
:ZekeCreate "Comprehensive Jest tests for React component with mocking and coverage"
```

### Go Examples

```lua
-- Microservice
:ZekeCreate "Go microservice with HTTP server, middleware, and graceful shutdown"

-- Concurrency
:ZekeCreate "Go program demonstrating goroutines, channels, and worker pools"

-- Database integration
:ZekeCreate "Go application with PostgreSQL integration using GORM"

-- CLI tool
:ZekeCreate "Go CLI tool using cobra with subcommands and configuration"
```

## ⚙️ Advanced Integration Examples

### Git Integration

```lua
-- Pre-commit code review
vim.keymap.set('n', '<leader>gpr', function()
  -- Get staged files
  local staged = vim.fn.system('git diff --cached --name-only'):split('\n')
  for _, file in ipairs(staged) do
    if file ~= '' then
      require('zeke').add_file_to_context(file)
    end
  end
  require('zeke').analyze('quality')
  require('zeke').chat('Review these staged changes for any issues before commit')
end, { desc = 'Pre-commit review with Zeke' })

-- Commit message generation
vim.keymap.set('n', '<leader>gcm', function()
  local diff = vim.fn.system('git diff --cached')
  require('zeke').chat('Generate a conventional commit message for this diff:\n```diff\n' .. diff .. '\n```')
end, { desc = 'Generate commit message' })
```

### LSP Integration

```lua
-- Explain LSP diagnostics
vim.keymap.set('n', '<leader>zld', function()
  local diagnostics = vim.diagnostic.get(0)
  if #diagnostics == 0 then
    vim.notify('No diagnostics found')
    return
  end

  local messages = {}
  for _, diag in ipairs(diagnostics) do
    table.insert(messages, string.format('%s:%d: %s',
      vim.fn.fnamemodify(diag.filename or '', ':t'), diag.lnum + 1, diag.message))
  end

  local diagnostic_text = table.concat(messages, '\n')
  require('zeke').chat('Explain these LSP diagnostics and suggest fixes:\n' .. diagnostic_text)
end, { desc = 'Explain LSP diagnostics' })

-- Quick fix suggestions
vim.keymap.set('n', '<leader>zlf', function()
  local current_line = vim.api.nvim_get_current_line()
  local diagnostics = vim.diagnostic.get(0, { lnum = vim.fn.line('.') - 1 })

  if #diagnostics > 0 then
    require('zeke').add_current_file_to_context()
    require('zeke').chat(string.format('Fix this error on line %d: "%s"\nCode: %s',
      vim.fn.line('.'), diagnostics[1].message, current_line))
  end
end, { desc = 'Quick fix with Zeke' })
```

### Testing Integration

```lua
-- Generate tests for current function
vim.keymap.set('n', '<leader>ztg', function()
  -- Get current function (this is a simplified example)
  local current_function = vim.fn.expand('<cword>')
  require('zeke').add_current_file_to_context()
  require('zeke').create(string.format('Unit tests for the %s function', current_function))
end, { desc = 'Generate tests for current function' })

-- Test explanation
vim.keymap.set('n', '<leader>zte', function()
  require('zeke').add_current_file_to_context()
  require('zeke').chat('Explain what this test file is testing and suggest improvements')
end, { desc = 'Explain test file' })
```

### Project Management Integration

```lua
-- Project overview
vim.api.nvim_create_user_command('ZekeProjectOverview', function()
  require('zeke').workspace_search('package.json')  -- or Cargo.toml, etc.
  require('zeke').workspace_search('README')
  require('zeke').workspace_search('main')
  require('zeke').chat('Give me an overview of this project: its purpose, architecture, and main components')
end, { desc = 'Get project overview' })

-- Dependency analysis
vim.api.nvim_create_user_command('ZekeDependencyAnalysis', function()
  require('zeke').workspace_search('package.json')
  require('zeke').workspace_search('requirements.txt')
  require('zeke').workspace_search('Cargo.toml')
  require('zeke').chat('Analyze the dependencies in this project. Are they up to date? Any security concerns?')
end, { desc = 'Analyze project dependencies' })
```

### CI/CD Integration

```lua
-- Generate GitHub Actions workflow
vim.api.nvim_create_user_command('ZekeGenerateCI', function()
  require('zeke').workspace_search('package.json')
  require('zeke').workspace_search('test')
  require('zeke').create('GitHub Actions workflow for testing, building, and deploying this project')
end, { desc = 'Generate CI/CD workflow' })

-- Analyze build failures
vim.keymap.set('n', '<leader>zcf', function()
  vim.ui.input({ prompt = 'Paste build failure log: ' }, function(log)
    if log then
      require('zeke').add_current_file_to_context()
      require('zeke').chat('Analyze this build failure and suggest fixes:\n' .. log)
    end
  end)
end, { desc = 'Analyze CI/CD failures' })
```

---

These examples show how **zeke.nvim** can be integrated into every aspect of your development workflow. Start with the basic examples and gradually incorporate more advanced patterns as you become comfortable with the tool.

**Remember:** The key to effective AI assistance is providing good context and asking specific, well-formed questions!