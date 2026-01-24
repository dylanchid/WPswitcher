#!/bin/bash
set -e

echo "Adding remaining critical beads to WPswitcher analysis..."

# Get epic IDs
PHASE1=$(bd list --type epic --title-contains "Phase 1" | grep "WPswitcher-" | head -1 | awk '{print $1}')
PHASE2=$(bd list --type epic --title-contains "Phase 2" | grep "WPswitcher-" | head -1 | awk '{print $1}')
PHASE3=$(bd list --type epic --title-contains "Phase 3" | grep "WPswitcher-" | head -1 | awk '{print $1}')
PHASE4=$(bd list --type epic --title-contains "Phase 4" | grep "WPswitcher-" | head -1 | awk '{print $1}')
PHASE5=$(bd list --type epic --title-contains "Phase 5" | grep "WPswitcher-" | head -1 | awk '{print $1}')
PHASE6=$(bd list --type epic --title-contains "Phase 6" | grep "WPswitcher-" | head -1 | awk '{print $1}')
DELIVERABLES=$(bd list --type epic --title-contains "Deliverables" | grep "WPswitcher-" | head -1 | awk '{print $1}')

echo "Found Epic IDs:"
echo "  Phase 1: $PHASE1"
echo "  Phase 2: $PHASE2"
echo "  Phase 3: $PHASE3"
echo "  Phase 4: $PHASE4"
echo "  Phase 5: $PHASE5"
echo "  Phase 6: $PHASE6"
echo "  Deliverables: $DELIVERABLES"

# Add more Phase 1 beads
echo ""
echo "Adding Phase 1 beads..."

bd create "01-arch-02-protocol-design: Analyze Service Protocol Design" \
  --type task --priority P0 --parent "$PHASE1" --estimate 180 \
  --labels "phase:1.1,category:architecture,risk:low,value:high" \
  --description "Analyze ServiceProtocols.swift for protocol design quality, assess ISP compliance, evaluate naming conventions, and document protocol patterns. Create protocol inventory and design assessment." >/dev/null

bd create "01-arch-03-dependency-graph: Map Complete Dependency Tree" \
  --type task --priority P0 --parent "$PHASE1" --estimate 150 \
  --labels "phase:1.1,category:architecture,risk:low,value:critical" \
  --description "Create comprehensive dependency graph of all services, identify circular dependencies, calculate coupling metrics, create visual dependency graph. Use Mermaid for visualization." >/dev/null

bd create "01-arch-04-core-data-stack: Analyze Core Data Stack Configuration" \
  --type task --priority P0 --parent "$PHASE1" --estimate 240 \
  --labels "phase:1.2,category:data-architecture,risk:low,value:critical" \
  --description "Deep analysis of Core Data stack setup in PersistenceController.swift. Analyze context hierarchy, performance configuration, migration options, and thread safety." >/dev/null

bd create "01-arch-05-entity-relationships: Analyze Entity Relationship Model" \
  --type task --priority P0 --parent "$PHASE1" --estimate 180 \
  --labels "phase:1.2,category:data-architecture,risk:low,value:high" \
  --description "Analyze Core Data entity model in DataModel.xcdatamodeld. Document all entities, relationships, indexes, and validation rules. Create ERD diagram." >/dev/null

bd create "01-arch-06-domain-models: Analyze Domain Model Layer" \
  --type task --priority P1 --parent "$PHASE1" --estimate 150 \
  --labels "phase:1.2,category:data-architecture,risk:low,value:high" \
  --description "Analyze separation between domain models and persistence layer. Identify DTO patterns, mapping logic, and business logic isolation. Assess value types strategy." >/dev/null

bd create "01-arch-07-state-flow: Analyze State Flow Architecture" \
  --type task --priority P1 --parent "$PHASE1" --estimate 180 \
  --labels "phase:1.3,category:state-management,risk:low,value:high" \
  --description "Understand state management patterns and data flow. Map application state structure, data flow (uni/bidirectional), state persistence, and reactive patterns." >/dev/null

bd create "01-arch-08-observable-objects: Analyze ObservableObject Usage" \
  --type task --priority P1 --parent "$PHASE1" --estimate 120 \
  --labels "phase:1.3,category:state-management,risk:low,value:medium" \
  --description "Analyze ObservableObject usage and potential memory issues. Inventory all ObservableObjects, assess @Published properties, check for retain cycles, evaluate performance impact." >/dev/null

echo "Added 7 Phase 1 beads"

# Add Phase 2 beads
echo ""
echo "Adding Phase 2 beads..."

bd create "02-logic-01-wallpaper-service: Analyze WallpaperService Implementation" \
  --type task --priority P0 --parent "$PHASE2" --estimate 300 \
  --labels "phase:2.1,category:business-logic,risk:medium,value:critical" \
  --description "Complete analysis of CoreDataWallpaperService.swift. Analyze service interface, import workflow, CRUD operations, file system integration, security (bookmarks), image processing, and Core Data integration." >/dev/null

bd create "02-logic-02-file-system: Analyze File System Integration & Security" \
  --type task --priority P0 --parent "$PHASE2" --estimate 180 \
  --labels "phase:2.1,category:business-logic,risk:high,value:critical" \
  --description "Deep dive into file system integration and security-scoped bookmarks. Analyze bookmark implementation, sandbox compliance, file access patterns, and error handling." >/dev/null

bd create "02-logic-03-image-processing: Analyze Image Processing Pipeline" \
  --type task --priority P1 --parent "$PHASE2" --estimate 150 \
  --labels "phase:2.1,category:business-logic,risk:medium,value:high" \
  --description "Analyze image loading, processing, and thumbnail generation. Study image loading strategy, thumbnail generation, image caching (NSCache), and performance optimization." >/dev/null

bd create "02-logic-04-system-integration: Analyze macOS System Integration" \
  --type task --priority P0 --parent "$PHASE2" --estimate 180 \
  --labels "phase:2.1,category:business-logic,risk:medium,value:critical" \
  --description "Analyze integration with macOS wallpaper APIs. Study NSWorkspace API usage, display management (NSScreen), system appearance integration, multiple spaces support." >/dev/null

bd create "02-logic-05-playlist-store: Analyze PlaylistStore Implementation" \
  --type task --priority P0 --parent "$PHASE2" --estimate 240 \
  --labels "phase:2.2,category:business-logic,risk:medium,value:critical" \
  --description "Complete analysis of CoreDataPlaylistStore.swift. Analyze playlist data model, CRUD operations, playlist composition, display assignment logic, and state management." >/dev/null

bd create "02-logic-06-scheduling: Analyze Wallpaper Rotation Scheduling" \
  --type task --priority P0 --parent "$PHASE2" --estimate 210 \
  --labels "phase:2.2,category:business-logic,risk:medium,value:critical" \
  --description "Analyze wallpaper rotation scheduling algorithm. Study scheduling mechanism (Timer), rotation logic (sequential/shuffle), system event handling, pause/resume, power management, and concurrency." >/dev/null

bd create "02-logic-07-light-dark-mode: Analyze Light/Dark Mode Support" \
  --type task --priority P1 --parent "$PHASE2" --estimate 120 \
  --labels "phase:2.2,category:business-logic,risk:low,value:medium" \
  --description "Analyze appearance-based wallpaper selection. Study appearance detection (NSAppearance), wallpaper association, switching logic, and edge cases." >/dev/null

echo "Added 7 Phase 2 beads"

# Add Phase 3 beads
echo ""
echo "Adding Phase 3 beads..."

bd create "03-ui-01-view-hierarchy: Map SwiftUI View Hierarchy" \
  --type task --priority P1 --parent "$PHASE3" --estimate 180 \
  --labels "phase:3.1,category:ui-architecture,risk:low,value:high" \
  --description "Map complete SwiftUI view hierarchy. Create view hierarchy map from WPswitcherApp.swift, analyze navigation architecture, view composition strategy, and view identification." >/dev/null

bd create "03-ui-02-viewmodel-pattern: Analyze MVVM Implementation" \
  --type task --priority P1 --parent "$PHASE3" --estimate 180 \
  --labels "phase:3.2,category:ui-architecture,risk:low,value:high" \
  --description "Analyze ViewModel architecture and MVVM pattern. Create ViewModel inventory, assess MVVM pattern adherence, analyze input/output patterns, service integration, and testing considerations." >/dev/null

bd create "03-ui-03-performance: Analyze UI Performance & Responsiveness" \
  --type task --priority P1 --parent "$PHASE3" --estimate 180 \
  --labels "phase:3.1,category:performance,risk:medium,value:high" \
  --description "Analyze UI performance and responsiveness. Profile view body complexity, use Instruments Time Profiler, assess lazy loading, identify unnecessary re-renders, check animation performance." >/dev/null

bd create "03-ui-04-accessibility: Accessibility Audit" \
  --type task --priority P2 --parent "$PHASE3" --estimate 150 \
  --labels "phase:3.3,category:ux,risk:low,value:medium" \
  --description "Comprehensive accessibility audit. Test VoiceOver support, keyboard navigation, Dynamic Type support, color contrast, and reduce motion support." >/dev/null

echo "Added 4 Phase 3 beads"

# Add Phase 4 beads
echo ""
echo "Adding Phase 4 beads..."

bd create "04-sec-01-sandboxing: App Sandbox Audit" \
  --type task --priority P0 --parent "$PHASE4" --estimate 180 \
  --labels "phase:4.1,category:security,risk:high,value:critical" \
  --description "Comprehensive audit of App Sandbox implementation. Review entitlements, sandbox compliance, security-scoped resources, and security best practices. Critical for Mac App Store." >/dev/null

bd create "04-sec-02-data-protection: Data Protection & Privacy Analysis" \
  --type task --priority P0 --parent "$PHASE4" --estimate 150 \
  --labels "phase:4.2,category:security,risk:high,value:critical" \
  --description "Analyze data protection and privacy. Review Core Data encryption options, sensitive data handling, user data retention, permissions management, and privacy policy requirements." >/dev/null

bd create "04-sec-03-input-validation: Input Validation & Security" \
  --type task --priority P1 --parent "$PHASE4" --estimate 120 \
  --labels "phase:4.1,category:security,risk:medium,value:high" \
  --description "Audit input validation and security measures. Check user input sanitization, file type validation, path validation, path traversal prevention, symlink attack prevention." >/dev/null

echo "Added 3 Phase 4 beads"

# Add Phase 5 beads
echo ""
echo "Adding Phase 5 beads..."

bd create "05-perf-01-threading: Threading Model Analysis" \
  --type task --priority P1 --parent "$PHASE5" --estimate 240 \
  --labels "phase:5.1,category:concurrency,risk:high,value:critical" \
  --description "Analyze threading model and concurrent execution. Study main thread usage, background processing (DispatchQueue), Swift concurrency (async/await, actors), Core Data concurrency, and thread safety." >/dev/null

bd create "05-perf-02-memory: Memory Management & Leak Detection" \
  --type task --priority P1 --parent "$PHASE5" --estimate 210 \
  --labels "phase:5.2,category:memory,risk:high,value:critical" \
  --description "Analyze memory management and detect leaks. Identify retain cycles, assess image memory handling, use Instruments Leaks and Allocations, memory pressure handling, and cache management." >/dev/null

bd create "05-perf-03-profiling: Performance Profiling & Optimization" \
  --type task --priority P1 --parent "$PHASE5" --estimate 180 \
  --labels "phase:5.3,category:performance,risk:medium,value:high" \
  --description "Performance profiling and optimization opportunities. Use Instruments Time Profiler, System Trace, analyze I/O performance, CPU utilization, battery impact, and launch time." >/dev/null

echo "Added 3 Phase 5 beads"

# Add Phase 6 beads
echo ""
echo "Adding Phase 6 beads..."

bd create "06-test-01-coverage: Test Coverage Analysis" \
  --type task --priority P1 --parent "$PHASE6" --estimate 180 \
  --labels "phase:6.1,category:testing,risk:low,value:high" \
  --description "Comprehensive test coverage analysis. Document coverage metrics, assess test quality, identify untested areas, evaluate test architecture. Create coverage report and gap analysis." >/dev/null

bd create "06-test-02-error-handling: Error Handling & Resilience Audit" \
  --type task --priority P1 --parent "$PHASE6" --estimate 180 \
  --labels "phase:6.2,category:quality,risk:medium,value:high" \
  --description "Audit error handling patterns and application resilience. Analyze error propagation, recovery strategies, validation & preconditions, and error presentation to users." >/dev/null

bd create "06-test-03-code-quality: Code Quality Metrics & Analysis" \
  --type task --priority P2 --parent "$PHASE6" --estimate 150 \
  --labels "phase:6.3,category:quality,risk:low,value:medium" \
  --description "Analyze code quality metrics and technical debt. Calculate complexity metrics (cyclomatic, cognitive), identify code duplication, assess maintainability, audit TODO/FIXME comments." >/dev/null

echo "Added 3 Phase 6 beads"

# Add Deliverable beads
echo ""
echo "Adding Deliverable beads..."

bd create "DEL-01-executive-summary: Create Executive Summary Report" \
  --type task --priority P0 --parent "$DELIVERABLES" --estimate 240 \
  --labels "deliverable,priority:critical" \
  --description "Synthesize all findings into executive summary. Create key findings summary, risk assessment, recommendations matrix, metrics dashboard, and roadmap overview. Final deliverable: 2-4 page executive report." >/dev/null

bd create "DEL-02-tech-debt: Compile Technical Debt Register" \
  --type task --priority P0 --parent "$DELIVERABLES" --estimate 180 \
  --labels "deliverable,priority:high" \
  --description "Comprehensive technical debt inventory. Collect all issues from analysis phases, categorize by severity, assess impact, prioritize using severity x impact matrix, create remediation plan with effort estimates." >/dev/null

bd create "DEL-03-architecture-diagram: Create Architecture Diagrams" \
  --type task --priority P1 --parent "$DELIVERABLES" --estimate 180 \
  --labels "deliverable,priority:high" \
  --description "Create comprehensive architecture documentation. Produce component diagram, service architecture, data architecture, UI architecture, and system integration diagrams. Use Mermaid, Draw.io, or similar tools." >/dev/null

bd create "DEL-04-refactoring-roadmap: Develop Refactoring Roadmap" \
  --type task --priority P1 --parent "$DELIVERABLES" --estimate 150 \
  --labels "deliverable,priority:high" \
  --description "Create actionable refactoring roadmap. Identify refactoring opportunities, categorize by type (quick fixes, strategic, major), create timeline (immediate, short-term, long-term), assess risks and mitigation." >/dev/null

bd create "DEL-05-performance-plan: Performance Optimization Plan" \
  --type task --priority P1 --parent "$DELIVERABLES" --estimate 120 \
  --labels "deliverable,priority:medium" \
  --description "Comprehensive performance optimization plan. Document profiling results, identify bottlenecks, prioritize optimizations, create implementation plan with metrics and success criteria." >/dev/null

bd create "DEL-06-security-report: Security Assessment Report" \
  --type task --priority P0 --parent "$DELIVERABLES" --estimate 120 \
  --labels "deliverable,priority:critical" \
  --description "Complete security assessment report. Document vulnerability findings, risk mitigation strategies, compliance checklist (OWASP), sandboxing audit results, and security recommendations." >/dev/null

echo "Added 6 Deliverable beads"

echo ""
echo "================================================================"
echo "Bead creation complete!"
echo "================================================================"
echo ""
bd list --pretty --limit 0 | grep -E "^(○|✓|●|◐)" | wc -l | xargs echo "Total beads created:"
echo ""
echo "Next steps:"
echo "1. bd list --pretty --limit 0      # View all beads in tree format"
echo "2. bd ready                         # Show beads ready to work on"
echo "3. bd graph                         # View dependency graph"
echo "4. bd show <bead-id>               # View detailed bead documentation"
echo ""

