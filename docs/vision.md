# Vision for smart-rename

## Purpose
Smart-rename is an AI-powered tool that brings intelligence to file organization by generating meaningful, descriptive filenames based on actual file content rather than arbitrary naming conventions.

## Core Philosophy
Files should be named based on what they contain, not when they were created or who created them. A filename should give you a good indication of what is in the file without needing to open it.

## Problem it solves
- Thousands of files with meaningless names like "IMG_4523.jpg" or "Document(1).pdf"
- Time wasted opening files to find what you need
- Inconsistent naming conventions across teams and projects
- Lost information when files are shared without context
- Special handling for financial documents that need date and amount information

## Design Principles

### 1. Content-First Naming
The filename should reflect the actual content, not metadata. it analyze the file's content using AI to understand what it represents.

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

## Roadmap

[ ] Integration with cloud storage providers
[ ] Support for more document types (presentations, spreadsheets)
[ ] Improved OCR for scanned documents
[ ] Folder organization suggestions
[ ] Smart categorization and tagging beyond just naming - probably with `tmsu tag` though open to suggestions

## Success Metrics
- A file can be identified by glancing filesname without needing to open and examine it
- Consistent naming across document libraries
- Reduced time spent organizing files
- Financial documents properly formatted for accounting software

## Non-Goals
- Not a document management system
- Not a backup solution
- Not trying to replace human judgment - augment it
- Not modifying file content, only names
