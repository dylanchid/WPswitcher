#!/bin/bash

set -e

echo "Creating WPswitcher Comprehensive Analysis Bead Structure..."
echo "============================================================"

# Phase 0: Baseline Setup
echo "Phase 0: Baseline & Environment Setup..."
PHASE0=$(bd create "Phase 0: Baseline & Environment Setup" \
  --type epic \
  --priority P0 \
  --description "$(cat <<'EOF'
Purpose: Establish baseline understanding and set up analysis environment
Context: Foundation phase that enables all subsequent analysis work
Priority: P0 (Critical - Must complete first)

Overview:
  This phase establishes the baseline state of the WPswitcher codebase
  and prepares the environment for comprehensive analysis. All subsequent
  phases depend on completing this foundational work.

Key Activities:
  - Clone/verify codebase access
  - Build project successfully
  - Run existing test suite
  - Set up analysis tools (Instruments, linters, etc.)
  - Document initial metrics (LOC, complexity, coverage)
  - Create workspace for analysis artifacts

Success Criteria:
  ✓ Project builds without errors
  ✓ All existing tests pass
  ✓ Development environment fully configured
  ✓ Baseline metrics documented
  ✓ Analysis tools verified working

Estimated Duration: 4-6 hours
EOF
)" --silent)

echo "Created Phase 0 Epic: $PHASE0"

echo "Creating 00-baseline-build-verify..."
BUILDVERIFY=$(bd create "00-baseline-build-verify: Verify Build and Run Project" \
  --type task \
  --priority P0 \
  --parent "$PHASE0" \
  --estimate 120 \
  --labels "phase:0,category:baseline,risk:low,value:critical" \
  --description "$(cat <<'EOF'
═══════════════════════════════════════════════════════════════════════════════
PURPOSE: Verify that the WPswitcher project builds and runs successfully
═══════════════════════════════════════════════════════════════════════════════

📍 CONTEXT & LOCATION
  Phase: 0 - Baseline & Environment Setup
  Priority: P0 - CRITICAL (Foundation for all analysis)
  Files: WPswitcher.xcodeproj, all project files
  Tools: Xcode, xcodebuild command line

🎯 BACKGROUND & RATIONALE
  Before any analysis can begin, we must verify that the project is in a
  buildable state. This ensures that:
    • The development environment is correctly configured
    • All dependencies are available
    • There are no broken file references
    • The codebase is in a known good state
  
  This is the gate-keeper task that validates readiness for analysis.

📋 DETAILED TASKS
  1. Open Project in Xcode
     - Launch Xcode
     - Open WPswitcher.xcodeproj
     - Verify scheme selection (WPswitcher target)
  
  2. Clean Build Folder
     - Product → Clean Build Folder (⇧⌘K)
     - Ensures fresh build state
  
  3. Build Project
     - Product → Build (⌘B)
     - Observe build log for warnings/errors
     - Document any warnings
  
  4. Run Application
     - Product → Run (⌘R)
     - Verify app launches successfully
     - Perform basic smoke test (open main window, navigate UI)
  
  5. Command Line Build Verification
     - Run: xcodebuild -project WPswitcher.xcodeproj -scheme WPswitcher -configuration Debug build
     - Verify command line builds work (important for CI/automation)
  
  6. Document Build Configuration
     - Target deployment version
     - Supported architectures
     - Build time (baseline metric)
     - Binary size (baseline metric)
     - Number of warnings

🔍 SPECIFIC INVESTIGATION POINTS
  Build Issues:
    [ ] Any missing files or broken references?
    [ ] All dependencies resolved?
    [ ] Code signing configuration correct?
    [ ] Any deprecated API warnings?
  
  Runtime Issues:
    [ ] App launches without crashes?
    [ ] All UI elements visible?
    [ ] Any console errors/warnings?
    [ ] Permissions requested properly?

📦 EXPECTED ARTIFACTS
  1. Build Log (Debug Configuration)
     - Full Xcode build log (captured)
     - Warning count and categorization
     - Build duration
  
  2. Build Metrics Baseline
     - Lines of code: ~3,150 (verify)
     - Swift files: ~13 (verify)
     - Build time: [DOCUMENT]
     - Binary size: [DOCUMENT]
     - Warning count: [DOCUMENT]
  
  3. Runtime Verification Report
     - Screenshot of launched app
     - Basic functionality checklist
     - Any console output (errors/warnings)
  
  4. Environment Configuration
     - Xcode version
     - macOS version
     - Swift version
     - Deployment target

🔗 DEPENDENCIES & RELATIONSHIPS
  Prerequisites:
    • Xcode installed
    • macOS development environment
    • Project cloned/available
  
  This Bead Blocks:
    • ALL subsequent analysis beads
    • This is the foundational gate
  
  This Bead Enables:
    • Test suite execution
    • Code analysis
    • Instruments profiling
    • All other phases

✅ ACCEPTANCE CRITERIA
  Definition of Done:
    ✓ Project builds successfully with no errors
    ✓ App launches and runs
    ✓ Baseline metrics documented
    ✓ Build warnings categorized
    ✓ Command line build verified
    ✓ Build time recorded
    ✓ Environment configuration documented
    ✓ Screenshots/logs captured

  Quality Checks:
    • Zero build errors
    • All warnings understood and documented
    • App fully functional after launch

⏱️ EFFORT ESTIMATION
  Estimated Time: 1-2 hours
    • 15 min: Project opening and initial build
    • 15 min: Runtime verification
    • 15 min: Command line build testing
    • 15 min: Documentation of findings
    • 30 min: Buffer for troubleshooting
  
  Priority: P0 (Critical)
  Risk Level: Low (well-defined task)
  Value: Critical (enables everything else)
  Complexity: Low

📝 NOTES FOR FUTURE SELF
  Red Flags to Watch For:
    🚩 Build errors (blocks all analysis)
    🚩 Extensive warnings (technical debt indicator)
    🚩 Long build times (tooling issue)
    🚩 Runtime crashes (stability concern)
  
  Success Indicators:
    ✅ Clean build log
    ✅ Fast build times (<30s incremental)
    ✅ Stable runtime
    ✅ Professional code signing setup

📚 RESOURCES & REFERENCES
  Internal Files:
    • WPswitcher.xcodeproj (project file)
    • Build settings in Xcode
  
  Tools:
    • Xcode (primary IDE)
    • xcodebuild (command line builds)
    • Terminal (for CLI verification)

═══════════════════════════════════════════════════════════════════════════════
END OF BEAD DOCUMENTATION
═══════════════════════════════════════════════════════════════════════════════
EOF
)" --silent)

echo "Created: $BUILDVERIFY"

echo "Successfully created initial beads!"
echo "To see beads: bd list"
