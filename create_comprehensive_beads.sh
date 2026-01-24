#!/bin/bash
set -e

echo "Creating Comprehensive WPswitcher Analysis Bead Structure"
echo "=========================================================="

# Helper function to create beads
create_bead() {
    local title="$1"
    local type="$2"
    local priority="$3"
    local parent="$4"
    local estimate="$5"
    local labels="$6"
    local description="$7"
    
    if [ -z "$parent" ]; then
        bd create "$title" --type "$type" --priority "$priority" --estimate "$estimate" --labels "$labels" --description "$description" --silent
    else
        bd create "$title" --type "$type" --priority "$priority" --parent "$parent" --estimate "$estimate" --labels "$labels" --description "$description" --silent
    fi
}

# Get the Phase 0 ID
PHASE0=$(bd list --type epic --silent | grep "Phase 0" | head -1 | awk '{print $1}')

# Continue creating more baseline beads
echo "Creating more Phase 0 beads..."

TESTBASELINE=$(create_bead \
  "00-baseline-test-execution: Execute Existing Test Suite" \
  "task" \
  "P0" \
  "$PHASE0" \
  "90" \
  "phase:0,category:baseline,risk:low,value:high" \
  "Purpose: Run existing test suite and document baseline test coverage

Tasks:
  1. Run all unit tests (Cmd+U in Xcode)
  2. Document test results (pass/fail count)
  3. Measure test coverage (Enable coverage in scheme)
  4. Identify untested areas
  5. Document test execution time

Artifacts:
  - Test results report
  - Coverage report (% and specific gaps)
  - Test execution time baseline
  
Acceptance:
  ✓ All tests executed
  ✓ Coverage percentage documented
  ✓ Test gaps identified
  ✓ No blocking test failures")

echo "Created: $TESTBASELINE"

METRICS=$(create_bead \
  "00-baseline-metrics: Document Baseline Code Metrics" \
  "task" \
  "P0" \
  "$PHASE0" \
  "120" \
  "phase:0,category:baseline,risk:low,value:high" \
  "Purpose: Establish baseline metrics for the codebase

Tasks:
  1. Count lines of code per file/module
     - Use: find . -name '*.swift' | xargs wc -l
  2. Calculate cyclomatic complexity
     - Consider using: swiftlint or lizard tool
  3. Document file structure (number of files, organization)
  4. Measure binary size
  5. Document Swift version and dependencies
  
Metrics to Capture:
  - Total LOC (expected ~3,150)
  - Files count (expected ~13 Swift files)
  - Average file size
  - Largest files
  - Cyclomatic complexity (per file/function)
  - Build time
  - Binary size
  
Artifacts:
  - Metrics dashboard (spreadsheet or markdown)
  - Complexity report
  - File organization map
  
Acceptance:
  ✓ All metrics documented
  ✓ Complexity hotspots identified
  ✓ Baseline established for future comparison")

echo "Created: $METRICS"

TOOLS=$(create_bead \
  "00-baseline-tools-setup: Setup Analysis Tools" \
  "task" \
  "P0" \
  "$PHASE0" \
  "90" \
  "phase:0,category:baseline,risk:low,value:medium" \
  "Purpose: Install and configure tools needed for analysis

Tools to Setup:
  1. SwiftLint
     - brew install swiftlint
     - Configure .swiftlint.yml if needed
  
  2. Instruments (already with Xcode)
     - Verify Time Profiler works
     - Verify Allocations tool works
     - Verify Leaks tool works
  
  3. Additional Tools (optional):
     - Periphery (unused code detection)
     - SwiftFormat (code formatting)
     - sourcery (code generation)
  
  4. Documentation Tools:
     - DocC (comes with Xcode)
  
Tasks:
  - Install each tool
  - Verify tool works on project
  - Document tool versions
  - Create quick reference guide

Acceptance:
  ✓ All required tools installed
  ✓ Tools verified working
  ✓ Tool versions documented
  ✓ Quick reference created")

echo "Created: $TOOLS"

echo ""
echo "Creating Phase 1: Architecture & Foundational Patterns..."

PHASE1=$(bd create "Phase 1: Architecture & Foundational Patterns" \
  --type epic \
  --priority P0 \
  --description "Deep analysis of architectural patterns, dependency injection, data persistence, and state management. This phase establishes foundational understanding required for all subsequent analysis.

Sections:
  1.1 - Dependency Injection & Service Layer
  1.2 - Data Architecture & Persistence
  1.3 - State Management & Reactive Patterns
  
Duration: 3-4 days
Critical Path: Blocks all service and UI analysis" \
  --silent)

echo "Created Phase 1 Epic: $PHASE1"

# Add dependency from Phase 1 to Phase 0
bd dep add "$PHASE1" "$BUILDVERIFY" --silent 2>/dev/null || true

echo "Creating Phase 1.1 beads (Dependency Injection)..."

SERVICEREG=$(create_bead \
  "01-arch-01-service-registry: Deep Analysis of ServiceRegistry" \
  "task" \
  "P0" \
  "$PHASE1" \
  "240" \
  "phase:1.1,category:architecture,risk:low,value:critical" \
  "═══════════════════════════════════════════════════════════════════════════════
PURPOSE: Analyze ServiceRegistry.swift to understand the dependency injection
architecture and service lifecycle management patterns used in WPswitcher.
═══════════════════════════════════════════════════════════════════════════════

📍 CONTEXT & LOCATION
  Phase: 1.1 - Dependency Injection & Service Layer Architecture
  Priority: P0 - CRITICAL (Foundation for all service analysis)
  Files: ServiceRegistry.swift, ServiceProtocols.swift
  Related: All service implementations, WPswitcherApp.swift

🎯 BACKGROUND & RATIONALE
  WPswitcher employs a service-based architecture where ServiceRegistry acts
  as the central dependency injection container. This is a custom DI solution
  (not using third-party frameworks like Swinject).

  Why This Matters:
    • All business logic flows through services
    • Services are injected into ViewModels and Views
    • Testability depends on protocol-based abstraction
    • Adding features requires understanding service registration
    • Performance characteristics depend on lifecycle management

  Architectural Context:
    • Protocol-oriented design (POP) is a Swift best practice
    • Separates interface from implementation
    • Enables compile-time type safety
    • Facilitates mocking for unit tests

📋 DETAILED TASKS
  1. Read & Understand ServiceRegistry.swift
     - Full file read with careful attention to:
       * Property declarations (stored vs computed)
       * Initialization sequence
       * Service registration methods
       * Access patterns (@MainActor, thread safety)

  2. Document All Registered Services
     Create comprehensive table:
     | Service Protocol      | Implementation Class           | Lifecycle    |
     |----------------------|--------------------------------|--------------|
     | WallpaperService     | CoreDataWallpaperService       | Singleton    |
     | PlaylistStore        | CoreDataPlaylistStore          | Singleton    |
     | SchedulerCoordinator | (TBD during analysis)          | (TBD)        |

  3. Analyze Lifecycle Management
     - Singleton pattern usage (lazy var vs let)
     - Initialization timing (app launch vs on-demand)
     - Disposal/cleanup strategy
     - Memory implications of long-lived services

  4. Map Dependency Graph
     - Which services depend on others?
     - Is there a dependency hierarchy?
     - Any circular dependency risks?
     - Document with Mermaid diagram or ASCII art

  5. Trace Injection Points
     - How do Views/ViewModels get service references?
     - @EnvironmentObject usage?
     - Direct property passing?
     - Property wrappers?
     Find all patterns in codebase

  6. Assess Testability
     - Can services be easily mocked?
     - Protocol conformance allows test doubles?
     - Any concrete type dependencies breaking abstraction?
     - Review existing test files for patterns

  7. Evaluate Design Quality
     Using SOLID principles:
     - Single Responsibility: One service = one concern?
     - Open/Closed: Easy to extend with new services?
     - Liskov Substitution: Protocols properly designed?
     - Interface Segregation: Protocols too fat or just right?
     - Dependency Inversion: High-level not depending on low-level?

🔍 SPECIFIC INVESTIGATION POINTS

  Performance:
    [ ] Are services lazily initialized? If so, check timing
    [ ] Any expensive initialization blocking app launch?
    [ ] Memory footprint of all services combined
    [ ] Opportunity for delayed loading of unused services?

  Maintainability:
    [ ] Naming consistency and clarity
    [ ] Code documentation level
    [ ] Ease of adding a new service (simulate mentally)
    [ ] Centralized vs distributed registration

  Thread Safety:
    [ ] @MainActor annotations present?
    [ ] Any service accessed from background threads?
    [ ] Core Data context thread confinement respected?
    [ ] Potential race conditions in service initialization?

  Extensibility:
    [ ] Plugin architecture possible?
    [ ] Service versioning strategy?
    [ ] Feature flags integration point?
    [ ] A/B testing support?

📦 EXPECTED ARTIFACTS

  1. Service Inventory Document (Markdown)
     - Table of all services (as shown above)
     - Prose description of ServiceRegistry pattern
     - Comparison to standard DI containers (pros/cons)

  2. Dependency Graph Visualization
     - Mermaid diagram source
     - ASCII fallback for terminals
     - Annotations for circular risks

  3. Code Flow Diagram
     - App launch → ServiceRegistry init → Service creation
     - View creation → Service injection → Usage
     - Shutdown flow (if applicable)

  4. Testability Assessment
     - Current mockability score (subjective 1-10)
     - Specific pain points for testing
     - Recommendations for improvement

  5. Findings & Recommendations Document
     - Minimum 3 specific observations
     - Minimum 2 recommendations (even if 'no changes needed')
     - Technical debt items (if any)
     - Quick wins vs strategic improvements

🔗 DEPENDENCIES & RELATIONSHIPS

  Prerequisites:
    • Basic Swift knowledge (protocols, property wrappers, etc.)
    • Understanding of dependency injection concept
    • Familiarity with SOLID principles
    • Read project README (if exists)

  This Bead Blocks:
    • All individual service analysis beads (02-logic-*)
    • ViewModel analysis (depends on service understanding)
    • Test coverage analysis (need to know injection pattern)
    • Architecture decision documentation

  This Bead Enables:
    • Parallel analysis of individual services
    • Informed refactoring suggestions
    • Test strategy development

  Related Beads:
    • 01-arch-02-protocol-design (deep dive on protocols)
    • 01-arch-03-core-data-stack (persistence service)
    • 06-test-01-unit-test-strategy (mock creation)

✅ ACCEPTANCE CRITERIA

  Definition of Done:
    ✓ ServiceRegistry.swift fully read and understood
    ✓ All services documented in structured format (table)
    ✓ Dependency graph created and validated
    ✓ At least 3 specific findings documented
    ✓ At least 2 recommendations provided
    ✓ Testability assessment complete with score
    ✓ All artifacts created and saved
    ✓ Notes suitable for handoff to another developer
    ✓ Self-review: Could I explain this to someone else?
    ✓ Cross-check: Do findings align with codebase reality?

  Quality Checks:
    • No assumptions without code evidence
    • Claims backed by file/line references
    • Diagrams accurate to code (not idealized)
    • Recommendations actionable and specific

⏱️ EFFORT ESTIMATION

  Estimated Time: 3-4 hours
    • 1 hour: Reading and note-taking
    • 1 hour: Tracing dependencies and injection
    • 1 hour: Creating diagrams and documentation
    • 0.5 hour: Assessment and recommendations
    • 0.5 hour: Review and refinement

  Priority: P0 (Critical)
  Risk Level: Low (pure analysis, no code changes)
  Value: High (foundational understanding, high leverage)
  Complexity: Medium (requires architectural thinking)

📝 NOTES FOR FUTURE SELF

  Mental Models to Build:
    • 'ServiceRegistry is the heart of the DI system'
    • 'Every business capability is a service'
    • 'Protocols define contracts, classes implement'

  Red Flags to Watch For:
    🚩 Circular dependencies (service A needs B, B needs A)
    🚩 Services doing too much (violating SRP)
    🚩 Concrete type dependencies (breaks abstraction)
    🚩 Services accessing other services directly (bypass registry)
    🚩 Global mutable state in services
    🚩 Missing thread safety annotations

  Learning Opportunities:
    💡 How does Swift's type system enable compile-time DI?
    💡 Trade-offs of custom DI vs third-party frameworks
    💡 How does this compare to SwiftUI's @Environment?
    💡 Could property wrappers simplify service injection?

  Context for Recommendations:
    • This is an active project, maintainability matters
    • Team size might be small (optimize for simplicity)
    • macOS app (not iOS, different patterns possible)
    • Core Data in use (affects service design)

  Integration with Other Phases:
    • Phase 2: Service implementations analysis needs this
    • Phase 3: UI layer will show usage patterns
    • Phase 6: Testing strategy depends on mockability
    • Phase 10: Technical debt register accumulates findings

  Success Criteria Meta:
    Ask yourself:
      • Can I draw the architecture from memory now?
      • Could I add a new service without guessing?
      • Do I understand why this pattern was chosen?
      • What would I change, and why (or why not)?

📚 RESOURCES & REFERENCES

  Internal Files:
    • ServiceRegistry.swift (primary analysis target)
    • ServiceProtocols.swift (all protocol definitions)
    • WPswitcherApp.swift (initialization entry point)
    • CoreDataWallpaperService.swift (example implementation)
    • CoreDataPlaylistStore.swift (example implementation)
    • *ViewModel.swift files (consumers of services)
    • Tests/*Service*.swift (test patterns for mocking)

  External References:
    • Swift.org: Protocol-Oriented Programming in Swift
    • WWDC: Protocol and Value Oriented Programming
    • Martin Fowler: Inversion of Control Containers
    • Uncle Bob: SOLID Principles
    • Swift by Sundell: Dependency Injection articles

  Tools:
    • Xcode: 'Jump to Definition' for tracing
    • grep/rg: Find all service usage patterns
    • Mermaid: Diagram generation

═══════════════════════════════════════════════════════════════════════════════
END OF BEAD DOCUMENTATION
═══════════════════════════════════════════════════════════════════════════════")

echo "Created: $SERVICEREG"

# Add dependencies
bd dep add "$SERVICEREG" "$BUILDVERIFY" --silent 2>/dev/null || true

echo "Script completed successfully!"
echo "Use 'bd list' to see all beads"
echo "Use 'bd show <id>' to see details"

