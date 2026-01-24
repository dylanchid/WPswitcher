# 🎯 Handoff Prompt: WPswitcher Comprehensive Analysis & Beads Creation

**Context:** WPswitcher is a macOS wallpaper management application built with Swift/SwiftUI. We have created a comprehensive 14-phase analysis plan that needs to be broken down into an actionable, dependency-mapped bead structure for systematic execution.

---

## 📋 Your Mission

You are an expert software architect and project planner. Your task is to:

1. **Read and deeply understand** `ANALYSIS_PLAN.md` in this repository
2. **Elaborate and expand** on each phase with additional technical depth where beneficial
3. **Create a comprehensive bead structure** using the `bd` tool that transforms the analysis plan into:
   - Granular, actionable tasks
   - Nested subtasks where appropriate
   - Explicit dependency relationships
   - Self-documenting comments with context, rationale, and considerations
4. **Use ultrathink mode** for deep reasoning about task decomposition and dependencies

---

## 🎓 Required Deep Thinking (Ultrathink)

Before creating beads, reason through:

### Strategic Questions
- What is the optimal order of analysis phases?
- Which phases have hard dependencies vs can run in parallel?
- What are the critical path items that block downstream work?
- Which tasks provide maximum learning/insight per unit effort?
- What are the risk areas that need early validation?

### Architectural Considerations
- How does understanding one component inform analysis of others?
- What cross-cutting concerns span multiple phases?
- Where do we need to establish baselines before deep dives?
- Which analyses produce artifacts needed by later phases?

### Practical Execution
- What is a realistic granularity for each bead? (2-4 hour chunks?)
- How do we maintain momentum while ensuring thoroughness?
- What are natural checkpoints for validation and course correction?
- How do we handle discoveries that require re-planning?

---

## 🏗️ Bead Structure Requirements

### Top-Level Organization
Create a hierarchical bead structure like:

```
wpswitch-analysis/
├── phase-01-architecture/
│   ├── 1.1-dependency-injection/
│   │   ├── analyze-service-registry
│   │   ├── map-protocol-contracts
│   │   ├── document-dependency-graph
│   │   └── assess-testability
│   ├── 1.2-data-architecture/
│   └── 1.3-state-management/
├── phase-02-business-logic/
├── phase-03-ui-layer/
├── ...
└── deliverables/
    ├── executive-summary
    ├── technical-debt-register
    └── refactoring-roadmap
```

### Bead Naming Conventions
- Use kebab-case for bead names
- Prefix with phase numbers for clarity (e.g., `01-arch-`, `02-logic-`)
- Make names descriptive but concise
- Group related beads under parent directories

### Dependency Mapping Rules
1. **Sequential within phase**: Later tasks depend on earlier baseline understanding
2. **Cross-phase dependencies**: Document explicitly (e.g., UI analysis depends on ViewModel understanding)
3. **Parallel opportunities**: Identify tasks that can run concurrently
4. **Blocking vs non-blocking**: Distinguish critical path from nice-to-have
5. **Tool dependencies**: Some analyses require Instruments, profiling, or test runs

### Comment/Documentation Requirements

Each bead MUST include comprehensive comments covering:

#### 1. Purpose & Context
```
# Purpose: Analyze the ServiceRegistry implementation to understand dependency injection patterns
# Context: This is a service-based architecture where ServiceRegistry acts as the IoC container
# Part of: Phase 1.1 - Dependency Injection & Service Layer Architecture
```

#### 2. Background & Rationale
```
# Background:
#   - WPswitcher uses protocol-based dependency injection
#   - ServiceRegistry.swift is the central orchestrator
#   - Understanding this is foundational for all service analysis
#
# Rationale:
#   - Services are the core abstraction in this architecture
#   - All business logic flows through service protocols
#   - DI patterns affect testability and maintainability
```

#### 3. Detailed Task Description
```
# Tasks:
#   1. Read ServiceRegistry.swift thoroughly
#   2. Document all registered services and their protocols
#   3. Identify lifecycle management patterns (singleton, factory, etc.)
#   4. Trace how services are injected into views/viewmodels
#   5. Assess ease of adding new services
#   6. Document current limitations or technical debt
```

#### 4. Specific Investigation Points
```
# Investigation Points:
#   - Is lazy initialization used? Performance implications?
#   - Are there circular dependency risks?
#   - How are service mocks created for testing?
#   - What is the service disposal strategy?
#   - Can services be swapped at runtime? Should they be?
```

#### 5. Expected Artifacts
```
# Artifacts to Create:
#   - Service dependency graph (mermaid diagram or ASCII)
#   - Table of all services with:
#     * Protocol name
#     * Implementation class
#     * Lifecycle (singleton/transient/scoped)
#     * Dependencies
#   - Assessment document with findings
#   - Recommendations for improvements (if any)
```

#### 6. Dependencies & Blockers
```
# Dependencies:
#   - Requires: Basic codebase familiarity (prerequisite bead)
#   - Blocks: All service-specific analysis beads
#   - Related: Phase 1.2 (data architecture - some services manage Core Data)
#
# Prerequisite Knowledge:
#   - Swift protocols and protocol-oriented programming
#   - Dependency injection patterns
#   - Service locator vs IoC containers
```

#### 7. Acceptance Criteria
```
# Done When:
#   ✓ All services documented in structured format
#   ✓ Dependency graph created and validated
#   ✓ Lifecycle patterns understood and documented
#   ✓ Testability assessment complete
#   ✓ At least 2 specific findings or recommendations documented
#   ✓ Review with team/self validates understanding
```

#### 8. Time Estimate & Priority
```
# Estimated Effort: 3-4 hours
# Priority: P0 (Critical - foundational understanding)
# Risk: Low (pure analysis, no code changes)
# Value: High (enables all downstream service analysis)
```

#### 9. Notes for Future Self
```
# Future Self Notes:
#   - If you find circular dependencies, this needs immediate attention
#   - ServiceRegistry pattern may evolve - document current state clearly
#   - Consider if SwiftUI's @Environment could replace some DI
#   - Look for opportunities to leverage Swift's type system more
#   - This analysis feeds into Phase 6 (Testing) - note testability gaps
```

#### 10. Related Resources
```
# Related Files:
#   - ServiceRegistry.swift (primary)
#   - ServiceProtocols.swift (all protocol definitions)
#   - WPswitcherApp.swift (initialization point)
#   - *ViewModel.swift files (service consumers)
#
# Documentation References:
#   - Swift Protocol-Oriented Programming Guide
#   - Dependency Injection in Swift (best practices)
#   - SOLID principles (especially DIP)
```

---

## 🔧 Using the `bd` Tool

### Create Parent/Organizational Beads
```bash
# Create phase-level parent beads
bd phase-01-architecture "Phase 1: Architecture & Foundational Patterns"
bd phase-02-business-logic "Phase 2: Core Business Logic & Domain Features"
# ... etc
```

### Create Detailed Task Beads
```bash
# Create specific analysis task with full documentation
bd 01-arch-service-registry "Analyze ServiceRegistry & DI patterns" \
  --parent phase-01-architecture \
  --comment "$(cat <<'EOF'
Purpose: Analyze the ServiceRegistry implementation to understand dependency injection patterns
Context: This is a service-based architecture where ServiceRegistry acts as the IoC container
Part of: Phase 1.1 - Dependency Injection & Service Layer Architecture

Background:
  - WPswitcher uses protocol-based dependency injection
  - ServiceRegistry.swift is the central orchestrator
  - Understanding this is foundational for all service analysis

[... FULL DOCUMENTATION AS DESCRIBED ABOVE ...]
EOF
)"
```

### Set Dependencies
```bash
# Set dependencies between beads
bd dep 01-arch-service-registry --on 00-baseline-codebase-familiarity
bd dep 02-logic-wallpaper-service --on 01-arch-service-registry
```

### Mark Priority and Metadata
```bash
# Add priority tags
bd tag 01-arch-service-registry priority:p0 effort:3h phase:1
```

---

## 📊 Dependency Structure Guidelines

### Critical Path (Must be sequential)
1. **Baseline Setup**
   - Initial codebase exploration
   - Build and run verification
   - Test suite baseline execution
   
2. **Foundational Understanding** (Phase 1)
   - Service architecture
   - Data model
   - State management patterns
   
3. **Service-by-Service Analysis** (Phase 2)
   - Each service can be analyzed once foundation is understood
   - Some services have dependencies on others
   
4. **UI Layer** (Phase 3)
   - Requires understanding of ViewModels and Services
   
5. **Cross-Cutting Concerns** (Phases 4-5)
   - Security, performance, concurrency
   - Can happen after understanding architecture
   
6. **Testing & Quality** (Phase 6)
   - Requires understanding of entire codebase
   
7. **Deliverables** (End)
   - Synthesize all findings

### Parallelization Opportunities
- Multiple service analyses can run in parallel (after foundation)
- View analyses can be parallel
- Security audit can run parallel to performance analysis
- Documentation review can run parallel to code analysis

### Gating Dependencies
Identify which beads are **gates** that block large numbers of downstream beads:
- Understanding ServiceRegistry (gates all service analysis)
- Understanding Core Data schema (gates all persistence analysis)
- Understanding MVVM pattern (gates all UI analysis)

---

## 🎯 Specific Instructions for Bead Creation

### Phase 1: Architecture (High Priority)
- Create ~15-20 beads covering:
  - Service registry deep dive
  - Each protocol in ServiceProtocols.swift
  - Core Data stack analysis
  - Migration strategy review
  - Domain model mapping
  - State management patterns
  - ObservableObject usage audit

### Phase 2: Business Logic (High Priority)
- Create ~20-25 beads for:
  - WallpaperService complete analysis
  - File system integration review
  - Sandboxing and security-scoped bookmarks
  - Image processing pipeline
  - PlaylistStore analysis
  - Scheduling algorithm review
  - Display assignment logic
  - Light/dark mode handling

### Phase 3: UI Layer (Medium Priority)
- Create ~15-20 beads for:
  - View hierarchy mapping
  - Each major view (Library, Editor, Settings)
  - ViewModel pattern analysis
  - State propagation audit
  - Performance optimization review

### Phase 4-5: Security & Performance (Medium Priority)
- Create ~15-20 beads for:
  - Entitlements audit
  - Sandboxing review
  - Threading model analysis
  - Memory management audit
  - Performance profiling tasks
  - Instruments analysis sessions

### Phase 6: Testing & Quality (Medium Priority)
- Create ~10-15 beads for:
  - Test coverage analysis
  - Integration test review
  - Error handling audit
  - Code quality metrics
  - Complexity analysis

### Phase 7-9: Build & Deploy (Lower Priority)
- Create ~8-10 beads for:
  - Xcode project configuration
  - Build settings review
  - Signing and capabilities
  - Distribution analysis

### Phase 10-14: Advanced Topics (Lower Priority)
- Create ~10-15 beads for:
  - Technical debt inventory
  - Documentation review
  - Best practices compliance
  - OWASP security checklist
  - Extensibility analysis

### Deliverables (End Game)
- Create ~8-10 beads for:
  - Executive summary synthesis
  - Technical debt register compilation
  - Architecture diagram creation
  - Refactoring roadmap development
  - Test coverage gap report
  - Performance optimization plan
  - Security assessment report
  - Metrics dashboard setup

---

## 📝 Elaboration Requirements

As you read ANALYSIS_PLAN.md, **expand and elaborate** on sections that need more depth:

### Add Concrete Examples
Where the plan says "analyze error handling," expand to:
- Review Swift Error protocol usage
- Check for do-catch blocks
- Verify error context preservation
- Look for force-unwraps (!)
- Check for fatalError usage
- Review NSError bridging
- Assess user-facing error messages

### Add Tool-Specific Instructions
Where the plan mentions "profiling," specify:
- Use Instruments Time Profiler
- Record 30-second session during wallpaper switch
- Filter to app symbols only
- Identify functions >50ms
- Check for main thread blocking
- Document top 10 hotspots

### Add File-Specific Mappings
Link each analysis point to specific files:
- "Analyze scheduling logic" → SchedulerCoordinator.swift, Timer management in Services
- "Review view hierarchy" → WPswitcherApp.swift → MainWindowView.swift → subviews

### Add Decision Frameworks
For subjective assessments, provide criteria:
- "Assess code quality" → Check: naming, complexity, duplication, test coverage, documentation
- "Evaluate architecture" → Check: separation of concerns, coupling, cohesion, SOLID principles

---

## 🚀 Execution Strategy

### Phase Order Recommendation
1. **Phase 0** (New): Baseline & Environment Setup
   - Clone/build verification
   - Run existing tests
   - Instruments setup
   - Documentation tools setup

2. **Phase 1**: Architecture (3-4 days)
   - Foundation for everything else
   - High leverage understanding

3. **Phase 2**: Business Logic (3-4 days)
   - Core functionality deep dive
   - Identifies main risk areas

4. **Phase 3**: UI Layer (1-2 days)
   - Faster once services understood

5. **Phase 4-5**: Security & Performance (2-3 days)
   - Can partially overlap with Phase 3

6. **Remaining Phases**: Execute based on findings and priorities

### Checkpoint Strategy
After each major phase:
- Create checkpoint bead
- Synthesize findings so far
- Update priority of remaining beads
- Adjust plan based on discoveries

---

## 🎨 Example Bead Creation Script

Here's an example of how to create one comprehensive bead:

```bash
bd 01-arch-01-service-registry-core "Deep Analysis: ServiceRegistry Implementation" \
  --parent phase-01-architecture \
  --comment "$(cat <<'EOFCOMMENT'
═══════════════════════════════════════════════════════════════════════════════
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
     - Document with Mermaid diagram or ASCII art:
       ```
       ServiceRegistry
         ├─> PersistenceController (Core Data)
         ├─> WallpaperService
         │     └─> PersistenceController (depends on)
         ├─> PlaylistStore
         │     └─> PersistenceController (depends on)
         └─> SchedulerCoordinator
               ├─> WallpaperService (depends on)
               └─> PlaylistStore (depends on)
       ```

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
     - Minimum 2 recommendations (even if "no changes needed")
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
    • "ServiceRegistry is the heart of the DI system"
    • "Every business capability is a service"
    • "Protocols define contracts, classes implement"

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
    • Xcode: "Jump to Definition" for tracing
    • Xcodeproj: Dependency graph visualization (if available)
    • grep/rg: Find all service usage patterns
    • Graphviz/Mermaid: Diagram generation

═══════════════════════════════════════════════════════════════════════════════
END OF BEAD DOCUMENTATION
═══════════════════════════════════════════════════════════════════════════════
EOFCOMMENT
)" \
  --estimate "3-4h" \
  --priority "P0"

# Set dependencies
bd dep 01-arch-01-service-registry-core --on 00-baseline-setup
bd dep 02-logic-* --on 01-arch-01-service-registry-core

# Tag for organization
bd tag 01-arch-01-service-registry-core \
  phase:1 \
  category:architecture \
  risk:low \
  value:high \
  type:analysis
```

---

## ✅ Your Deliverables

1. **Complete Bead Hierarchy** (~100-150 beads total)
   - All phases covered
   - Proper parent-child relationships
   - Clear naming conventions

2. **Dependency Graph**
   - All dependencies mapped
   - Critical path identified
   - Parallelization opportunities marked

3. **Enhanced Analysis Plan**
   - Elaborations on vague items
   - Concrete examples added
   - Tool-specific instructions
   - File mappings complete

4. **Execution Guide**
   - Suggested order of execution
   - Checkpoint strategy
   - Time estimates refined

5. **Self-Contained Documentation**
   - Each bead fully self-documenting
   - Future self can pick up any bead and execute
   - Context always clear
   - Rationale always explained

---

## 🎯 Success Criteria for This Handoff

You will know you've succeeded when:

✅ Someone unfamiliar with the project could:
   - Pick any bead
   - Understand its purpose without external context
   - Execute it following the instructions
   - Produce the expected artifacts
   - Know what to do next (via dependencies)

✅ The bead structure demonstrates:
   - Logical progression from foundation to specifics
   - Clear dependency chains
   - Realistic effort estimates
   - Comprehensive coverage of ANALYSIS_PLAN.md
   - No orphaned or unreachable beads

✅ The documentation shows:
   - Deep technical understanding
   - Architectural thinking
   - Practical execution focus
   - Quality consciousness
   - Continuous learning mindset

---

## 🚀 Begin Your Analysis

Start by:
1. Reading ANALYSIS_PLAN.md completely
2. Using ultrathink to reason about optimal decomposition
3. Creating the bead hierarchy (parents first)
4. Populating detailed beads (following the example above)
5. Mapping all dependencies
6. Validating the critical path makes sense
7. Adding time estimates and priorities
8. Creating a visualization of the bead graph

**Remember:** Every bead should be so well-documented that your "future self" (or another developer) can execute it 6 months from now without additional context.

**Good luck! The quality of this bead structure will directly impact the success of the entire WPswitcher analysis project.** 🎯
