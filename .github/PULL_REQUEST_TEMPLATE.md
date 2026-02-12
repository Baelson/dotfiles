# Pull Request Evidence Checklist

## Implementation Evidence

- [ ] **Feature Implemented**: Code changes are present and complete
- [ ] **Tests Pass**: `bats tests/` passes all relevant tests
- [ ] **Behavioral Tests**: Tests prove feature WORKS, not just that code runs
- [ ] **Negative Tests**: Tests prove feature FAILS CORRECTLY with invalid input
- [ ] **Manual Verification**: Feature tested manually and works as expected

## Test Quality Evidence

For each new test added, provide evidence the test can fail:

### Test: [Test Name]

**Positive Case** (test passes when implementation correct):
```bash
# Command run:
$ bats tests/path/to/test.bats -f "Test Name"

# Result:
✓ Test Name
```

**Negative Case** (test fails when implementation broken):
```bash
# What was changed to break implementation:
# (e.g., "Removed argument parsing code", "Changed --dry-run to be ignored")

# Command run:
$ bats tests/path/to/test.bats -f "Test Name"

# Result:
✗ Test Name
  (from function `assert_whatever' in file ...)
  ERROR: [Specific failure message]
```

## Documentation Evidence

- [ ] **Requirements Updated**: PRD.md reflects any requirement changes
- [ ] **Implementation Documented**: SYSTEM_DESIGN.md updated for architecture changes
- [ ] **Tests Documented**: TESTING.md updated with new test procedures
- [ ] **Lessons Captured**: CLAUDE.md updated with new patterns/lessons learned

## Branch Hygiene Evidence

- [ ] **Main Branch Synced**: `git log --oneline main ^HEAD` shows no commits (this branch is up-to-date with main)
- [ ] **Tests Pass on Main**: All tests pass on main branch before merge
- [ ] **No WIP Commits**: No commit messages contain "WIP", "TODO", "FIXME"
- [ ] **Clean History**: Commits follow conventional commit format

## Deployment Evidence (if applicable)

- [ ] **Dry-Run Tested**: `./setup.sh --dry-run` completes without errors
- [ ] **Manual Test**: Feature tested on clean macOS system (if system-level change)
- [ ] **Rollback Plan**: Documented how to revert changes if issues discovered

---

## Evidence of Test Quality

**CRITICAL**: For any test related to functional requirements (FR-1 through FR-7),
you must prove the test can detect when the feature is broken.

Example:

### Test: FR-7.1 --dry-run makes no system modifications

**Implementation Location**: setup.sh:238-240
```bash
if [[ "$DRY_RUN" == "true" ]]; then
    echo "🔍 DRY RUN MODE: No system changes will be made"
fi
```

**Test Can Pass** (Implementation Correct):
```bash
$ bats tests/system/test_fr7_debug_modes.bats -f "FR-7.1"
✓ FR-7.1: --dry-run makes NO system modifications
```

**Test Can Fail** (Implementation Broken):

Broke implementation by commenting out dry-run check:
```bash
# if [[ "$DRY_RUN" == "true" ]]; then
#     echo "🔍 DRY RUN MODE: No system changes will be made"
# fi
```

Result:
```bash
$ bats tests/system/test_fr7_debug_modes.bats -f "FR-7.1"
✗ FR-7.1: --dry-run makes NO system modifications
  (from function `assert_argument_processed' in file behavioral_helpers.bash, line 23)
  ERROR: --dry-run not processed (no dry-run indicators)
```

This proves the test ACTUALLY VALIDATES the feature works.
