# Architectural Decision Records (ADRs)

This directory contains all architectural decisions made for the MD TalkMan project.

## ADR Format

Each ADR follows this structure:
- **Context**: What situation led to this decision?
- **Decision**: What we decided to do
- **Rationale**: Why we made this choice
- **Consequences**: What are the positive/negative results?
- **Alternatives**: What other options were considered?

## Current ADRs

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-001](./ADR-001-Int32-For-Position-Tracking.md) | Use Int32 for Position Tracking | ✅ Accepted | 2025-08-15 |
| [ADR-002](./ADR-002-Visual-Text-Display.md) | Visual Text Display with Real-time Highlighting | ✅ Accepted | 2025-08-16 |
| [ADR-003](./ADR-003-Webhook-Architecture.md) | Go-based Webhook Server with APNs Integration | ✅ Accepted | 2025-08-24 |

## ADR Statuses

- 🟡 **Proposed**: Under discussion
- ✅ **Accepted**: Decision made and implemented  
- ❌ **Rejected**: Decision considered but not chosen
- ⚠️ **Deprecated**: No longer valid, superseded by newer ADR
- 🔄 **Superseded**: Replaced by a newer decision

## Future ADRs to Consider

- **TTS Position Strategy**: Time-based vs Character-based positioning
- **Memory Management**: Chunking vs Full-load vs Streaming
- **Audio Session Management**: Background playback strategy
- **GitHub Integration**: Repository sync architecture
- **Claude API Integration**: Context management and conversation history
- **CarPlay Integration**: UI and interaction patterns

## Guidelines

### When to Write an ADR
- Any decision that affects system architecture
- Choices between multiple technical approaches  
- Trade-offs that impact performance, maintainability, or user experience
- Decisions that team members might question later

### ADR Best Practices
- **Be specific**: Include code examples and metrics
- **Show alternatives**: Explain why other options were rejected
- **Include context**: Future developers need to understand the situation
- **Set review dates**: Decisions should be revisited periodically
- **Reference supporting research**: Link to relevant documentation

---

*This ADR system helps us maintain architectural consistency and provides context for future development decisions.*