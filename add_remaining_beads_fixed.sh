#!/bin/bash
set -e

echo "Adding remaining critical beads to WPswitcher analysis..."

# Get epic IDs with corrected extraction
PHASE1=$(bd list --type epic --title-contains "Phase 1:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)
PHASE2=$(bd list --type epic --title-contains "Phase 2:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)
PHASE3=$(bd list --type epic --title-contains "Phase 3:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)
PHASE4=$(bd list --type epic --title-contains "Phase 4:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)
PHASE5=$(bd list --type epic --title-contains "Phase 5:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)
PHASE6=$(bd list --type epic --title-contains "Phase 6:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)
DELIVERABLES=$(bd list --type epic --title-contains "Deliverables" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)

echo "Found Epic IDs:"
echo "  Phase 1: $PHASE1"
echo "  Phase 2: $PHASE2"
echo "  Phase 3: $PHASE3"
echo "  Phase 4: $PHASE4"
echo "  Phase 5: $PHASE5"
echo "  Phase 6: $PHASE6"
echo "  Deliverables: $DELIVERABLES"

if [ -z "$PHASE1" ] || [ -z "$PHASE2" ]; then
    echo "ERROR: Could not find all required epic IDs"
    exit 1
fi

# Add Phase 1 beads
echo ""
echo "Adding Phase 1 beads..."

bd create "01-arch-02-protocol-design: Analyze Service Protocol Design" \
  --type task --priority P0 --parent "$PHASE1" --estimate 180 \
  --labels "phase:1.1,category:architecture,risk:low,value:high" \
  --description "Analyze ServiceProtocols.swift for protocol design quality. Assess ISP compliance, evaluate naming conventions, and document protocol patterns. Create protocol inventory and design assessment with minimum 2 findings." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "01-arch-03-dependency-graph: Map Complete Dependency Tree" \
  --type task --priority P0 --parent "$PHASE1" --estimate 150 \
  --labels "phase:1.1,category:architecture,risk:low,value:critical" \
  --description "Create comprehensive dependency graph of all services. Identify circular dependencies, calculate coupling metrics (afferent/efferent), create visual dependency graph using Mermaid. Document critical path." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "01-arch-04-core-data-stack: Analyze Core Data Stack" \
  --type task --priority P0 --parent "$PHASE1" --estimate 240 \
  --labels "phase:1.2,category:data-architecture,risk:low,value:critical" \
  --description "Deep analysis of Core Data stack in PersistenceController.swift. Analyze NSPersistentContainer setup, context hierarchy, performance configuration, migration options, and thread safety. Document configuration and provide recommendations." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "01-arch-05-entity-relationships: Analyze Entity Model" \
  --type task --priority P0 --parent "$PHASE1" --estimate 180 \
  --labels "phase:1.2,category:data-architecture,risk:low,value:high" \
  --description "Analyze Core Data entity model in DataModel.xcdatamodeld. Document all entities, attributes, relationships (with cardinality), indexes, and validation rules. Create ERD diagram. Assess normalization and delete rules." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "01-arch-06-domain-models: Analyze Domain Model Layer" \
  --type task --priority P1 --parent "$PHASE1" --estimate 150 \
  --labels "phase:1.2,category:data-architecture,risk:low,value:high" \
  --description "Analyze separation between domain models (PlaylistModels.swift) and persistence layer. Identify DTO patterns, mapping logic location, business logic isolation. Assess value types strategy and performance of conversions." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "01-arch-07-state-flow: Analyze State Flow Architecture" \
  --type task --priority P1 --parent "$PHASE1" --estimate 180 \
  --labels "phase:1.3,category:state-management,risk:low,value:high" \
  --description "Understand state management patterns and data flow. Map application state structure, identify sources of truth, analyze uni/bidirectional data flow, state persistence (UserDefaults), and reactive patterns (Combine)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "01-arch-08-observable-objects: Analyze ObservableObject" \
  --type task --priority P1 --parent "$PHASE1" --estimate 120 \
  --labels "phase:1.3,category:state-management,risk:low,value:medium" \
  --description "Analyze ObservableObject usage and potential memory issues. Inventory all ObservableObjects, assess @Published properties and update frequency, check for retain cycles in closures, evaluate performance impact of excessive updates." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

echo "✓ Added 7 Phase 1 beads"

# Add Phase 2 beads
echo ""
echo "Adding Phase 2 beads..."

bd create "02-logic-01-wallpaper-service: Analyze WallpaperService" \
  --type task --priority P0 --parent "$PHASE2" --estimate 300 \
  --labels "phase:2.1,category:business-logic,risk:medium,value:critical" \
  --description "Complete analysis of CoreDataWallpaperService.swift. Analyze service interface, import workflow (file copy vs reference), CRUD operations, file system integration, security-scoped bookmarks (ScopedWallpaperURL), image processing pipeline, Core Data integration. Document minimum 5 findings." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "02-logic-02-file-system: Analyze File System Security" \
  --type task --priority P0 --parent "$PHASE2" --estimate 180 \
  --labels "phase:2.1,category:business-logic,risk:high,value:critical" \
  --description "Deep dive into file system integration and security-scoped bookmarks. Analyze bookmark creation/storage/staleness/refresh, sandbox compliance, file access patterns, path traversal prevention, symlink attack prevention. Critical for security audit." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "02-logic-03-image-processing: Analyze Image Pipeline" \
  --type task --priority P1 --parent "$PHASE2" --estimate 150 \
  --labels "phase:2.1,category:business-logic,risk:medium,value:high" \
  --description "Analyze image loading, processing, and thumbnail generation. Study image loading strategy (lazy loading), thumbnail generation (size, quality), image caching (NSCache usage, eviction policy), memory management for large images, and performance optimization." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "02-logic-04-system-integration: Analyze macOS Integration" \
  --type task --priority P0 --parent "$PHASE2" --estimate 180 \
  --labels "phase:2.1,category:business-logic,risk:medium,value:critical" \
  --description "Analyze integration with macOS wallpaper APIs. Study NSWorkspace wallpaper setting API, desktop image options (fill, fit, center), display management (NSScreen enumeration, hot-plug), system appearance integration (light/dark mode), multiple spaces support." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "02-logic-05-playlist-store: Analyze PlaylistStore" \
  --type task --priority P0 --parent "$PHASE2" --estimate 240 \
  --labels "phase:2.2,category:business-logic,risk:medium,value:critical" \
  --description "Complete analysis of CoreDataPlaylistStore.swift. Analyze playlist data model (entity structure, relationships, ordering), CRUD operations, playlist composition patterns, display assignment logic (mirror mode, per-display), playlist state management (active/inactive, rotation position)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "02-logic-06-scheduling: Analyze Wallpaper Scheduling" \
  --type task --priority P0 --parent "$PHASE2" --estimate 210 \
  --labels "phase:2.2,category:business-logic,risk:medium,value:critical" \
  --description "Analyze wallpaper rotation scheduling algorithm in SchedulerCoordinator. Study scheduling mechanism (Timer vs DispatchSourceTimer), rotation logic (sequential/shuffle), next wallpaper selection, system event handling (sleep/wake, display changes), pause/resume, power management, thread safety." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "02-logic-07-light-dark-mode: Analyze Appearance Support" \
  --type task --priority P1 --parent "$PHASE2" --estimate 120 \
  --labels "phase:2.2,category:business-logic,risk:low,value:medium" \
  --description "Analyze appearance-based wallpaper selection. Study appearance detection (NSAppearance observation), wallpaper association (light/dark pairing), automatic switching logic, transition timing, user override capability, edge cases (no wallpaper for appearance, rapid toggles)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

echo "✓ Added 7 Phase 2 beads"

# Add Phase 3 beads
echo ""
echo "Adding Phase 3 beads..."

bd create "03-ui-01-view-hierarchy: Map SwiftUI View Hierarchy" \
  --type task --priority P1 --parent "$PHASE3" --estimate 180 \
  --labels "phase:3.1,category:ui-architecture,risk:low,value:high" \
  --description "Map complete SwiftUI view hierarchy from WPswitcherApp.swift through MainWindowView.swift to all child views. Create view hierarchy tree diagram, analyze navigation architecture (NavigationView/Stack), view composition strategy (decomposition, reusability), view responsibilities." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "03-ui-02-viewmodel-pattern: Analyze MVVM Implementation" \
  --type task --priority P1 --parent "$PHASE3" --estimate 180 \
  --labels "phase:3.2,category:ui-architecture,risk:low,value:high" \
  --description "Analyze ViewModel architecture and MVVM pattern in PlaylistEditorViewModel.swift and others. Create ViewModel inventory, assess MVVM separation of concerns (business logic in VM vs View), analyze input/output patterns (user actions, data binding), service integration, testability." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "03-ui-03-performance: Analyze UI Performance" \
  --type task --priority P1 --parent "$PHASE3" --estimate 180 \
  --labels "phase:3.1,category:performance,risk:medium,value:high" \
  --description "Analyze UI performance and responsiveness. Profile view body complexity, use Instruments Time Profiler for UI interactions, assess lazy loading (LazyVStack/LazyHGrid), identify unnecessary re-renders (@Published granularity, view identity), check animation performance and frame rate." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "03-ui-04-accessibility: Conduct Accessibility Audit" \
  --type task --priority P2 --parent "$PHASE3" --estimate 150 \
  --labels "phase:3.3,category:ux,risk:low,value:medium" \
  --description "Comprehensive accessibility audit. Test VoiceOver support (labels, hints, values, custom actions), keyboard navigation (tab order, shortcuts, focus management), Dynamic Type support, color contrast ratios, color blind friendly design, reduce motion support." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "03-ui-05-ux-patterns: Evaluate User Experience Patterns" \
  --type task --priority P2 --parent "$PHASE3" --estimate 120 \
  --labels "phase:3.3,category:ux,risk:low,value:medium" \
  --description "Evaluate overall user experience. Assess UI responsiveness and progress indicators, error presentation (clarity, recovery actions), platform conventions (macOS HIG compliance, keyboard shortcuts, menu bar integration), localization readiness (string externalization, NSLocalizedString)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

echo "✓ Added 5 Phase 3 beads"

# Add Phase 4 beads
echo ""
echo "Adding Phase 4 beads..."

bd create "04-sec-01-sandboxing: Conduct App Sandbox Audit" \
  --type task --priority P0 --parent "$PHASE4" --estimate 180 \
  --labels "phase:4.1,category:security,risk:high,value:critical" \
  --description "Comprehensive audit of App Sandbox implementation. Review entitlements (list all, justify each), sandbox compliance (file access, network, IPC, resources), security-scoped resources (bookmarks, Powerbox, user consent), security best practices (least privilege, hardened runtime, code signing). CRITICAL for Mac App Store." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "04-sec-02-data-protection: Analyze Data Protection" \
  --type task --priority P0 --parent "$PHASE4" --estimate 150 \
  --labels "phase:4.2,category:security,risk:high,value:critical" \
  --description "Analyze data protection and privacy. Review Core Data encryption options, sensitive data handling, user data retention and deletion capability, permissions management (photo library, file system, screen recording), privacy policy requirements, analytics/telemetry." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "04-sec-03-input-validation: Audit Input Validation" \
  --type task --priority P1 --parent "$PHASE4" --estimate 120 \
  --labels "phase:4.1,category:security,risk:medium,value:high" \
  --description "Audit input validation and security measures. Check user input sanitization, file type validation, path validation (prevent path traversal), symlink attack prevention. Review for injection vulnerabilities and malformed data handling." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "04-sec-04-owasp-audit: OWASP Security Checklist" \
  --type task --priority P1 --parent "$PHASE4" --estimate 180 \
  --labels "phase:4.1,category:security,risk:high,value:high" \
  --description "Complete OWASP Mobile Top 10 audit (adapted for macOS). Check: improper platform usage, insecure data storage, insecure communication, insecure authentication, insufficient cryptography, insecure authorization, client code quality, code tampering, reverse engineering, extraneous functionality." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

echo "✓ Added 4 Phase 4 beads"

# Add Phase 5 beads
echo ""
echo "Adding Phase 5 beads..."

bd create "05-perf-01-threading: Analyze Threading Model" \
  --type task --priority P1 --parent "$PHASE5" --estimate 240 \
  --labels "phase:5.1,category:concurrency,risk:high,value:critical" \
  --description "Analyze threading model and concurrent execution. Study main thread usage (UI updates, blocking), background processing (DispatchQueue, OperationQueue, QoS), Swift concurrency (async/await, actors, @MainActor, Task lifecycle), Core Data concurrency (context thread confinement, perform/performAndWait), thread safety (shared state, race conditions)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "05-perf-02-memory: Analyze Memory Management" \
  --type task --priority P1 --parent "$PHASE5" --estimate 210 \
  --labels "phase:5.2,category:memory,risk:high,value:critical" \
  --description "Analyze memory management and detect leaks. Identify retain cycles (ARC, weak/unowned, closure captures, delegates), assess image memory handling (large images, cache management, NSCache vs custom), use Instruments Leaks and Allocations, memory pressure handling (didReceiveMemoryWarning, cache eviction), zombie objects." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "05-perf-03-profiling: Performance Profiling" \
  --type task --priority P1 --parent "$PHASE5" --estimate 180 \
  --labels "phase:5.3,category:performance,risk:medium,value:high" \
  --description "Performance profiling and optimization opportunities. Use Instruments (Time Profiler hotspots, System Trace, Energy Log), analyze I/O performance (file read/write, database queries), CPU utilization (algorithm complexity, unnecessary computation), battery impact (timer frequency, background activity), launch time analysis." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

echo "✓ Added 3 Phase 5 beads"

# Add Phase 6 beads
echo ""
echo "Adding Phase 6 beads..."

bd create "06-test-01-coverage: Analyze Test Coverage" \
  --type task --priority P1 --parent "$PHASE6" --estimate 180 \
  --labels "phase:6.1,category:testing,risk:low,value:high" \
  --description "Comprehensive test coverage analysis. Document coverage metrics (line, branch, function coverage per module), assess test quality (edge cases, happy vs error paths, naming conventions), identify untested areas (critical paths, complex logic, error handling), evaluate test architecture (helpers, mocks, test data management)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "06-test-02-error-handling: Audit Error Handling" \
  --type task --priority P1 --parent "$PHASE6" --estimate 180 \
  --labels "phase:6.2,category:quality,risk:medium,value:high" \
  --description "Audit error handling patterns and resilience. Analyze error propagation (Swift Error, error type hierarchy, context preservation), error recovery (graceful degradation, retry logic, fallback mechanisms), validation & preconditions (input validation, assertions, fatal errors, guard statements), error presentation (user messages, clarity, actionable guidance)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "06-test-03-code-quality: Analyze Code Quality" \
  --type task --priority P2 --parent "$PHASE6" --estimate 150 \
  --labels "phase:6.3,category:quality,risk:low,value:medium" \
  --description "Analyze code quality metrics and technical debt. Calculate complexity metrics (cyclomatic complexity per function, cognitive complexity, nesting depth, function length), identify code duplication (refactoring opportunities), assess maintainability (parameter count, class/file size, naming quality), audit TODO/FIXME comments, deprecated API usage." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

echo "✓ Added 3 Phase 6 beads"

# Add Deliverable beads
echo ""
echo "Adding Deliverable beads..."

bd create "DEL-01-executive-summary: Executive Summary Report" \
  --type task --priority P0 --parent "$DELIVERABLES" --estimate 240 \
  --labels "deliverable,priority:critical,type:synthesis" \
  --description "Synthesize all findings into executive summary (2-4 pages). Create: key findings summary (top 10 critical + positive), risk assessment matrix, recommendations prioritized (quick wins, strategic investments, technical debt), metrics dashboard (quality, coverage, performance, security), roadmap overview (short/medium/long-term). Final deliverable for stakeholders." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "DEL-02-tech-debt: Technical Debt Register" \
  --type task --priority P0 --parent "$DELIVERABLES" --estimate 180 \
  --labels "deliverable,priority:high,type:synthesis" \
  --description "Comprehensive technical debt inventory. Collect all issues from analysis phases, categorize by severity (P0-P4), assess impact (business, velocity, maintenance), prioritize using severity × impact matrix, create remediation plan with effort estimates and dependencies. Spreadsheet/table format with actionable recommendations." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "DEL-03-architecture-diagram: Architecture Documentation" \
  --type task --priority P1 --parent "$DELIVERABLES" --estimate 180 \
  --labels "deliverable,priority:high,type:documentation" \
  --description "Create comprehensive architecture documentation with diagrams. Produce: component diagram (major components, relationships, data flow), service architecture (DI, dependencies, lifecycle), data architecture (Core Data stack, entities, persistence), UI architecture (view hierarchy, MVVM, state), system integration (macOS APIs, file system, displays). Use Mermaid or Draw.io. Provide source files." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "DEL-04-refactoring-roadmap: Refactoring Roadmap" \
  --type task --priority P1 --parent "$DELIVERABLES" --estimate 150 \
  --labels "deliverable,priority:high,type:roadmap" \
  --description "Create actionable refactoring roadmap with timeline. Identify refactoring opportunities (code smells, architecture improvements, performance optimizations, test gaps), categorize by type (quick fixes <1d, strategic 1-5d, major >5d), create 3-phase timeline (immediate/short-term/long-term), assess risks and mitigation strategies. Include success metrics." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "DEL-05-performance-plan: Performance Optimization Plan" \
  --type task --priority P1 --parent "$DELIVERABLES" --estimate 120 \
  --labels "deliverable,priority:medium,type:plan" \
  --description "Comprehensive performance optimization plan. Document profiling results from Instruments, identify bottlenecks (CPU, memory, I/O, battery), prioritize optimizations by impact, create implementation plan with success metrics and acceptance criteria. Include before/after benchmarks where possible." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

bd create "DEL-06-security-report: Security Assessment Report" \
  --type task --priority P0 --parent "$DELIVERABLES" --estimate 120 \
  --labels "deliverable,priority:critical,type:security" \
  --description "Complete security assessment report for stakeholders. Document: vulnerability findings with severity ratings, risk mitigation strategies with timelines, compliance checklist (OWASP, App Sandbox, macOS security best practices), sandboxing audit results, security-scoped bookmark implementation review. Include App Store readiness assessment." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created bead"

echo "✓ Added 6 Deliverable beads"

echo ""
echo "================================================================"
echo "Bead creation complete!"
echo "================================================================"
echo ""
echo "Summary:"
bd list --limit 0 --status open | wc -l | xargs echo "  Total beads:"
bd list --type epic --limit 0 | wc -l | xargs echo "  Epics:"
bd list --type task --limit 0 | wc -l | xargs echo "  Tasks:"
echo ""
echo "Next steps:"
echo "  1. bd list --pretty --limit 0      # View all beads in tree format"
echo "  2. bd ready                         # Show beads ready to work on"
echo "  3. bd graph                         # View dependency graph"
echo "  4. bd show <bead-id>               # View detailed bead documentation"
echo ""
echo "To start analysis:"
echo "  bd ready                            # Shows next available beads"
echo "  bd show WPswitcher-hbl.1           # View first baseline bead details"
echo ""

