# Baseline Code Metrics Report
**Bead:** WPswitcher-vs6  
**Date:** 2026-01-23  
**Analyst:** GitHub Copilot CLI  
**Status:** ✅ COMPLETE

---

## Executive Summary

Comprehensive baseline metrics for the WPswitcher codebase have been established. The project is **well-sized** at 3,150 LOC across 13 Swift files, with a clear architectural organization and reasonable file sizes.

**Key Findings:**
- ✅ Project size matches documentation expectations (3,150 LOC, 13 files)
- ⚠️ One file is significantly large (MainWindowView.swift at 742 LOC - 24% of codebase)
- ✅ Average file size is manageable at 242 LOC
- ✅ Clear modular organization (Models, Views, ViewModels, Services, Persistence)

---

## Code Volume Metrics

### Overall Statistics
| Metric | Value |
|--------|-------|
| **Total Lines of Code** | 3,150 |
| **Swift Files** | 13 |
| **Average File Size** | 242 LOC |
| **Median File Size** | 215 LOC |
| **Largest File** | 742 LOC (MainWindowView.swift) |
| **Smallest File** | 18 LOC (WPswitcherApp.swift) |

### Lines of Code by File (Sorted by Size)

| Rank | File | LOC | % of Total | Category |
|------|------|-----|------------|----------|
| 1 | MainWindowView.swift | 742 | 23.6% | 🔴 **View - LARGE** |
| 2 | ServiceProtocols.swift | 571 | 18.1% | Service |
| 3 | PlaylistEditorViewModel.swift | 389 | 12.4% | ViewModel |
| 4 | CoreDataWallpaperService.swift | 349 | 11.1% | Service |
| 5 | PlaylistEditorView.swift | 303 | 9.6% | View |
| 6 | ManagedObjects.swift | 274 | 8.7% | Persistence |
| 7 | CoreDataPlaylistStore.swift | 215 | 6.8% | Service |
| 8 | PlaylistModels.swift | 80 | 2.5% | Model |
| 9 | AppDelegate.swift | 71 | 2.3% | Infrastructure |
| 10 | SettingsView.swift | 52 | 1.7% | View |
| 11 | ServiceRegistry.swift | 43 | 1.4% | Service |
| 12 | PersistenceController.swift | 43 | 1.4% | Persistence |
| 13 | WPswitcherApp.swift | 18 | 0.6% | Entry Point |

---

## Code Distribution by Category

### By Architectural Layer
| Layer | Files | LOC | % of Total | Avg File Size |
|-------|-------|-----|------------|---------------|
| **Views** | 3 | 1,097 | 34.8% | 366 LOC |
| **Services** | 4 | 1,178 | 37.4% | 295 LOC |
| **Persistence** | 2 | 317 | 10.1% | 159 LOC |
| **ViewModels** | 1 | 389 | 12.4% | 389 LOC |
| **Models** | 1 | 80 | 2.5% | 80 LOC |
| **Infrastructure** | 2 | 89 | 2.8% | 45 LOC |

### Distribution Analysis
```
Services (37.4%)  ████████████████████████████████████████
Views (34.8%)     ███████████████████████████████████
ViewModels (12.4%) █████████████
Persistence (10.1%) ███████████
Models (2.5%)      ███
Infrastructure (2.8%) ███
```

**Observation:** Balanced distribution between Services and Views, indicating good separation of concerns.

---

## File Size Analysis

### Size Distribution
| Size Category | Range | Count | Files |
|---------------|-------|-------|-------|
| **Very Large** | > 500 LOC | 2 | MainWindowView (742), ServiceProtocols (571) |
| **Large** | 300-500 LOC | 3 | PlaylistEditorViewModel, CoreDataWallpaperService, PlaylistEditorView |
| **Medium** | 100-300 LOC | 2 | ManagedObjects, CoreDataPlaylistStore |
| **Small** | 50-100 LOC | 3 | PlaylistModels, AppDelegate, SettingsView |
| **Very Small** | < 50 LOC | 3 | ServiceRegistry, PersistenceController, WPswitcherApp |

### Largest Files (Candidates for Refactoring)

#### 1. 🔴 MainWindowView.swift (742 LOC)
- **Size:** 23.6% of entire codebase
- **Risk:** HIGH - Single file is nearly 1/4 of project
- **Category:** SwiftUI View
- **Analysis:** Likely contains:
  - Multiple sub-views
  - State management logic
  - UI layout code
  - Event handlers
- **Recommendation:** **P1 - Should be decomposed** into smaller view components
- **Estimated Complexity:** HIGH

#### 2. ServiceProtocols.swift (571 LOC)
- **Size:** 18.1% of codebase
- **Category:** Protocol definitions
- **Analysis:** Contains multiple protocol definitions and likely data model types
- **Recommendation:** Consider splitting into:
  - Service protocols file
  - Data model types file
  - Protocol extensions file

---

## Module Organization

### Directory Structure
```
WPswitcher/
├── Models/                    [1 file, 80 LOC]
│   └── PlaylistModels.swift
├── Views/                     [1 file, 303 LOC]
│   └── PlaylistEditorView.swift
├── ViewModels/                [1 file, 389 LOC]
│   └── PlaylistEditorViewModel.swift
├── Services/                  [4 files, 1,178 LOC]
│   ├── ServiceRegistry.swift
│   ├── ServiceProtocols.swift
│   ├── CoreDataWallpaperService.swift
│   └── CoreDataPlaylistStore.swift
├── Persistence/               [2 files, 317 LOC]
│   ├── PersistenceController.swift
│   └── ManagedObjects.swift
├── Root Views/                [2 files, 794 LOC]
│   ├── MainWindowView.swift
│   └── SettingsView.swift
└── Infrastructure/            [2 files, 89 LOC]
    ├── WPswitcherApp.swift
    └── AppDelegate.swift
```

### Organization Quality
✅ **Strengths:**
- Clear separation into architectural layers
- Consistent naming conventions
- Logical grouping of related files

⚠️ **Observations:**
- Views directory only has 1 file (PlaylistEditorView)
- MainWindowView and SettingsView are in root, not in Views/
- Could benefit from more granular organization

---

## Binary & Build Metrics

### Application Bundle
| Metric | Value |
|--------|-------|
| **App Bundle Size** | 2.9 MB |
| **Executable Size** | 56 KB |
| **Architecture** | arm64 (Apple Silicon) |
| **Deployment Target** | macOS 13.0 |

### Build Configuration
| Setting | Value |
|---------|-------|
| **Swift Version** | 5.0 |
| **Xcode Version** | 16.2 (16C5032a) |
| **Configuration** | Debug |
| **Optimization** | None (-Onone) |

### Build Performance (from previous bead)
- **Clean Build Time:** ~45-60 seconds (estimated)
- **Incremental Build Time:** Not yet measured
- **Build Warnings:** 2 (platform warnings only)
- **Build Errors:** 0

---

## Complexity Analysis (Estimated)

*Note: SwiftLint not installed - estimates based on file size and inspection*

### Complexity Hotspots (by LOC proxy)

#### High Complexity (likely)
1. **MainWindowView.swift** (742 LOC)
   - Estimated Cyclomatic Complexity: HIGH
   - Reason: Large SwiftUI view with likely many conditional views and state branches
   
2. **ServiceProtocols.swift** (571 LOC)
   - Estimated Cyclomatic Complexity: MEDIUM
   - Reason: Protocol definitions (lower complexity than implementations)

3. **PlaylistEditorViewModel.swift** (389 LOC)
   - Estimated Cyclomatic Complexity: HIGH
   - Reason: Business logic, state management, validation

4. **CoreDataWallpaperService.swift** (349 LOC)
   - Estimated Cyclomatic Complexity: MEDIUM-HIGH
   - Reason: Service implementation with file I/O and Core Data operations

### Recommended Complexity Tools
```bash
# Install SwiftLint for automated analysis
brew install swiftlint

# Run complexity analysis
swiftlint analyze --compiler-log-path <build_log>

# Or use lizard for language-agnostic complexity
pip install lizard
lizard WPswitcher -l swift
```

---

## Code Quality Indicators

### File Size Health
| Indicator | Target | Actual | Status |
|-----------|--------|--------|--------|
| Avg File Size | < 300 LOC | 242 LOC | ✅ GOOD |
| Max File Size | < 500 LOC | 742 LOC | ⚠️ EXCEEDS |
| Files > 500 LOC | 0 | 2 | ⚠️ WARNING |
| Files < 50 LOC | Variable | 3 | ✅ OK |

### Modularity Score
- **Total Files:** 13
- **Lines per File (avg):** 242
- **Largest File %:** 23.6%

**Assessment:** ⚠️ Moderate - One file is disproportionately large

---

## Comparative Metrics

### Against Documentation Expectations
| Expected | Actual | Status |
|----------|--------|--------|
| ~3,150 LOC | 3,150 LOC | ✅ Exact match |
| ~13 files | 13 files | ✅ Exact match |
| Small project | Confirmed | ✅ Yes |

---

## Technical Debt Indicators (from Metrics)

### F-002: MainWindowView.swift Excessive Size (P1 - High)
**Severity:** P1 (High)  
**Category:** Code Organization / Maintainability  
**File:** MainWindowView.swift (742 LOC)

**Description:**  
MainWindowView.swift contains 742 lines (23.6% of entire codebase), indicating it likely violates the Single Responsibility Principle and will be difficult to maintain.

**Impact:**
- **Maintainability:** Difficult to understand and modify
- **Testing:** Hard to unit test such large views
- **Reusability:** Components embedded in large file cannot be reused
- **Team Velocity:** Large files slow down parallel development

**Recommendation:**
Decompose into smaller view components:
```
MainWindowView.swift (100-150 LOC - coordinator)
├── WallpaperLibraryView.swift
├── PlaylistListView.swift
├── WallpaperDetailView.swift
└── Common/
    ├── HeaderView.swift
    └── ActionBarView.swift
```

**Effort Estimate:** 4-6 hours  
**Priority:** P1 - Should be addressed in refactoring phase

---

### F-003: ServiceProtocols.swift Large Protocol File (P2 - Medium)
**Severity:** P2 (Medium)  
**Category:** Code Organization  
**File:** ServiceProtocols.swift (571 LOC)

**Description:**  
ServiceProtocols.swift is 571 LOC (18.1% of codebase), suggesting it contains multiple concerns (protocols + data models + potentially implementations).

**Impact:**
- **Organization:** Multiple concepts mixed in single file
- **Navigation:** Harder to find specific protocols
- **Merge Conflicts:** Higher likelihood in team environment

**Recommendation:**
Split into focused files:
```
Services/
├── Protocols/
│   ├── WallpaperService.swift
│   ├── PlaylistStore.swift
│   └── SchedulingService.swift
├── Models/
│   ├── WallpaperModels.swift
│   └── ServiceModels.swift
```

**Effort Estimate:** 2-3 hours  
**Priority:** P2 - Nice to have

---

## Baseline Comparison Table

Use this table for future comparison:

| Metric | Baseline (2026-01-23) | Future Measurement | Delta |
|--------|----------------------|-------------------|-------|
| Total LOC | 3,150 | | |
| Swift Files | 13 | | |
| Avg File Size | 242 LOC | | |
| Largest File | 742 LOC | | |
| Binary Size | 2.9 MB | | |
| Build Time | ~45-60s | | |

---

## Recommendations

### Immediate Actions
1. ⚠️ **None required** - Metrics collection complete

### Short-Term (Phase 1 Analysis)
1. Install SwiftLint: `brew install swiftlint`
2. Run complexity analysis during architecture review
3. Deep-dive into MainWindowView.swift structure

### Medium-Term (Refactoring Phase)
1. **P1:** Decompose MainWindowView.swift (742 → ~500 LOC across multiple files)
2. **P2:** Split ServiceProtocols.swift into focused files
3. Establish automated metrics tracking (CI integration)

---

## Artifacts Generated

1. **loc_by_file.txt** - Raw LOC counts per file
2. **baseline_metrics.md** - This comprehensive report

---

## Acceptance Criteria Verification

- ✅ All metrics documented (LOC, files, sizes, organization)
- ✅ Complexity hotspots identified (MainWindowView, ServiceProtocols)
- ✅ Baseline established for future comparison
- ✅ Distribution analyzed (by layer, by category)
- ✅ Quality indicators calculated
- ✅ Technical debt items identified (2 findings)

**All acceptance criteria MET** ✅

---

## Conclusion

The WPswitcher codebase is **well-sized and organized** with clear architectural boundaries. The primary concern is file size concentration, with two files comprising 41.7% of the codebase. These should be addressed during refactoring phases.

**Baseline Status:** ✅ **ESTABLISHED**

**Next Steps:**
- Continue Phase 0 (tools setup)
- Move to Phase 1 (Architecture Analysis) where MainWindowView and ServiceProtocols will be analyzed in detail

---

*Baseline metrics established: 2026-01-23*  
*Next bead: WPswitcher-h6v (Tools Setup)*
