#!/bin/bash
set -e

echo "Adding beads for Phases 7-10..."

# Get epic IDs
PHASE7=$(bd list --type epic --title-contains "Phase 7:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)
PHASE8=$(bd list --type epic --title-contains "Phase 8:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)
PHASE9=$(bd list --type epic --title-contains "Phase 9:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)
PHASE10=$(bd list --type epic --title-contains "Phase 10:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)

echo "Found Epic IDs:"
echo "  Phase 7: $PHASE7"
echo "  Phase 8: $PHASE8"
echo "  Phase 9: $PHASE9"
echo "  Phase 10: $PHASE10"

# Phase 7: Build System & Project Configuration
echo ""
echo "Adding Phase 7 beads (Build System)..."

bd create "07-build-01-project-config: Analyze Xcode Project Configuration" \
  --type task --priority P2 --parent "$PHASE7" --estimate 150 \
  --labels "phase:7,category:build,risk:low,value:medium" \
  --description "Analyze WPswitcher.xcodeproj configuration. Review build configuration (Debug vs Release settings, optimization levels, compiler flags), target configuration (deployment target, architectures, bitcode), signing & capabilities (provisioning, entitlements), build scripts (run scripts, linting, code generation)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "07-build-02-dependencies: Review Dependencies & SPM" \
  --type task --priority P2 --parent "$PHASE7" --estimate 120 \
  --labels "phase:7,category:build,risk:low,value:medium" \
  --description "Review dependency management. Audit Swift Package Manager usage (Package.swift dependencies), check for CocoaPods/Carthage (if any), review third-party library versions and updates, assess license compliance, evaluate dependency graph for conflicts or redundancy." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "07-build-03-build-performance: Optimize Build Performance" \
  --type task --priority P2 --parent "$PHASE7" --estimate 90 \
  --labels "phase:7,category:build,risk:low,value:low" \
  --description "Analyze and optimize build performance. Profile compilation time using xcodebuild -showBuildTimingSummary, assess module interface stability, evaluate incremental build effectiveness, identify slow compiling files, consider framework modularization opportunities for build parallelization." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

echo "✓ Added 3 Phase 7 beads"

# Phase 8: Documentation & Knowledge Transfer
echo ""
echo "Adding Phase 8 beads (Documentation)..."

bd create "08-doc-01-code-documentation: Review Code Documentation" \
  --type task --priority P2 --parent "$PHASE8" --estimate 150 \
  --labels "phase:8,category:documentation,risk:low,value:medium" \
  --description "Review inline code documentation. Assess DocC/Javadoc comment coverage, evaluate API documentation completeness (public interfaces, parameters, return values), check for example usage documentation, review complex logic documentation, assess documentation currency and accuracy." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "08-doc-02-architecture-docs: Evaluate Architecture Documentation" \
  --type task --priority P2 --parent "$PHASE8" --estimate 120 \
  --labels "phase:8,category:documentation,risk:low,value:high" \
  --description "Evaluate architectural documentation. Check for architecture decision records (ADRs), system design documents, data flow diagrams, review README quality (setup instructions, feature documentation, contribution guidelines), assess onboarding documentation for new developers." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "08-doc-03-code-readability: Assess Code Readability" \
  --type task --priority P2 --parent "$PHASE8" --estimate 90 \
  --labels "phase:8,category:quality,risk:low,value:medium" \
  --description "Assess code readability and style. Review Swift API Design Guidelines compliance, evaluate naming consistency (variables, functions, types), check abbreviation usage and clarity, assess MARK: comment usage for organization, evaluate file structure consistency, review SwiftLint configuration and compliance." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

echo "✓ Added 3 Phase 8 beads"

# Phase 9: Deployment & Distribution
echo ""
echo "Adding Phase 9 beads (Deployment)..."

bd create "09-deploy-01-versioning: Review Versioning Strategy" \
  --type task --priority P2 --parent "$PHASE9" --estimate 90 \
  --labels "phase:9,category:deployment,risk:low,value:medium" \
  --description "Review versioning and release strategy. Assess semantic versioning compliance, review build number management, document version history, check for changelog/release notes, evaluate versioning automation, assess backward compatibility strategy." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "09-deploy-02-app-store: App Store Readiness Assessment" \
  --type task --priority P2 --parent "$PHASE9" --estimate 180 \
  --labels "phase:9,category:deployment,risk:high,value:critical" \
  --description "Assess Mac App Store readiness. Review App Store Guidelines compliance, evaluate rejection risk factors, verify Privacy Manifest accuracy (required reason API usage, privacy nutrition label), review App Sandbox configuration, check temporary exceptions and migration plan, verify screenshots and marketing materials requirements." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "09-deploy-03-distribution: Distribution Strategy Analysis" \
  --type task --priority P2 --parent "$PHASE9" --estimate 120 \
  --labels "phase:9,category:deployment,risk:low,value:medium" \
  --description "Analyze distribution channels and strategy. Compare Mac App Store vs direct distribution trade-offs, evaluate update mechanism (Sparkle framework or App Store updates), assess beta testing strategy (TestFlight usage, beta feedback loop), review crash reporting integration (if any), plan rollout strategy." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

echo "✓ Added 3 Phase 9 beads"

# Phase 10: Maintenance & Evolution
echo ""
echo "Adding Phase 10 beads (Maintenance)..."

bd create "10-maint-01-tech-debt-assessment: Technical Debt Deep Dive" \
  --type task --priority P2 --parent "$PHASE10" --estimate 180 \
  --labels "phase:10,category:maintenance,risk:low,value:high" \
  --description "Comprehensive technical debt deep dive. Create detailed debt inventory (known issues catalog, workarounds documentation), assess maintenance burden and development velocity impact, prioritize debt by severity x impact, create deprecation strategy (deprecated code removal plan, API evolution), document upgrade paths (Swift version migration, macOS SDK updates, third-party dependency updates)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "10-maint-02-extensibility: Evaluate Extensibility & Future-Proofing" \
  --type task --priority P2 --parent "$PHASE10" --estimate 150 \
  --labels "phase:10,category:architecture,risk:low,value:medium" \
  --description "Evaluate extensibility and future-proofing. Identify extension points for new features, assess plugin architecture feasibility, evaluate feature flags infrastructure (A/B testing, gradual rollout capability), review API stability (public API surface, backward compatibility strategy), assess modularity and separation of concerns for future growth." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "10-maint-03-best-practices: Best Practices Compliance Review" \
  --type task --priority P2 --parent "$PHASE10" --estimate 120 \
  --labels "phase:10,category:quality,risk:low,value:medium" \
  --description "Comprehensive best practices compliance review. Assess Swift best practices (protocol-oriented programming, value semantics, error handling, memory safety, type safety), SwiftUI best practices (single source of truth, view decomposition, state management, performance, accessibility), macOS app best practices (HIG compliance, app lifecycle, resource management, system integration). Create compliance scorecard." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

echo "✓ Added 3 Phase 10 beads"

# Add a few bonus analysis beads
echo ""
echo "Adding bonus specialized analysis beads..."

# Add to Phase 2 - a few more domain-specific beads
PHASE2=$(bd list --type epic --title-contains "Phase 2:" | grep -o 'WPswitcher-[a-z0-9]*' | head -1)

bd create "02-logic-08-metadata-management: Analyze Metadata & Tagging" \
  --type task --priority P2 --parent "$PHASE2" --estimate 90 \
  --labels "phase:2.1,category:business-logic,risk:low,value:medium" \
  --description "Analyze wallpaper metadata management. Review EXIF data extraction, image dimensions and aspect ratio tracking, file size management, import timestamps, tags and categorization system. Assess search and filter capabilities based on metadata. Evaluate metadata persistence and performance." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "02-logic-09-preview-rendering: Analyze Preview System" \
  --type task --priority P2 --parent "$PHASE2" --estimate 90 \
  --labels "phase:2.3,category:business-logic,risk:low,value:medium" \
  --description "Analyze preview generation and rendering system. Study preview generation strategy (thumbnail vs full-size), aspect ratio preservation logic, preview update triggers and refresh mechanism, performance optimization techniques, desktop snapshot mechanism (current desktop capture, screen capture permissions, privacy implications)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

echo "✓ Added 2 bonus Phase 2 beads"

# Create a Phase 11 for advanced topics
bd create "Phase 11: Advanced Topics & Domain-Specific Analysis" \
  --type epic --priority P2 \
  --description "Advanced domain-specific analysis. Deep dives into macOS system integration, Core Data advanced topics, and specialized features." 2>&1 | grep -o 'WPswitcher-[a-z0-9]*' > /tmp/phase11_id.txt

PHASE11=$(cat /tmp/phase11_id.txt)
echo "Created Phase 11 Epic: $PHASE11"

bd create "11-advanced-01-nsworkspace: Deep Dive into NSWorkspace Integration" \
  --type task --priority P2 --parent "$PHASE11" --estimate 120 \
  --labels "phase:11,category:advanced,risk:low,value:medium" \
  --description "Deep dive into NSWorkspace API usage. Analyze wallpaper setting implementation details, desktop image options (scaling modes: fill, fit, center, stretch, tile), per-screen vs global wallpaper settings, NSScreen change notifications and handling, display arrangement and coordinate spaces, edge cases (displays with different resolutions, orientation changes)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "11-advanced-02-core-data-advanced: Core Data Advanced Techniques" \
  --type task --priority P2 --parent "$PHASE11" --estimate 120 \
  --labels "phase:11,category:advanced,risk:low,value:medium" \
  --description "Core Data advanced topics analysis. Review fetch batching strategies, relationship prefetching optimization, faulting behavior management, parent-child context hierarchy patterns, sibling contexts usage, merge conflict resolution strategies, persistent history tracking (if used), cloud sync considerations (if applicable: iCloud integration, conflict resolution, sync performance)." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

bd create "11-advanced-03-system-integration: System Events & Lifecycle" \
  --type task --priority P2 --parent "$PHASE11" --estimate 90 \
  --labels "phase:11,category:advanced,risk:low,value:medium" \
  --description "Analyze system integration and lifecycle. Study launch agent/daemon implementation (auto-start, background execution, system login integration), system sleep/wake handling, screen lock/unlock events, display hot-plug detection and response, system appearance changes, user session management, app termination and cleanup." 2>&1 | grep -E "(WPswitcher-|Created)" || echo "Created"

echo "✓ Added 3 Phase 11 beads"

echo ""
echo "================================================================"
echo "Final bead structure creation complete!"
echo "================================================================"
echo ""
echo "Summary:"
bd list --limit 0 --status open | wc -l | xargs echo "  Total beads:"
bd list --type epic --limit 0 | wc -l | xargs echo "  Epics:"
bd list --type task --limit 0 | wc -l | xargs echo "  Tasks:"
echo ""
echo "Bead organization:"
echo "  Phase 0: Baseline (3 beads)"
echo "  Phase 1: Architecture (8 beads)"
echo "  Phase 2: Business Logic (9 beads)"
echo "  Phase 3: UI Layer (5 beads)"
echo "  Phase 4: Security (4 beads)"
echo "  Phase 5: Performance (3 beads)"
echo "  Phase 6: Testing & Quality (3 beads)"
echo "  Phase 7: Build System (3 beads)"
echo "  Phase 8: Documentation (3 beads)"
echo "  Phase 9: Deployment (3 beads)"
echo "  Phase 10: Maintenance (3 beads)"
echo "  Phase 11: Advanced Topics (3 beads)"
echo "  Deliverables: (6 beads)"
echo ""
echo "Total: ~56 task beads + 13 epic beads = 69 beads"
echo ""
echo "Next steps to begin analysis:"
echo "  1. bd list --pretty --limit 0      # View complete structure"
echo "  2. bd ready                         # Show beads ready to start"
echo "  3. bd show WPswitcher-hbl.1        # View first baseline bead"
echo "  4. Start with Phase 0 (Baseline)"
echo ""

