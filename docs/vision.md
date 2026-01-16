# Vision for smart-rename

## Purpose
Smart-rename is an AI-powered tool that brings intelligence to file organization by generating meaningful, descriptive filenames based on actual file content rather than arbitrary naming conventions.

## Core Philosophy
Files should be named based on what they contain, not when they were created or who created them. A filename should tell you everything you need to know about a file without opening it.

## Problem We Solve
- Thousands of files with meaningless names like "IMG_4523.jpg" or "Document(1).pdf"
- Time wasted opening files to find what you need
- Inconsistent naming conventions across teams and projects
- Lost information when files are shared without context
- Special handling for financial documents that need date and amount information

## Design Principles

### 1. Content-First Naming
The filename should reflect the actual content, not metadata. We analyze the file's content using AI to understand what it represents.

### 2. Specialized Format Recognition
Different document types deserve different naming patterns:
- **Receipts/Invoices**: `YYYY-MM-DD-amount-vendor.ext` for easy sorting and tax purposes
- **Documents**: Descriptive names with dates when relevant
- **Images**: Context-aware descriptions of what's shown

### 3. User Control
- Interactive mode by default - users approve each rename
- Batch processing with patterns for efficiency
- Configurable AI providers based on user preference

### 4. Extensibility
- Support for multiple AI providers (OpenAI, Claude, Ollama)
- Configurable abbreviations for common entities
- Currency handling for international users

## Future Direction

### Near Term
- Integration with cloud storage providers
- Support for more document types (presentations, spreadsheets)
- Improved OCR for scanned documents
- Folder organization suggestions

### Long Term
- Learning from user corrections to improve suggestions
- Team-shared naming conventions
- Integration with document management systems
- Smart categorization and tagging beyond just naming

## Success Metrics
- Files can be found by name alone without searching content
- Consistent naming across an entire document library
- Reduced time spent organizing files
- Financial documents properly formatted for accounting software

## Non-Goals
- Not a document management system
- Not a backup solution
- Not trying to replace human judgment - augment it
- Not modifying file content, only names