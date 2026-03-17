# MechSurvivors — TDD Workflow Guide for AI Agents

## Project Overview
Top-down 2D Vampire Survivors-like game built with Godot 4.6+.

## Testing Frameworks Installed

### 1. GUT (Godot Unit Testing) — `addons/gut/`
- **Best for**: Unit tests, fast iteration, CLI-friendly
- **Test location**: `tests/unit/`, `tests/integration/`
- **Test file prefix**: `test_` (e.g., `test_player_stats.gd`)
- **Test method prefix**: `test_` (e.g., `func test_take_damage():`)
- **Base class**: `extends GutTest`

### 2. GdUnit4 — `addons/gdUnit4/`
- **Best for**: Advanced assertions, mocking, scene testing
- **Test location**: Same directories
- **Base class**: `extends GdUnitTestSuite`

## Running Tests from CLI (Agent-Friendly)

```powershell
# Run ALL GUT tests (headless)
.\run_tests.ps1

# Run only unit tests
.\run_tests.ps1 -Unit

# Run only integration tests
.\run_tests.ps1 -Integration

# Run specific test by name filter
.\run_tests.ps1 -Filter "test_player_stats"

# Direct Godot command (if scripts don't work)
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```

## TDD Cycle (Red-Green-Refactor)

1. **RED**: Write a failing test first in `tests/unit/test_<feature>.gd`
2. **GREEN**: Write minimal code in `src/<module>/` to make the test pass
3. **REFACTOR**: Clean up while keeping tests green
4. **VERIFY**: Run `.\run_tests.ps1` to confirm all tests pass

## Project Structure

```
MechSurvivors/
├── src/                    # Game source code
│   ├── player/             # Player scripts & stats
│   ├── enemies/            # Enemy scripts & data
│   ├── weapons/            # Weapon scripts & data
│   ├── pickups/            # XP gems, health pickups
│   ├── ui/                 # HUD, menus, level-up screen
│   ├── autoload/           # Singletons (GameManager)
│   └── levels/             # Level/wave management
├── scenes/                 # .tscn scene files (mirrors src/)
├── tests/
│   ├── unit/               # Fast, isolated unit tests
│   └── integration/        # Tests needing scene tree
├── assets/                 # Sprites, audio, fonts
├── addons/
│   ├── gut/                # GUT testing framework
│   └── gdUnit4/            # GdUnit4 testing framework
├── project.godot           # Godot project config
├── .gutconfig.json         # GUT CLI configuration
├── run_tests.ps1           # Test runner script (GUT)
└── run_tests_gdunit.ps1    # Test runner script (GdUnit4)
```

## Writing a New Test (Template)

```gdscript
# tests/unit/test_my_feature.gd
extends GutTest

var _sut  # System Under Test

func before_each():
    _sut = MyClass.new()

func test_it_does_the_thing():
    _sut.do_thing()
    assert_eq(_sut.result, expected_value, "Description of what we expect")

func test_edge_case():
    assert_true(_sut.handles_edge_case(), "Should handle edge case")
```

## Key Assertions (GUT)

| Assertion | Usage |
|-----------|-------|
| `assert_eq(a, b)` | a == b |
| `assert_ne(a, b)` | a != b |
| `assert_gt(a, b)` | a > b |
| `assert_lt(a, b)` | a < b |
| `assert_true(a)` | a is true |
| `assert_false(a)` | a is false |
| `assert_null(a)` | a is null |
| `assert_not_null(a)` | a is not null |
| `assert_has(obj, val)` | obj contains val |

## Physics Layers

| Layer | Purpose |
|-------|---------|
| 1 | Player |
| 2 | Enemies |
| 3 | Pickups |
| 4 | Projectiles |
