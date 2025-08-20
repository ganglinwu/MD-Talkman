# Known Issues & Non-Critical Bugs

This document tracks known issues that don't affect core functionality but may need attention in future releases.

## Audio & TTS Issues

### GryphonVoice MobileAsset Query Error
**Status**: Non-Critical  
**Error**: `Query for com.apple.MobileAsset.VoiceServices.GryphonVoice failed: 2`  
**Date Identified**: 2025-08-16

**Description:**
iOS fails to download highest-quality neural TTS voices (GryphonVoice) from Apple's servers, resulting in debug console errors.

**Impact:**
- ✅ **No functional impact**: App continues working with premium voices (e.g., Daniel, Ava, Samantha)
- ✅ **Voice quality**: Still excellent with 47+ enhanced voices available
- ⚠️ **Debug noise**: Creates error messages in development console

**Root Cause:**
- Network connectivity issues with Apple's voice asset servers
- iOS version compatibility with specific neural voice models
- Simulator vs device differences in voice asset availability
- Temporary server unavailability for premium voice downloads

**Current Behavior:**
- App automatically falls back to available premium/enhanced voices
- Voice selection works correctly (confirmed: "🎵 Selected premium voice: Daniel")
- No user-visible impact or degraded experience

**Potential Solutions:**
1. **Voice Availability Detection**: Check voice availability before attempting selection
2. **Enhanced Error Handling**: Suppress non-critical voice download errors
3. **Voice Download Management**: Proactive voice asset management
4. **User Notification**: Optional voice quality status for power users

**Priority**: Low (P3)  
**Estimated Effort**: 2-3 hours  
**Recommended Timeline**: Future enhancement (not current sprint)

**Workaround:**
None needed - current fallback mechanism handles this gracefully.

---

### System-Level Audio Warnings
**Status**: Non-Critical  
**Error**: `IPCAUClient.cpp:129 IPCAUClient: bundle display name is nil`  
**Date Identified**: 2025-08-16

**Description:**
System-level audio framework warnings that appear in debug console during TTS operations.

**Impact:**
- ✅ **No functional impact**: TTS and audio functionality work perfectly
- ✅ **Audio quality**: No degradation in speech synthesis or playback
- ⚠️ **Debug noise**: Creates warning messages in development logs

**Root Cause:**
- iOS system-level audio unit initialization warnings
- Inter-process communication (IPC) between app and system audio services
- Framework-level logging from AVFoundation/CoreAudio

**Current Behavior:**
- System warnings appear but don't affect app functionality
- TTS plays correctly with proper audio session management
- No user-visible impact or performance degradation

**Priority**: Very Low (P4)  
**Estimated Effort**: Not actionable (system-level issue)  
**Recommended Timeline**: Monitor only - no action needed

**Workaround:**
None needed - these are informational system warnings.

---

### Metal Rendering Library Warnings
**Status**: Non-Critical  
**Error**: `Unable to open mach-O at path: /Library/Caches/.../RenderBox.framework/default.metallib Error:2`  
**Date Identified**: 2025-08-16

**Description:**
iOS attempting to load Metal rendering libraries that may not be present in simulator or development environment.

**Impact:**
- ✅ **No functional impact**: SwiftUI rendering works correctly
- ✅ **Visual quality**: No impact on UI performance or appearance
- ⚠️ **Debug noise**: Creates error messages in development console

**Root Cause:**
- Simulator vs device differences in Metal shader availability
- iOS framework attempting to load optimized rendering paths
- Development environment vs production Metal library differences

**Current Behavior:**
- Framework automatically falls back to available rendering paths
- SwiftUI interface renders correctly with smooth animations
- No performance or visual impact on the app

**Priority**: Very Low (P4)  
**Estimated Effort**: Not actionable (system-level issue)  
**Recommended Timeline**: Monitor only - no action needed

**Workaround:**
None needed - iOS handles fallback rendering automatically.

---

## Future Tracking

Add new non-critical issues here following the same format:
- Audio & TTS Issues
- UI & Visual Issues  
- Performance Issues
- Integration Issues
- Platform-Specific Issues

**Note**: Critical bugs that affect core functionality should be tracked in GitHub Issues or the main todo system, not this document.