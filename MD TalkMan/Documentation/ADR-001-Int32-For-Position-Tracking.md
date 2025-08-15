# ADR-001: Use Int32 for Position Tracking in Bookmarks

**Date**: 2025-08-15  
**Status**: ✅ **ACCEPTED**  
**Context**: TTS position tracking and bookmark storage data types

---

## Context

We need to choose an appropriate data type for storing character positions in markdown files for TTS bookmarking and progress tracking. Initial concern was whether Int32 would be sufficient for large markdown files.

## Decision

**We will use Int32 for position tracking instead of upgrading to Int64.**

## Rationale

### File Size Analysis
- **Typical markdown files**: 1KB - 10MB
- **Large technical docs**: 10MB - 50MB  
- **Extremely large files**: 50MB+ (very rare)

### Int32 Capacity
- **Range**: -2,147,483,648 to 2,147,483,647
- **Practical capacity**: ~2.1 billion characters ≈ 2GB text
- **Real-world buffer**: 50MB file = ~50 million characters (40x safety margin)

### Industry Reality Check
- **Largest markdown files encountered**: <100MB
- **Typical use case**: 1-10MB documentation
- **Overflow scenario**: Would require 2GB+ single markdown file (unprecedented)

### Trade-offs Considered

#### Option A: Upgrade to Int64 ❌
- **Pros**: Handles theoretical 9+ exabyte files
- **Cons**: 
  - Doubles storage space (4 bytes → 8 bytes per position)
  - Over-engineering for problem that doesn't exist
  - Core Data migration complexity
  - No real-world benefit

#### Option B: Keep Int32 ✅ **CHOSEN**
- **Pros**:
  - Sufficient for 40+ years of realistic usage
  - Smaller storage footprint
  - No migration needed
  - Industry-appropriate sizing
- **Cons**: 
  - Theoretical limit at 2GB files

## Consequences

### Positive
- **Memory efficient**: 4 bytes vs 8 bytes per bookmark
- **No breaking changes**: Existing Core Data schema works
- **Future-proof**: Handles realistic growth for decades
- **Performance**: Smaller integers = faster operations

### Risk Mitigation
- **Monitoring**: Log file sizes in analytics
- **Graceful degradation**: If we ever hit Int32 limits, can implement file splitting
- **Future upgrade path**: ADR can be revisited if real-world usage changes

## Alternatives Considered

1. **Int64**: Rejected due to over-engineering
2. **String-based positions**: Rejected due to complexity
3. **Time-based positioning**: Considered for future hybrid approach (separate ADR)

## Implementation Notes

```swift
// Core Data Schema (unchanged)
currentPosition: Int32  // Character index
position: Int32        // Bookmark position

// Swift Usage
@Published var currentPosition: Int = 0  // Int maps to Int32 in Core Data
```

## Success Metrics

- **Storage efficiency**: Bookmark data remains <1KB per file
- **Performance**: Position calculations <1ms
- **Reliability**: No overflow errors in production
- **User experience**: Accurate resume/bookmark functionality

## Review Date

**Next review**: August 2026 (1 year)  
**Trigger for early review**: If any markdown file >500MB is encountered

---

**Contributors**: Claude, ganglinwu  
**Related ADRs**: None yet  
**References**: [TTS-Position-Tracking-Research.md](./TTS-Position-Tracking-Research.md)