# DMUD — Test Case Design: Issue #21 Low-Hanging-Fixes Batch + Gem Packaging

SE run #1502, step 3 (Quality Assurance), **revised per step 4 review**
(NOVA, Project Leadership, 2026-11-20). This is a **test design document**,
not an implementation. No minitest code lives here; the runnable suite will
live in `test/` and run via `rake test`, per the agreed design in
[#21](https://github.com/dtrammell/dmud/issues/21).

Base commit: `c57546a3b09153a5276ae407677d6836197bc11c` on `main`.
Branch: `feature/issue-21-low-hanging-batch`.

> **Revision note:** the step-3 draft hedged ten points as `ASSUMPTION`
> because the #21 AC text didn't pin an exact value. Step 4 supplied
> explicit rulings for all ten, quoted inline below as **RULING:**, and
> all `ASSUMPTION` language has been replaced with pinned, literal
> expected values. Step 4 also flagged four defects in the step-3 draft
> itself (bare-area-name matching that can pass for the wrong reason, a
> traversal vehicle that silently exercises an out-of-scope quirk,
> hard-coded gate names that the batch is about to change, and missing
> guidance on subprocess timeouts given the unchanged per-turn `sleep 1`);
> all four are fixed below and noted where they land.

Every expected result below is derived from the text of issue #21's
"Agreed design / acceptance criteria" section (quoted inline as **AC:**),
the step-4 rulings (quoted as **RULING:**), the individual issue
bodies/comments (#1–#9, #20), or — where none of those says anything —
the **unchanged, currently-documented behavior** in `docs/ARCHITECTURE.md`
/ `docs/KNOWN_ISSUES.md` (quoted as **Unchanged:**), or a plain static
read of the example-world construction script's source order (quoted as
**Derived from source order:** — this is reading text, not running code).
No expected value in this document was derived by running code.

## Conventions used below

- **Test Fixture World**: a minimal in-process world built directly with
  `Region`/`Area`/`Gate`/`Player` (no `Session`), mirroring the shape
  `test_game.rb` / the future `examples/` script builds: a `Foyer` with
  gates to `Grand Hall`, `Stairs`, and a `Secret Room` (Secret Room's own
  side marked not-visible, Foyer's side visible — same as today), plus a
  `Game Entrance` gate from a `Game Lobby` (Lobby's side not-visible),
  with gates attached to Foyer **in the same order the example-world
  script attaches them today**: entrance gate first, then Grand Hall, then
  Stairs, then Secret Room. This ordering is load-bearing for TC-1502-050
  below and is read directly from the example-world script's source, not
  assumed. Used for all unit-level construction/command/gate tests so we
  never have to instantiate `Session` (its constructor runs an infinite
  loop today — [#16](https://github.com/dtrammell/dmud/issues/16),
  explicitly out of scope — so tests must never call `Session.new`).
- **Player name convention**: every fixture (Test Fixture World and the
  real `examples/` script) uses `"Leeroy Jenkins"` as the player name,
  matching the existing, unchanged constant in today's `test_game.rb`.
  This makes the pinned goodbye text (see Section G, RULING #6) an exact,
  literal string rather than a pattern match.
- **the example world**: whatever single script ships under `examples/`
  after the gem-layout work. Its exact filename isn't specified by #20/#21,
  so tests locate it with `Dir.glob('examples/*.rb')` rather than a
  hard-coded name, and fail loudly with a clear message if more than one
  candidate exists.
- **Gate names are not hard-coded.** Step 4 confirmed the batch gives the
  example world's gates new player-facing names, so no test in this
  document asserts a literal gate name string drawn from today's
  `test_game.rb` (e.g. `"Game Entrance"`, `"Foyer<>Grand Hall Gate"`).
  Where a test needs to assert output that includes a gate's name, it
  either (a) builds its own gate in-test and names it itself (e.g. a
  `TestGate` named `"Toll Gate"`), or (b) reads the name off the real
  gate object at test time via `gate.metadata[:name]` and asserts against
  that captured value, never against a literal string.
- **Driving `Player#query` without a real TTY:** per RULING #10 below,
  the implementation reads lines via `Reline.readline` directly (not the
  `Readline` compatibility module). Stub `Reline.readline` to return the
  given *Input* string once, then call `query`/`command` and capture
  output via a `Player#message` override or `$stdout` capture.
- **Subprocess timeouts (defect D):** `Session#start`'s infinite loop
  still calls `sleep 1` after every single turn (#16, out of scope,
  unchanged). Every real-subprocess test in Sections G and M therefore has
  a wall-clock floor of roughly one second per piped command before EOF —
  e.g. TC-1502-113 pipes 5 commands, so its floor is ~5s. All subprocess
  tests in this document should be given a **generous timeout, around
  30 seconds**, not because any single test is expected to take that long,
  but to absorb that floor plus ordinary CI scheduling jitter without
  becoming flaky. See TC-1502-118 for the single place this rationale is
  written out in full.
- "Automated minitest" = belongs in `test/`, runs under `rake test`,
  must pass unattended. "Manual check" = needs a human, a real terminal/PTY,
  or is otherwise impractical to assert deterministically in CI.
- **Bare-area-name matching is banned in subprocess-stdout assertions
  (defect A).** An `Area`'s own description text can legitimately mention
  *other* area names (e.g. Grand Hall's description says "To the South is
  the Foyer"), so a test that just greps for `"Grand Hall"` appearing
  somewhere in stdout can pass even if the player never actually arrived
  there. Every subprocess-stdout test that needs to confirm *which room the
  player is in* asserts on the literal `"Location: <name>"` line (the one
  line `Area#describe` emits for the room the player currently occupies),
  never a bare substring match on the area's name.

---

## A. Ruby version floor (AC: "Ruby 3.3+")

### TC-1502-001 — `.ruby-version` pins 3.3 or newer
- **Covers:** #21 AC "Add a `.ruby-version` file"
- **Type:** automated minitest
- **Setup:** none
- **Input:** read `.ruby-version` from repo root
- **Expected:** file exists, content parses as a Ruby version `>= 3.3.0`
  (e.g. `Gem::Version.new(content.strip) >= Gem::Version.new('3.3.0')`).
  Derivation: AC line verbatim.

### TC-1502-002 — README states the minimum Ruby version
- **Covers:** #21 AC "the README states the minimum"
- **Type:** automated minitest (content grep)
- **Setup:** none
- **Input:** read `README.md`
- **Expected:** contains a `3.3` version mention in a "Requirements"-style
  context (regex like `/Ruby.{0,20}3\.3/`). Derivation: AC line verbatim.

### TC-1502-003 — gemspec `required_ruby_version` boundary
- **Covers:** #21 AC "`dmud.gemspec` sets `required_ruby_version >= 3.3`"
- **Type:** automated minitest
- **Setup:** load `dmud.gemspec` via `Gem::Specification::load`
- **Input:** `spec.required_ruby_version`
- **Expected (boundary):** `satisfied_by?(Gem::Version.new('3.3.0'))` is
  true; `satisfied_by?(Gem::Version.new('3.2.9'))` is false. Derivation:
  AC line verbatim (`>= 3.3` is an inclusive lower boundary).

---

## B. Gem layout (#20, #8)

### TC-1502-004 — `lib/dmud.rb` exists and loads every class file
- **Covers:** #20 "lib/dmud.rb loads lib/dmud/*.rb"; AC "Gem layout (#20)"
- **Type:** automated minitest (static source scan)
- **Setup:** read `lib/dmud.rb`
- **Input:** n/a
- **Expected:** contains a `require_relative` (not `require`) for each of
  the seven classes' files under `dmud/` (dmud_object, region, area, gate,
  mobile_object, player, session — by whatever names TC-1502-005 confirms).
  Derivation: AC "lib/dmud.rb loads lib/dmud/*.rb" + AC "require_relative is
  used throughout (#8)".

### TC-1502-005 — one class per file, file named after its class
- **Covers:** #20 AC parenthetical example
- **Type:** automated minitest
- **Setup:** `require_relative '../lib/dmud'` once
- **Input:** for each of `DMUDObject, Region, Area, Gate, MobileObject,
  Player, Session, Item, NPC, MOB`, compute the expected snake_case file
  stem (e.g. `MobileObject` → `mobile_object`)
- **Expected:** `lib/dmud/<stem>.rb` exists for each of the seven primary
  classes; `Item`/`NPC`/`MOB` may live in `mobile_object.rb` alongside
  their parent (this mirrors the pre-existing single-file grouping and the
  AC doesn't say otherwise) — the test only requires each of the seven
  *named* classes in the AC's example to have its own correctly-named file.
  Derivation: AC "one class per file, each file named after its class, so
  `class_movable_object.rb` becomes `mobile_object.rb`" (the literal
  example given).

### TC-1502-006 — old flat files are deleted (RULING #8, no longer an assumption)
- **Covers:** #20 gem layout
- **Type:** automated minitest
- **Setup:** none
- **Input:** `Dir.glob('class_*.rb')` and `Dir.glob('dmud.rb')` at repo
  root
- **Expected:** empty — the old-style flat `.rb` files at the repo root
  are gone, not duplicated alongside the new `lib/` tree. Derivation:
  **RULING #8** ("The old flat files are deleted"), pinned explicitly in
  the step-4 review, replacing the step-3 draft's assumption.

### TC-1502-007 — `mobile_object.rb` defines `MobileObject`, not `MovableObject`
- **Covers:** #9, AC "The `MobileObject` class name is kept."
- **Type:** automated minitest
- **Setup:** `require_relative '../lib/dmud'`
- **Input:** `defined?(MobileObject)`, `defined?(MovableObject)`
- **Expected:** `MobileObject` is defined; `MovableObject` is not.
  Derivation: AC line verbatim.

### TC-1502-008 — gemspec runtime dependency on `reline`
- **Covers:** #20 AC "declares runtime dependency `reline`"
- **Type:** automated minitest
- **Setup:** load `dmud.gemspec`
- **Input:** `spec.runtime_dependencies.map(&:name)`
- **Expected:** includes `"reline"`. Derivation: AC line verbatim.

### TC-1502-009 — gemspec development dependencies `minitest` + `rake`
- **Covers:** #20 AC "development dependencies `minitest` and `rake`"
- **Type:** automated minitest
- **Setup:** load `dmud.gemspec`
- **Input:** `spec.development_dependencies.map(&:name)`
- **Expected:** includes both `"minitest"` and `"rake"`. Derivation: AC
  line verbatim.

### TC-1502-010 — Gemfile contains only the source line and `gemspec`
- **Covers:** #21 AC "The Gemfile contains only the source line and gemspec"
- **Type:** automated minitest
- **Setup:** read `Gemfile`
- **Input:** strip comments/blank lines
- **Expected:** remaining lines are exactly one `source "https://rubygems.org"`
  (or equivalent) line and one `gemspec` line — no additional `gem`
  declarations. Derivation: AC line verbatim.

### TC-1502-011 — example world lives under `examples/` and uses `require 'dmud'`
- **Covers:** #20 AC "example world moves to examples/, using require 'dmud'"
- **Type:** automated minitest
- **Setup:** `Dir.glob('examples/*.rb')`
- **Input:** file contents of the example script(s)
- **Expected:** at least one file exists under `examples/`; it contains
  `require 'dmud'` (gem-style require, **not** `require_relative`).
  Derivation: AC line verbatim.

### TC-1502-012 — no stray world-builder script left at repo root (RULING #8)
- **Covers:** #20 gem layout
- **Type:** automated minitest
- **Setup:** none
- **Input:** `File.exist?('test_game.rb')`
- **Expected:** false. Derivation: **RULING #8**, same as TC-1502-006 —
  the example "moves" to `examples/`, it is not copied and left behind.

### TC-1502-013 — the example world runs locally via `-Ilib` without installing the gem
- **Covers:** #20 (dev-loop sanity, not explicitly required by AC but a
  natural precondition for every other example-world test in this doc)
- **Type:** automated minitest (subprocess, ~30s timeout — see Conventions)
- **Setup:** spawn `ruby -Ilib examples/<file>.rb` from the repo root with
  canned stdin (`"move foyer\n"` then EOF)
- **Input:** n/a
- **Expected:** process starts, prints a `"Location: Foyer"` line, exits 0
  on EOF (full EOF-handling assertions are in section G; this test only
  confirms the example *loads and runs* under `-Ilib`). Derivation:
  implied by "example world ... uses require 'dmud'" needing a working
  load path in dev before the gem is installed; the `"Location:"`-line
  assertion follows the bare-area-name ban in Conventions (defect A).

### TC-1502-014 — `Item`/`NPC`/`MOB` are reachable via `require 'dmud'`
- **Covers:** #20 gem layout completeness
- **Type:** automated minitest
- **Setup:** `require_relative '../lib/dmud'`
- **Input:** `defined?(Item)`, `defined?(NPC)`, `defined?(MOB)`
- **Expected:** all three defined. Derivation: the gem must expose the same
  public API the flat-file version did; nothing in the AC says to drop
  these classes.

### TC-1502-015 — loading `dmud` twice is idempotent
- **Covers:** #20 (boundary / require hygiene)
- **Type:** automated minitest
- **Setup:** `require_relative '../lib/dmud'` twice in the same process
- **Input:** n/a
- **Expected:** no `warning: already initialized constant` noise, no
  re-definition error; second `require_relative` call simply returns
  `false`. Derivation: standard Ruby `require`/`require_relative`
  semantics, unchanged by this batch — a regression guard, not a new
  behavior.

---

## C. `require_relative` / working-directory independence (#8)

### TC-1502-016 — no `require './...'` left in `lib/`
- **Covers:** #8, AC "require_relative is used throughout (#8)"
- **Type:** automated minitest (static scan)
- **Setup:** read every file under `lib/`
- **Input:** n/a
- **Expected:** no line matches `/require\s+['"]\.\//`. Derivation: #8's
  suggested fix ("Use `require_relative 'dmud'`") generalized to every
  internal require, per the AC.

### TC-1502-017 — `lib/dmud.rb` is loadable from any working directory
- **Covers:** #8 "Steps to reproduce: `cd /tmp && ruby /path/to/dmud/...`"
- **Type:** automated minitest (subprocess)
- **Setup:** spawn `ruby -e "require_relative '<abs path to lib/dmud.rb>'; puts 'OK'"`
  with `Dir.chdir`'d to a scratch tmpdir first, i.e. `cwd` is **not**
  inside the repo
- **Input:** n/a
- **Expected:** exits 0, prints `OK`, no `LoadError`. Derivation: #8's
  exact repro scenario, inverted to confirm the fix.

### TC-1502-018 — the example script does not re-require the class files individually
- **Covers:** #8 "test_game.rb also re-requires the class files that
  dmud.rb already loads, so those lines can be dropped"
- **Type:** automated minitest (static scan)
- **Setup:** read the example script under `examples/`
- **Input:** n/a
- **Expected:** contains exactly one `require 'dmud'` and no additional
  `require`/`require_relative` lines for individual class files.
  Derivation: #8 suggested-fix line, repeated as part of #21's AC bullet.

### TC-1502-019 — `securerandom` stays a plain stdlib require, not a gem dependency
- **Covers:** #20/#8 boundary (what counts as "a dependency")
- **Type:** automated minitest
- **Setup:** load `dmud.gemspec`
- **Input:** `spec.runtime_dependencies.map(&:name)`
- **Expected:** does **not** include `"securerandom"` (it's always-available
  stdlib on the pinned Ruby floor, unlike `reline`, which the AC
  explicitly explains is a *bundled*, not default, gem on 3.4+/4.0).
  Derivation: AC's "Why reline is declared" paragraph, by contrast.

---

## D. Object construction (#1, plus unchanged construction behavior)

All tests in this section use the Test Fixture World convention above.

### TC-1502-020 — `DMUDObject#id` is a UUID-shaped string
- **Covers:** Unchanged (`DMUDObject`, not touched by #21)
- **Type:** automated minitest
- **Setup:** `DMUDObject.new`
- **Input:** `.id`
- **Expected:** matches `/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/`.
  Derivation: ARCHITECTURE.md "sets `@id` to `SecureRandom.uuid`".

### TC-1502-021 — `DMUDObject#id` is unique per instance (edge)
- **Covers:** Unchanged
- **Type:** automated minitest
- **Setup:** two `DMUDObject.new` instances
- **Input:** compare `.id`
- **Expected:** not equal. Derivation: same as above, uniqueness is implied
  by "random UUID."

### TC-1502-022 — `Region.new` defaults and `add_area` duplicate behavior (unchanged)
- **Covers:** Unchanged (#11/#17 out of scope — not touching this)
- **Type:** automated minitest
- **Setup:** `r = Region.new`; `a = Area.new`
- **Input:** `r.metadata[:name]`; call `r.add_area(a)` twice
- **Expected:** default name `'New Region'`; both calls return `true`;
  area is **not** de-duplicated (appears twice internally) — confirms the
  documented "no duplicate check" quirk is untouched. Derivation:
  ARCHITECTURE.md Region section, verbatim ("no duplicate check ... adds it
  twice").

### TC-1502-023 — `Area#gate_lookup` stays case-insensitive (unchanged)
- **Covers:** Unchanged
- **Type:** automated minitest
- **Setup:** Test Fixture World, standing in Foyer
- **Input:** `foyer.gate_lookup("GRAND HALL")`, `foyer.gate_lookup("grand hall")`
- **Expected:** both return the same `Gate` object. Derivation:
  ARCHITECTURE.md "case-insensitively searches ... for a name match."

### TC-1502-024 — `Area#gate_lookup` ignores the hidden/visible flag (unchanged, #13 out of scope)
- **Covers:** Unchanged; relevant confirmation per task instructions since
  it's load-bearing for the hidden-area adversarial-input tests in Section E
- **Type:** automated minitest
- **Setup:** Test Fixture World, standing in Foyer
- **Input:** `foyer.gate_lookup("Secret Room")`
- **Expected:** returns the gate to Secret Room despite that side being
  marked not-visible. Derivation: ARCHITECTURE.md "ignores the gate/area's
  visible flag entirely."

### TC-1502-025 — `MobileObject.new` with both required args (happy path)
- **Covers:** Unchanged base-class behavior
- **Type:** automated minitest
- **Setup:** an `Area`
- **Input:** `MobileObject.new("Thing", area)`
- **Expected:** succeeds; `.metadata[:name] == "Thing"`; `.location == area`;
  `.metadata[:description] == ''` (default). Derivation: unchanged
  constructor signature `initialize(name, location, description = '')`.

### TC-1502-026 — `MobileObject.new` missing `location` (error condition)
- **Covers:** Unchanged
- **Type:** automated minitest
- **Setup:** none
- **Input:** `MobileObject.new("Thing")`
- **Expected:** raises `ArgumentError`. Derivation: `location` has no
  default in the current/unchanged signature.

### TC-1502-027 — `MobileObject.new` with zero args (boundary)
- **Covers:** Unchanged
- **Type:** automated minitest
- **Setup:** none
- **Input:** `MobileObject.new`
- **Expected:** raises `ArgumentError` ("given 0, expected 2..3" shape).
  Derivation: same signature, boundary of required-arg count.

### TC-1502-028 — `Item.new(name, location)` succeeds (fixes #1, happy path)
- **Covers:** #1
- **Type:** automated minitest
- **Setup:** an `Area`
- **Input:** `Item.new("Sword", area)`
- **Expected:** does **not** raise; `.metadata[:name] == "Sword"`;
  `.location == area`. Derivation: #21 AC "Item, NPC and MOB forward
  their constructor arguments, so they can be created"; #1's repro command
  is this exact call.

### TC-1502-029 — `NPC.new(name, location)` succeeds, `@carryable == false`
- **Covers:** #1 + required coverage "@carryable values correct per subclass"
- **Type:** automated minitest
- **Setup:** an `Area`
- **Input:** `npc = NPC.new("Bob", area)`
- **Expected:** does not raise; `npc.instance_variable_get(:@carryable) == false`.
  Derivation: #1 AC + unchanged subclass body `@carryable = false` (only
  the forwarding is being fixed, not the hardcoded value).

### TC-1502-030 — `MOB.new(name, location)` succeeds, `@carryable == false`
- **Covers:** #1 + required coverage
- **Type:** automated minitest
- **Setup:** an `Area`
- **Input:** `mob = MOB.new("Rat", area)`
- **Expected:** does not raise; `@carryable == false`. Derivation: same as
  TC-1502-029, mirrored for `MOB`.

### TC-1502-031 — `Item.new(name, location)` `@carryable == true`
- **Covers:** #1 + required coverage
- **Type:** automated minitest
- **Setup:** an `Area`
- **Input:** `item = Item.new("Sword", area)`
- **Expected:** `@carryable == true`. Derivation: same pattern, `Item`'s
  unchanged body sets `@carryable = true`.

### TC-1502-032 — `Item.new` with description forwards all three args
- **Covers:** #1 (forwarding must cover the optional third arg too)
- **Type:** automated minitest
- **Setup:** an `Area`
- **Input:** `Item.new("Sword", area, "A sharp blade")`
- **Expected:** `.metadata[:description] == "A sharp blade"`. Derivation:
  "forward their constructor arguments" (plural/all), not just the first two.

### TC-1502-033 — `Item.new` missing `location` still raises (error condition, fix doesn't loosen requiredness)
- **Covers:** #1 boundary
- **Type:** automated minitest
- **Setup:** none
- **Input:** `Item.new("Sword")`
- **Expected:** raises `ArgumentError`. Derivation: #1's fix only forwards
  arguments; it doesn't change `MobileObject#initialize`'s own required
  parameters, so the same requiredness propagates.

### TC-1502-034 — `Item.new` with zero args still raises (boundary)
- **Covers:** #1 boundary
- **Type:** automated minitest
- **Setup:** none
- **Input:** `Item.new`
- **Expected:** raises `ArgumentError`. Derivation: same reasoning as
  TC-1502-033; mirrors #1's own second repro line (`Item.new` raising
  "given 0, expected 2..3" pre-fix) — post-fix it should still raise,
  just for the same underlying reason as calling `MobileObject.new` bare.

### TC-1502-035 — `NPC`/`MOB`/`Item` carryable is not constructor-settable
- **Covers:** #1 (confirms the fix is pure forwarding, not a new parameter)
- **Type:** automated minitest
- **Setup:** an `Area`
- **Input:** `Item.new("Sword", area, "desc", true)` (4th positional arg)
- **Expected:** raises `ArgumentError` (too many arguments) — `carryable`
  is not an exposed constructor parameter. Derivation: #1's suggested fix
  (`def initialize(*args); super; @carryable = false; end`) only forwards
  to `MobileObject#initialize`'s existing 3-arg signature; it doesn't add
  a new parameter.

### TC-1502-036 — `Player.new` construction stays unchanged (regression)
- **Covers:** Unchanged (Player already forwarded correctly pre-fix because
  its own `initialize` declares the matching 3 params)
- **Type:** automated minitest
- **Setup:** an `Area`
- **Input:** `Player.new("Leeroy Jenkins", area)`
- **Expected:** succeeds; `@carryable == false`. Derivation:
  ARCHITECTURE.md Player section — this path was never broken, #1 doesn't
  touch it; test exists to catch an accidental regression from refactoring
  `MobileObject`'s subclasses.

---

## E. Command seam — adversarial input matrix (#2, #4)

All tests in this section: Test Fixture World, player standing in **Foyer**
unless noted. Each stubs `Reline.readline` (per RULING #10) to return the
given *Input* once, then calls `player.query` (or `player.command`
directly where the case is purely about dispatch, not line-reading), and
captures everything `Player#message` would have sent plus, where noted,
`$DEBUG`-gated stdout.

**RULING #1 (pinned, replaces the step-3 ASSUMPTION):** input is stripped
of leading/trailing whitespace before matching.

**RULING #2 (pinned, replaces the step-3 ASSUMPTION):** command keywords
are **case-insensitive** — `"MOVE Foyer"` moves the player. Area names
were already case-insensitive via `gate_lookup` (unchanged) and stay that
way; the two are independent code paths, tested independently below.

### TC-1502-037 — empty line → Invalid Command
- **Covers:** #2
- **Type:** automated minitest
- **Input:** `""`
- **Expected:** output is `"Invalid Command"` and nothing else; no command
  is dispatched. Derivation: AC "the `//` placeholder is removed and
  matching stops at the first match, so unknown input shows 'Invalid
  Command'" — an empty string matches none of the real (non-placeholder)
  patterns.

### TC-1502-038 — whitespace-only line → Invalid Command
- **Covers:** #2 + RULING #1
- **Type:** automated minitest
- **Input:** `"   "`
- **Expected:** same as TC-1502-037 — strips to an empty string per
  RULING #1, same result. Derivation: AC line above + RULING #1 (pinned).

### TC-1502-039 — leading/trailing spaces around a valid command still match
- **Covers:** #2/#4 + RULING #1; **vehicle changed per defect B** — see
  TC-1502-050 for why `"move foyer"` specifically is reserved for a
  different, more interesting test
- **Type:** automated minitest
- **Input:** `"  move grand hall  "`
- **Expected:** resolves identically to the unpadded `"move grand hall"`
  (TC-1502-051) — moves the player into Grand Hall. Derivation: RULING #1
  (input is stripped before matching), applied to a two-area move that has
  no other quirks entangled with it (unlike moving to "foyer" while
  already in the Foyer — see defect B / TC-1502-050).

### TC-1502-040 — command keyword is case-insensitive: `"MOVE Foyer"` succeeds (RULING #2)
- **Covers:** #4 + RULING #2 (**replaces the step-3 draft's "Invalid
  Command" expectation, which assumed case-sensitivity**)
- **Type:** automated minitest
- **Setup:** player standing in **Grand Hall** (not Foyer, to keep this
  test isolated from the #13 interaction reserved for TC-1502-050)
- **Input:** `"MOVE Foyer"`
- **Expected:** the player moves into Foyer. Derivation: RULING #2 verbatim
  ("Command keywords are CASE-INSENSITIVE (MOVE Foyer moves you)").

### TC-1502-041 — mixed-case **area name** resolves with a lowercase keyword (isolates the pre-existing, unchanged `gate_lookup` case-insensitivity from RULING #2's new keyword case-insensitivity)
- **Covers:** Unchanged (`gate_lookup`) — kept as a separate test from
  TC-1502-040 so a correct implementation can't accidentally pass one
  check while failing the other (e.g. an implementation that downcases
  the *entire* input line, versus one that case-folds only the matched
  keyword and relies on `gate_lookup`'s own independent `.downcase` for
  the area name)
- **Type:** automated minitest
- **Setup:** player standing in Foyer
- **Input:** `"move GRAND HALL"` (lowercase keyword, uppercase area name)
- **Expected:** moves to Grand Hall. Derivation: TC-1502-023 (unchanged
  `gate_lookup` case-insensitivity on the *area name* specifically).

### TC-1502-042 — `"lookout"` is a prefix collision that must NOT match `:look`
- **Covers:** #4 ("match on word boundaries")
- **Type:** automated minitest
- **Input:** `"lookout"`
- **Expected:** `"Invalid Command"` — a word-boundary pattern for `look`
  requires a boundary immediately after `look`, which `lookout` doesn't
  have (`k` immediately followed by `o`, both word characters).
  Derivation: AC "commands match on word boundaries" — `lookout` is the
  canonical negative case that boundary matching (vs. prefix matching) is
  meant to reject.

### TC-1502-043 — `"items"` is a prefix collision that must NOT match `:inventory`/`:i`
- **Covers:** #4
- **Type:** automated minitest
- **Input:** `"items"`
- **Expected:** `"Invalid Command"`. Derivation: same word-boundary
  reasoning as TC-1502-042, applied to the `i`/`inventory` alternation.

### TC-1502-044 — `"moved"` is a prefix collision that must NOT match `:move`
- **Covers:** #4
- **Type:** automated minitest
- **Input:** `"moved"`
- **Expected:** `"Invalid Command"`. Derivation: same reasoning, applied to
  `move`.

### TC-1502-045 — `"say"` with no text matches `:say` but stays a no-op (#15 out of scope, confirm unchanged)
- **Covers:** #2/#4 (matching) + #15 (dispatch, confirm unchanged)
- **Type:** automated minitest
- **Input:** `"say"`
- **Expected:** no player-visible message printed (confirms #15's no-op
  `:say` dispatch is untouched); with `$DEBUG` on, exactly one `MATCH`
  line for `:say` and zero lines for any placeholder (confirms #2's fix —
  there is no more double-dispatch via `//`). Derivation: AC "commands
  match on word boundaries" (bare `say` now matches, unlike before) +
  #15/#21 "out of scope" list (dispatch behavior for `:say` itself isn't
  being changed) + AC "matching stops at the first match."

### TC-1502-046 — `"m"` alone matches `:move` with a missing target → "Move where?"
- **Covers:** #4
- **Type:** automated minitest
- **Input:** `"m"`
- **Expected:** output is exactly `"Move where?"`. Derivation: AC "`move`
  with no target says 'Move where?'" — `m` is one of `:move`'s configured
  aliases (existing `/^m |^move|.../` alternation), so it's the same case
  with a different alias spelling.

### TC-1502-047 — `"move"` alone (no target) → "Move where?" (boundary, canonical spelling)
- **Covers:** #4
- **Type:** automated minitest
- **Input:** `"move"`
- **Expected:** `"Move where?"`. Derivation: AC line verbatim, canonical
  keyword case of TC-1502-046.

### TC-1502-048 — `"i"` alone matches `:inventory` but stays a no-op (#15 out of scope)
- **Covers:** #4 (matching) + #15 (dispatch, confirm unchanged)
- **Type:** automated minitest
- **Input:** `"i"`
- **Expected:** no player-visible message; with `$DEBUG` on, exactly one
  `MATCH` line for `:inventory`. Derivation: same reasoning as
  TC-1502-045, applied to `:inventory`.

### TC-1502-049 — bare `"look"` now matches `:look` but stays a no-op (#15 out of scope)
- **Covers:** #4 (matching) + #15 (dispatch, confirm unchanged)
- **Type:** automated minitest
- **Input:** `"look"`
- **Expected:** no player-visible message; with `$DEBUG` on, one `MATCH`
  line for `:look`. Derivation: #4's repro ("Actual: No match (look
  vs. ...)") inverted — post-fix it must match — combined with #15 being
  out of scope for dispatch behavior.

### TC-1502-050 — `"move foyer"` while already standing in the Foyer resolves through the entrance gate (defect B fix: pinned exact outcome, confirms #13 unchanged via a new adversarial angle)
- **Covers:** #4 (happy-path matching vehicle) + confirms #13 (out of
  scope, unchanged) — a different angle on the same quirk than
  TC-1502-115
- **Type:** automated minitest
- **Setup:** Test Fixture World, player standing in Foyer. Before issuing
  the command, capture `entrance_gate = foyer.gate_lookup("Foyer")`
  directly (not via the command) and read `entrance_gate.metadata[:name]`
  — per the gate-naming convention above, the test never hard-codes this
  string.
- **Input:** `"move foyer"`
- **Expected:**
  1. `player.location` is the same Foyer `Area` object as before the
     command (the visible destination is unchanged, as a true no-op
     would look).
  2. The traversal's step-through line is exactly
     `"You step through the #{entrance_gate.metadata[:name]}."` —
     i.e. the gate that actually fires is the world's entrance gate, not
     a dedicated Foyer-to-Foyer loop gate (there isn't one in this
     world), because Foyer's own `@gates` list has the entrance gate
     first, and that gate's own `@areas` list happens to include an
     entry literally named "Foyer" (the Foyer itself was added to the
     entrance gate's area list when `foyer.add_gate(game_entrance_gate)`
     ran).
  - Derivation: **Derived from source order** — the example-world script
    attaches the entrance gate to Foyer *before* the Grand-Hall/Stairs/
    Secret-Room gates (read directly from the script's call order, not
    executed), combined with the unchanged `Gate#enter`/`Area#gate_lookup`
    logic documented in `docs/ARCHITECTURE.md`'s "The game-entrance gate"
    section: `Gate#enter`'s `@game_entrance` workaround forces the
    object's source to `@areas[0][:object]` (the Lobby, linked first)
    before resolving a 2-area destination, which lands back on the only
    other area — Foyer. #13 is out of scope, so this mechanism is
    confirmed unchanged, just exercised from a different starting
    command than TC-1502-115's `"move game lobby"`.

### TC-1502-051 — multi-word area name: `"move Grand Hall"`
- **Covers:** required coverage "multi-word area names"
- **Type:** automated minitest
- **Input:** `"move Grand Hall"`
- **Expected:** moves the player to the `Grand Hall` area. Derivation:
  unchanged argument-extraction ("everything after the first space")
  behavior from ARCHITECTURE.md's `:move` description, re-verified post
  word-boundary refactor since the AC doesn't say this extraction changes.

### TC-1502-052 — nonexistent area name: `"move Dungeon"`
- **Covers:** required coverage "area names that don't exist"
- **Type:** automated minitest
- **Input:** `"move Dungeon"`
- **Expected:** `"Area 'Dungeon' not accessible from here."` (exact
  current message text, unchanged). Derivation: `class_player.rb`'s
  existing literal string; #21's AC doesn't ask to change this message.

### TC-1502-053 — hidden-but-reachable area: `"move Secret Room"` from Foyer
- **Covers:** required coverage "hidden-but-reachable area" + confirms
  #13 (out of scope) stays unchanged
- **Type:** automated minitest
- **Input:** `"move Secret Room"`
- **Expected:** succeeds, moves the player into Secret Room, **even though**
  Secret Room never appears in the Foyer's `Exits:` list (verify both
  halves: the move works, and a separate `Exits:` check for Foyer doesn't
  list it). Derivation: TC-1502-024 + ARCHITECTURE.md "This is how
  test_game.rb's Secret Room works."

### TC-1502-054 — unicode in a nonexistent area name doesn't crash and round-trips correctly
- **Covers:** required coverage "unicode input"
- **Type:** automated minitest
- **Input:** `"move Café"`
- **Expected:** no exception/encoding error; message is
  `"Area 'Café' not accessible from here."` with the `é` preserved
  correctly (byte-for-byte UTF-8 round trip). Derivation: extrapolated
  from TC-1502-052's unchanged message format, exercised with non-ASCII
  input to confirm the string handling doesn't mangle multibyte characters
  — not an explicit AC requirement, but required by the task's adversarial
  coverage list.

### TC-1502-055 — unicode non-command line doesn't crash
- **Covers:** required coverage "unicode input"
- **Type:** automated minitest
- **Input:** `"你好"` (no ASCII command keyword present at all)
- **Expected:** `"Invalid Command"`, no exception. Derivation: same
  reasoning as #2's fix (no pattern matches) applied to a non-ASCII input;
  also a safety check that word-boundary regexes (`\b`) don't misbehave or
  raise on multibyte UTF-8 strings.

### TC-1502-056 — emoji-only line doesn't crash
- **Covers:** required coverage "unicode input" (boundary: non-letter
  Unicode, not just non-Latin letters)
- **Type:** automated minitest
- **Input:** `"🎮"`
- **Expected:** `"Invalid Command"`, no exception. Derivation: same as
  TC-1502-055, using a codepoint outside any Unicode "word character"
  category to probe `\b` boundary edge behavior specifically.

### TC-1502-057 — unmatched input never dispatches more than once (stops-at-first-match, single-entry case)
- **Covers:** #2 AC "the `//` placeholder is removed and matching stops at
  the first match"
- **Type:** automated minitest
- **Setup:** `$DEBUG = true`
- **Input:** `"move foyer"` (matches `:move`, the first entry in the
  command table)
- **Expected:** debug output contains exactly one `MATCH` line (for
  `:move`) and **zero** `No match` lines (because the loop stops before
  reaching `:say`/`:look`/`:inventory`). Derivation: AC line verbatim +
  unchanged hash-insertion order (`:move` is defined first). Note: this
  traversal itself goes through the #13 entrance-gate path exactly as
  TC-1502-050 describes — this test only inspects the `MATCH`/`No match`
  debug lines from the *matching* stage, not the traversal's destination,
  so that interaction doesn't affect its assertions.

### TC-1502-058 — stops-at-first-match across a later entry
- **Covers:** #2 AC, same line, proving the "stop" isn't a no-op for
  non-first matches too
- **Type:** automated minitest
- **Setup:** `$DEBUG = true`
- **Input:** `"say hello"` (matches `:say`, the second entry)
- **Expected:** debug output contains exactly one `No match` line (for
  `:move`, checked and rejected first) followed by exactly one `MATCH`
  line (for `:say`), and **no** lines at all for `:look`/`:inventory`
  (never reached). Derivation: AC line verbatim; this is the strongest
  available test of "stops," since a non-stopping implementation would
  still show `No match` lines for `:look`/`:inventory` after the `:say`
  match.

### TC-1502-059 — unknown single word → Invalid Command, confirmed with `$DEBUG` off too
- **Covers:** #2
- **Type:** automated minitest
- **Input:** `"xyzzy"`
- **Expected:** `"Invalid Command"` with `$DEBUG` both on and off (two
  sub-cases) — confirms the fix doesn't accidentally depend on `$DEBUG`.
  Derivation: AC line verbatim.

### TC-1502-060 — `"say"`'s no-op is truly silent, not silently erroring (error-condition boundary)
- **Covers:** #15 out-of-scope confirmation, phrased as an error-condition
  check per the task's "happy path, edge cases, error conditions,
  boundaries" requirement
- **Type:** automated minitest
- **Input:** `"say"`, `"say  "` (trailing spaces only after the keyword,
  no text)
- **Expected:** neither raises; both produce no visible message. Derivation:
  #15 (out of scope) — `:say`'s `:extended` case has no branch, so it's
  always a no-op regardless of what follows, including nothing/whitespace.

---

## F. Debug-output guard (#3)

### TC-1502-061 — MATCH/No match lines absent with `$DEBUG` off
- **Covers:** #3
- **Type:** automated minitest
- **Setup:** `$DEBUG` false/nil (default); Test Fixture World
- **Input:** a few representative inputs (`"move foyer"`, `"look"`,
  `"xyzzy"`)
- **Expected:** captured stdout contains no `MATCH` and no `No match`
  substrings for any of them. Derivation: #3 AC "Add `if $DEBUG` to those
  ... lines"; #21 AC "MATCH/No match lines ... only print when `$DEBUG`
  is on."

### TC-1502-062 — MATCH/No match lines present with `$DEBUG` on (paired positive case)
- **Covers:** #3 (the other half of the toggle — proves the guard actually
  does something, not just that it's always off)
- **Type:** automated minitest
- **Setup:** `$DEBUG = true`
- **Input:** `"move foyer"`
- **Expected:** captured stdout contains at least one `MATCH` line.
  Derivation: #3/#21 AC, same lines, positive direction.

### TC-1502-063 — per-item `(ID:...)` suffix in contents listing absent with `$DEBUG` off
- **Covers:** #3
- **Type:** automated minitest
- **Setup:** `$DEBUG` off; an `Area` containing one `Player`
- **Input:** `area.describe`
- **Expected:** the contents line for the player is `"  * <name>"` with
  **no** `(ID:...)` suffix. Derivation: #3 AC "the per-item `(ID:...)`
  suffix ... print unconditionally [bug]"; #21 AC "object IDs in contents
  lists only print when `$DEBUG` is on" (fix direction).

### TC-1502-064 — per-item `(ID:...)` suffix present with `$DEBUG` on (paired positive case)
- **Covers:** #3
- **Type:** automated minitest
- **Setup:** `$DEBUG = true`; same fixture as TC-1502-063
- **Input:** `area.describe`
- **Expected:** the contents line includes `" (ID:<the player's actual
  id>)"`. Derivation: same AC line, positive direction.

### TC-1502-065 — Area's own `(ID:...)` line stays correctly `$DEBUG`-gated (regression, already-correct behavior)
- **Covers:** Unchanged
- **Type:** automated minitest
- **Setup:** `$DEBUG` off, then on
- **Input:** `area.describe` each time
- **Expected:** off → no `(ID:...)` after `"Location: <name>"`; on → present.
  Derivation: ARCHITECTURE.md — this one line was already correctly
  guarded pre-#21; the test exists to catch an accidental regression
  while the surrounding method is touched for the #7/#3 fixes.

### TC-1502-066 — `Area#initialize`'s "Initialized" debug line stays correctly gated (regression)
- **Covers:** Unchanged
- **Type:** automated minitest
- **Setup:** `$DEBUG` off, then on
- **Input:** `Area.new(name: "X")` (positional, per #11 — out of scope)
- **Expected:** off → no `"Area 'X' (ID:...) Initialized"` line printed;
  on → printed. Derivation: ARCHITECTURE.md, same "already correct, guard
  against regression" rationale as TC-1502-065.

---

## G. Exit handling — EOF and Ctrl-C, with/without `$DEBUG` (#5 + its scope-extension comment)

All tests below are real subprocess (E2E) tests: spawn `ruby [-d]
-Ilib examples/<file>.rb` (~30s timeout — see Conventions), feed it one
valid command first (`"move foyer\n"`) to reach a stable mid-game state,
then trigger the exit condition, and inspect the child's stdout/stderr and
exit status after it terminates.

**RULING #6 (pinned, replaces every step-3 `/goodbye/i` assertion):** the
goodbye text is exactly `"Farewell, Leeroy Jenkins."` (player name per the
Conventions section's player-name convention). Every test below that
checks for a goodbye message now asserts this exact literal string, not a
case-insensitive pattern match.

**RULING #3 (pinned, replaces the step-3 ASSUMPTION about "the exception"
for EOF):**
- **EOF:** the exit reason is the literal text `"EOF (end of input)"`,
  followed by a backtrace from the call site (i.e. Ruby's `caller`, not an
  exception's `.backtrace` — there is no exception object for EOF), then
  session/player state.
- **Ctrl-C:** prints the `Interrupt` exception (its class name/message),
  its own `.backtrace`, and the same session/player state.
- Both end with the pinned goodbye line, printed *after* the debug dump,
  per the #5 comment's "the game ... prints its debug info first ... and
  then exits cleanly."

### TC-1502-067 — EOF, `$DEBUG` off: exit 0 + exact goodbye, no stack trace
- **Covers:** #5 + scope-extension comment + RULING #6
- **Type:** automated minitest (subprocess, ~30s timeout)
- **Setup:** spawn without `-d`; send `"move foyer\n"`, then close stdin
  (EOF)
- **Input:** n/a
- **Expected:** process exit status `0`; stdout's final message line is
  exactly `"Farewell, Leeroy Jenkins."`; stdout+stderr contain no Ruby
  exception class name, no `.rb:\d+:in`-style backtrace frames, no object
  UUIDs beyond what normal (non-debug) play already prints. Derivation:
  comment on #5, "print a short goodbye and exit with status 0," plus
  RULING #6's exact text.

### TC-1502-068 — EOF, `$DEBUG` on: exit 0 + pinned debug dump + exact goodbye
- **Covers:** #5 + scope-extension comment + RULING #3 + RULING #6
- **Type:** automated minitest (subprocess, ~30s timeout)
- **Setup:** spawn with `-d` (or equivalent `$DEBUG=1`); same input as
  TC-1502-067
- **Input:** n/a
- **Expected:** exit status `0`; output contains, **in this order**: the
  literal text `"EOF (end of input)"`; at least one backtrace-shaped line
  (matches `/\.rb:\d+/`, sourced from `caller` per RULING #3 — no
  exception object exists for this path); session/player identifying
  state (the player's name `"Leeroy Jenkins"` and/or the default session
  name `"My Session"`); and finally the exact line `"Farewell, Leeroy
  Jenkins."` after all of the above. Derivation: RULING #3 (pinned
  verbatim) + comment on #5 ("prints its debug info first ... and then
  exits cleanly").

### TC-1502-069 — Ctrl-C (SIGINT), `$DEBUG` off: exit 0 + exact goodbye, no stack trace
- **Covers:** #5 scope-extension comment + RULING #6
- **Type:** automated minitest (subprocess, ~30s timeout)
- **Setup:** spawn without `-d`; send `"move foyer\n"`, then send
  `SIGINT` to the child process while it's blocked on the next prompt
- **Input:** n/a
- **Expected:** exit status `0`; stdout's final message line is exactly
  `"Farewell, Leeroy Jenkins."`; no `Interrupt` exception name or
  backtrace visible anywhere in captured output. Derivation: comment on
  #5, "Ctrl-C (Interrupt) at the prompt should also exit cleanly instead
  of dumping a stack trace," plus RULING #6.

### TC-1502-070 — Ctrl-C (SIGINT), `$DEBUG` on: exit 0 + pinned debug dump + exact goodbye
- **Covers:** #5 scope-extension comment + RULING #3 + RULING #6
- **Type:** automated minitest (subprocess, ~30s timeout)
- **Setup:** spawn with `-d`; same trigger as TC-1502-069
- **Input:** n/a
- **Expected:** exit status `0`; output contains, **in this order**: the
  `Interrupt` exception's class name (i.e. the substring `"Interrupt"`);
  a real exception backtrace (`/\.rb:\d+/`-shaped lines, this time sourced
  from `Interrupt#backtrace` per RULING #3 — this is the unambiguous half,
  a genuine rescued exception); session/player state; and finally
  `"Farewell, Leeroy Jenkins."`. Derivation: RULING #3, literal wording.

### TC-1502-071 — EOF as the very first input (boundary: before any room is entered)
- **Covers:** #5 boundary + RULING #6
- **Type:** automated minitest (subprocess, ~30s timeout)
- **Setup:** spawn without `-d`; close stdin immediately, no prior command
- **Input:** n/a
- **Expected:** exit status `0`, exact `"Farewell, Leeroy Jenkins."`, no
  crash — confirms the fix doesn't depend on having played at least one
  turn first. Derivation: comment on #5 doesn't scope the fix to "after
  the first command," so the earliest possible EOF must behave the same;
  RULING #6 for the exact text.

### TC-1502-072 — Ctrl-C as the very first input (boundary)
- **Covers:** #5 boundary + RULING #6
- **Type:** automated minitest (subprocess, ~30s timeout)
- **Setup:** spawn without `-d`; send `SIGINT` immediately, no prior
  command
- **Input:** n/a
- **Expected:** same as TC-1502-071, mirrored for Ctrl-C. Derivation: same
  reasoning.

### TC-1502-073 — EOF and Ctrl-C produce the exact same goodbye string (no longer a soft assumption)
- **Covers:** #5 scope-extension comment + RULING #6
- **Type:** automated minitest (subprocess, ~30s timeout)
- **Setup:** two runs of TC-1502-067 and TC-1502-069's setups
- **Input:** n/a
- **Expected:** both runs' final message line is the identical literal
  string `"Farewell, Leeroy Jenkins."` — this is now a hard, pinned
  equality check, not a pattern-match comparison. Derivation: RULING #6
  gives one fixed format string parameterized only by player name, and
  both paths use the same fixture player name, so they must be byte-equal.

### TC-1502-074 — `$DEBUG`-off exit paths produce none of the pinned debug-dump markers (negative, paired against 068/070)
- **Covers:** #5 + #21 AC "debug dump content only when $DEBUG" + RULING #3
- **Type:** automated minitest (subprocess, ~30s timeout)
- **Setup:** reuse TC-1502-067 and TC-1502-069 output
- **Input:** n/a
- **Expected:** neither contains `"EOF (end of input)"`, the substring
  `"Interrupt"`, any `/\.rb:\d+/`-shaped backtrace line, or the session/
  player state markers asserted present in TC-1502-068/070. Derivation:
  #21 AC line, negative direction, now checked against the exact pinned
  markers from RULING #3 instead of loosely-described content.

### TC-1502-075 — EOF and Ctrl-C both leave no zombie/orphan process (operational boundary)
- **Covers:** general process-hygiene sanity for the subprocess test
  harness itself, not a specific AC line
- **Type:** manual check
- **Setup:** TC-1502-067–070's harness
- **Input:** n/a
- **Expected:** child process is reaped (no defunct process left behind)
  after each test. Derivation: not from the AC — a test-infrastructure
  sanity check; marked manual since it's about the test harness, not
  DMUD's behavior, and not worth automating into `rake test` assertions.

### TC-1502-076 — a second SIGINT during the goodbye/debug-dump window doesn't hang or double-exit
- **Covers:** #5 edge case not explicitly covered by the AC or the step-4
  rulings
- **Type:** manual check
- **Setup:** send `SIGINT` once, then immediately send it again before the
  process has fully exited
- **Input:** n/a
- **Expected:** process still exits with status `0` (or, acceptably, a
  signal-death status if the second SIGINT interrupts cleanup — neither
  the AC nor the step-4 rulings say anything about this case). Derivation:
  none — still an open gap after step 4; kept manual/exploratory rather
  than given a pinned automated expectation, since asserting a specific
  exit status here would be inventing a requirement nobody has stated.

---

## H. Prompt format (#6)

### TC-1502-077 — no literal backslash-n text anywhere in one turn's output
- **Covers:** #6
- **Type:** automated minitest (subprocess, raw byte capture)
- **Setup:** spawn the example world, send one command, capture raw stdout
  bytes (do **not** split on newlines first)
- **Input:** `"move foyer\n"`
- **Expected:** the two-character sequence `\\n` (backslash, lowercase n)
  does **not** appear anywhere in the captured bytes. Derivation: #21 AC
  "No literal `\n`."; #6 "a literal backslash-n shows up in the output."

### TC-1502-078 — the prompt line itself is single-line text
- **Covers:** #6
- **Type:** automated minitest (subprocess)
- **Setup:** same as TC-1502-077; split captured output on real newline
  bytes (`\n`, 0x0A)
- **Input:** n/a
- **Expected:** the line containing `"Command>"` is exactly
  `"Leeroy Jenkins: Command> "` (per the player-name convention) with
  nothing else embedded in that same line. Derivation: #21 AC "the prompt
  is a single line, with the blank line printed separately" + the
  Conventions section's player-name convention.

### TC-1502-079 — the blank line before the prompt is a separate, real newline
- **Covers:** #6
- **Type:** automated minitest (subprocess)
- **Setup:** same capture as above
- **Input:** n/a
- **Expected:** there is a real blank line (two consecutive `\n` bytes)
  immediately preceding the `"Command>"` line, produced as its own output
  event rather than embedded in the prompt string. Derivation: #21 AC "the
  blank line printed separately" (i.e. via its own `puts`, not baked into
  the prompt format string).

### TC-1502-080 — the prompt is drawn once per turn on a non-interactive pipe (weak form)
- **Covers:** #6 (partial — see TC-1502-081 for the full repro)
- **Type:** automated minitest (subprocess)
- **Setup:** same capture
- **Input:** n/a
- **Expected:** exactly one occurrence of `"Command>"` in the captured
  output for the single turn tested. Derivation: #6 "the prompt is drawn
  multiple times per turn" (bug) — this is the easy, pipe-capturable half
  of confirming the fix; it doesn't require a real TTY.

### TC-1502-081 — the prompt does not visibly redraw on a real terminal
- **Covers:** #6 full repro ("originally reported ... reproduced here on
  Ruby 4.0.5 by running test_game.rb with piped input")
- **Type:** manual check
- **Setup:** run the example world attached to a real PTY (e.g. via
  `script(1)` or a terminal emulator), type a command by hand
- **Input:** a command typed interactively
- **Expected:** the prompt appears once, cleanly, with no repeated/garbled
  redraw. Derivation: #6's repro note explicitly says the original bug
  was reported from a real terminal session; TC-1502-080's piped-only
  check can't fully rule out TTY-specific Reline redraw quirks, so this is
  kept as a manual check rather than asserted automatically.

---

## I. Traversal output order (#7)

**RULING #7 (pinned, fully replaces the step-3 draft's partial ordering):**
the complete, pinned traversal sequence is:

1. clear-screen/cursor-home codes (`\033[2J\033[H`)
2. **[$DEBUG only]** the "You have entered the '...' Gate" line
3. `gate_specific` output
4. `"You step through the <gate name>."`
5. **[$DEBUG only]** the "You have exited the '...' Gate" line
6. the new area's description (`"Location: <name>"` and the rest of
   `Area#describe`)

Tests in this section use a dedicated `class TestGate < Gate` defined only
inside the test file, overriding `gate_specific` to emit one identifiable
marker (e.g. calling `@object.message("TOLL: a toll troll demands
payment.")`), wired between two areas and given its own test-chosen name
(e.g. `"Toll Gate"`) — never a name borrowed from the real example world
(per the gate-naming convention in Conventions, defect C).

### TC-1502-082 — full pinned ordering, `$DEBUG` off (4 elements)
- **Covers:** #7
- **Type:** automated minitest
- **Setup:** $DEBUG off; traverse the `TestGate` (named `"Toll Gate"`)
- **Input:** the move command that crosses it
- **Expected:** the four $DEBUG-independent elements appear in this exact
  relative order: clear-screen sequence, then `"TOLL: a toll troll demands
  payment."`, then `"You step through the Toll Gate."`, then
  `"Location: <destination area name>"`. Derivation: RULING #7, items 1,
  3, 4, 6 (items 2 and 5 are absent since $DEBUG is off).

### TC-1502-083 — full pinned ordering, `$DEBUG` on (6 elements)
- **Covers:** #7 — this is the direct, central test of RULING #7
- **Type:** automated minitest
- **Setup:** $DEBUG on; same `TestGate` traversal
- **Input:** n/a
- **Expected:** all six elements appear, strictly in RULING #7's order:
  clear-screen sequence; `"You have entered the 'Toll Gate' Gate"`;
  `"TOLL: a toll troll demands payment."`; `"You step through the Toll
  Gate."`; `"You have exited the 'Toll Gate' Gate"`; `"Location: <destination
  area name>"`. Derivation: RULING #7, all six items, in the pinned order.

### TC-1502-084 — step-through line's literal content
- **Covers:** #7
- **Type:** automated minitest
- **Setup:** same `TestGate` traversal (any $DEBUG setting)
- **Input:** n/a
- **Expected:** the line is exactly `"You step through the Toll Gate."`
  (gate name substituted exactly, matching the name the test itself gave
  the `TestGate`). Derivation: #21 AC quoted verbatim: "the non-debug line
  'You step through the <gate name>.' prints."

### TC-1502-085 — entered/exited Gate lines: present with pinned wording under $DEBUG, absent without it
- **Covers:** #7
- **Type:** automated minitest
- **Setup:** two sub-cases: $DEBUG off and $DEBUG on, same `TestGate`
  traversal
- **Input:** n/a
- **Expected:** off → neither `"You have entered the 'Toll Gate' Gate"` nor
  `"You have exited the 'Toll Gate' Gate"` appears anywhere in output; on →
  both appear, with exactly that wording (unchanged from today's literal
  strings — only their $DEBUG guard and position are new) and in the
  relative positions pinned by RULING #7 (entered before `gate_specific`,
  exited after the step-through line). Derivation: #21 AC "entered/exited
  lines only under $DEBUG" + RULING #7's exact slot numbers 2 and 5.

### TC-1502-086 — a one-area (loop) gate traversal: pinned order holds; the pre-existing loop message is an explicitly open gap
- **Covers:** #7 edge case, combined with the pre-existing one-area-gate
  behavior described in ARCHITECTURE.md
- **Type:** automated minitest
- **Setup:** a second `TestGate` (named e.g. `"Spinning Door"`) with only
  one `Area` linked (the loop case); $DEBUG off
- **Input:** the move command that traverses it
- **Expected:** no crash; clear-screen still precedes
  `"You step through the Spinning Door."`, which still precedes the
  (same) area's re-description. The test does **not** assert whether the
  existing "This Gate seems to only return to the Area you're leaving..."
  response text still prints, and if so, where — **step 4's rulings did
  not address this pre-existing one-area-specific message**, so it
  remains an open gap, called out again in the report rather than
  silently guessed at. Derivation: ARCHITECTURE.md's documented one-area
  case + RULING #7 (silent on this specific message).

### TC-1502-087 — the Secret Room's hidden-side gate: pinned order holds on a real fixture gate, not just `TestGate`
- **Covers:** #7 + required coverage overlap (hidden area) + gate-naming
  convention (defect C)
- **Type:** automated minitest
- **Setup:** $DEBUG off; traverse from Foyer into Secret Room (the real
  fixture gate with a hidden side, not a `TestGate` — confirms the
  ordering fix isn't specific to the subclass-with-`gate_specific` case).
  Capture `gate = foyer.gate_lookup("Secret Room")` and read
  `gate.metadata[:name]` before issuing the command, per the gate-naming
  convention — never hard-code this gate's name.
- **Input:** `"move secret room"`
- **Expected:** same clear-before-step-through-before-area ordering holds,
  with the step-through line reading
  `"You step through the #{gate.metadata[:name]}."` and no custom
  `gate_specific` text (base `Gate#gate_specific` is still a no-op).
  Derivation: RULING #7 applies to traversal generally, not just gates
  with custom `gate_specific` hooks; gate name read dynamically per the
  Conventions section.

### TC-1502-088 — ordinary two-sided gate (Foyer↔Grand Hall), `gate_specific` is the default no-op: pinned order still holds
- **Covers:** #7 — confirms the ordering fix applies to the everyday case,
  not only to a gate with a custom `gate_specific` override
- **Type:** automated minitest
- **Setup:** $DEBUG off; traverse the real Foyer↔Grand Hall fixture gate;
  capture its name the same way as TC-1502-087
- **Input:** `"move grand hall"`
- **Expected:** clear-screen precedes the step-through line, which
  precedes `"Location: Grand Hall"`; no `gate_specific` text appears
  anywhere (nothing to assert there, since the default hook is a no-op).
  Derivation: RULING #7, same ordering, applied to the base (non-subclass)
  `Gate#gate_specific`.

### TC-1502-089 — $DEBUG traversal lines for a real fixture gate include its connection info (cross-reference to Section J)
- **Covers:** #21 AC "the $DEBUG traversal lines include them" (Gate's
  `to_s`/`inspect`/`connection_label`)
- **Type:** automated minitest
- **Setup:** $DEBUG on; traverse the real Foyer↔Grand Hall fixture gate
- **Input:** n/a
- **Expected:** the entered/exited $DEBUG lines from TC-1502-085 contain
  the gate's pinned `connection_label` value (see TC-1502-090,
  `"Foyer <> Grand Hall"`) rather than just the bare gate name. Derivation:
  AC line verbatim, now checkable against RULING #4's exact format.

---

## J. `Gate#connection_label` / `#to_s` / `#inspect`

**RULING #4 (pinned, replaces the step-3 ASSUMPTIONs about hidden-side
marking and the 1-area/0-area formats):**
- two visible sides: `"Foyer <> Grand Hall"`
- a hidden side gets the suffix `" (hidden)"`, e.g.
  `"Foyer <> Secret Room (hidden)"`
- a 1-area gate: `"Foyer (loop)"`
- a 0-area gate: `"(no areas)"`
- area order follows `@areas` order (the order they were added, not
  alphabetical or any other sort)

**RULING #5 (pinned, replaces the step-3 ASSUMPTION that `to_s`/`inspect`
could be identical):**
- `Gate#to_s` is `"<name> [<connection_label>]"`
- `Gate#inspect` is `"#<Gate id=<uuid> name=<name> connections=<connection_label>>"`
- these are two different, fully pinned formats.

All tests in this section build their own gate(s) in-test (per the
gate-naming convention in Conventions) rather than assuming a specific
name for a real example-world gate.

### TC-1502-090 — `connection_label` for a plain two-sided visible gate
- **Covers:** RULING #4, first bullet (also the one case the original AC
  gave a literal example for)
- **Type:** automated minitest
- **Setup:** `gate = Gate.new("Test Gate")`; `foyer_like = Area.new(name: "Foyer")`;
  `other = Area.new(name: "Grand Hall")`; `foyer_like.add_gate(gate)`;
  `other.add_gate(gate)` (both sides visible, added in that order)
- **Input:** `gate.connection_label`
- **Expected:** exactly `"Foyer <> Grand Hall"`. Derivation: RULING #4,
  first bullet, verbatim.

### TC-1502-091 — `connection_label` marks a hidden side with `" (hidden)"`
- **Covers:** RULING #4, second bullet
- **Type:** automated minitest
- **Setup:** `gate = Gate.new("Test Gate")`; `foyer_like = Area.new(name: "Foyer")`;
  `secret = Area.new(name: "Secret Room")`; `foyer_like.add_gate(gate)`
  (visible, default); `secret.add_gate(gate, false)` (hidden side, added
  second)
- **Input:** `gate.connection_label`
- **Expected:** exactly `"Foyer <> Secret Room (hidden)"`. Derivation:
  RULING #4, second bullet, verbatim, with area order matching
  `@areas` insertion order (Foyer added first, so it comes first in the
  label; the *second*, hidden, area gets the suffix).

### TC-1502-092 — `connection_label` for a one-area (loop) gate
- **Covers:** RULING #4, third bullet
- **Type:** automated minitest
- **Setup:** `gate = Gate.new("Test Gate")`; `foyer_like = Area.new(name: "Foyer")`;
  `foyer_like.add_gate(gate)` (only one area ever added)
- **Input:** `gate.connection_label`
- **Expected:** exactly `"Foyer (loop)"`. Derivation: RULING #4, third
  bullet, verbatim.

### TC-1502-093 — `connection_label` for a zero-area gate
- **Covers:** RULING #4, fourth bullet
- **Type:** automated minitest
- **Setup:** `Gate.new("Test Gate")` with no `add_area`/`add_gate` calls
  at all
- **Input:** `gate.connection_label`
- **Expected:** exactly `"(no areas)"`. Derivation: RULING #4, fourth
  bullet, verbatim.

### TC-1502-094 — `connection_label` updates when a second area is added later (proves derived, not stored)
- **Covers:** required coverage "a label that updates when an area is
  added later (proves derived, not stored)" + RULING #4 (now checkable
  with exact pinned strings on both sides of the change)
- **Type:** automated minitest
- **Setup:** `gate = Gate.new("Test Gate")`; `area_a = Area.new(name: "A")`;
  `area_a.add_gate(gate)`
- **Input:** capture `label1 = gate.connection_label`; then
  `area_b = Area.new(name: "B")`; `area_b.add_gate(gate)`; capture
  `label2 = gate.connection_label`
- **Expected:** `label1` is exactly `"A (loop)"` (RULING #4, third
  bullet); `label2` is exactly `"A <> B"` (RULING #4, first bullet,
  applied to these area names). Derivation: required-coverage line +
  RULING #4, both sides of the comparison now pinned exactly rather than
  just asserted-different.

### TC-1502-095 — `Gate#to_s` format
- **Covers:** RULING #5, first bullet
- **Type:** automated minitest
- **Setup:** same gate as TC-1502-090 (`"Test Gate"` linking `"Foyer"`
  and `"Grand Hall"`)
- **Input:** `gate.to_s`
- **Expected:** exactly `"Test Gate [Foyer <> Grand Hall]"`. Derivation:
  RULING #5, first bullet, verbatim, composed with TC-1502-090's pinned
  `connection_label`.

### TC-1502-096 — `Gate#inspect` format
- **Covers:** RULING #5, second bullet
- **Type:** automated minitest
- **Setup:** same gate
- **Input:** `gate.inspect`
- **Expected:** exactly `"#<Gate id=#{gate.id} name=Test Gate connections=Foyer <> Grand Hall>"`.
  Derivation: RULING #5, second bullet, verbatim, composed with the
  gate's real `id` and TC-1502-090's pinned `connection_label`.

### TC-1502-097 — `$DEBUG` traversal lines include the gate's connection info (cross-referenced from TC-1502-089)
- **Covers:** #21 AC "the $DEBUG traversal lines include them"
- **Type:** automated minitest
- **Setup:** see TC-1502-089
- **Input:** n/a
- **Expected:** see TC-1502-089 — listed here for completeness of this
  section's AC-line coverage, not as a duplicate test.

### TC-1502-098 — `connection_label`/`to_s`/`inspect` are read-only derivations (no setter side effects)
- **Covers:** RULING #4/#5 "derived" framing, same spirit as TC-1502-094,
  checked from the opposite direction
- **Type:** automated minitest
- **Setup:** same gate as TC-1502-090
- **Input:** call `gate.connection_label` twice in a row with no state
  change in between
- **Expected:** both calls return the exact same pinned string
  `"Foyer <> Grand Hall"` (idempotent, a pure function of current
  `@areas` — not e.g. appending to some memoized array each call).
  Derivation: "derived, not stored" implies recomputation, not
  incremental mutation, now checked against RULING #4's exact string
  rather than a loose equality check.

---

## K. Style (#9)

**RULING #9 (pinned, extends scope beyond the step-3 draft's `lib/`-only
check):** tabs only, under `lib/`, `examples/`, **and** `test/`.

### TC-1502-099 — no leading-space indentation anywhere under `lib/`, `examples/`, or `test/` (tabs-only)
- **Covers:** #9 + required coverage "no mixed tab/space indentation in
  lib/ (a test or check that scans files)" + RULING #9's expanded scope
- **Type:** automated minitest (static scan)
- **Setup:** read every `.rb` file under `lib/`, `examples/`, and
  `test/`
- **Input:** every line's leading-whitespace run
- **Expected:** every leading-whitespace run matches `/\A\t*\z/` (tabs
  only, never a space character anywhere in the indentation, and never a
  mix), in all three directories. Derivation: RULING #9, verbatim,
  replacing the step-3 draft's `lib/`-only ASSUMPTION.

### TC-1502-100 — `.editorconfig` exists at the repo root
- **Covers:** #21 AC "an `.editorconfig`" + required coverage
- **Type:** automated minitest
- **Setup:** none
- **Input:** `File.exist?('.editorconfig')`
- **Expected:** true. Derivation: AC line verbatim.

### TC-1502-101 — `.editorconfig` declares `indent_style = tab` for Ruby files
- **Covers:** #9 + RULING #9
- **Type:** automated minitest (content check)
- **Setup:** read `.editorconfig`
- **Input:** n/a
- **Expected:** a section applicable to `*.rb` (or `[*]`) sets
  `indent_style = tab`. Derivation: RULING #9 pins "tabs only" as the
  chosen style across `lib/`, `examples/`, and `test/`; this test
  confirms the editor-level config agrees, not just the files themselves.

### TC-1502-102 — typo fixes: `"GameOjbects"` is gone
- **Covers:** #9
- **Type:** automated minitest (static grep)
- **Setup:** read every file under `lib/`
- **Input:** n/a
- **Expected:** no file contains the literal string `"GameOjbects"`.
  Derivation: #9 body, listed typo verbatim.

### TC-1502-103 — typo fixes: `"###i"` stray-i comment marker is gone
- **Covers:** #9
- **Type:** automated minitest (static grep)
- **Setup:** read `lib/dmud/dmud_object.rb` (or wherever `DMUDObject`
  lands)
- **Input:** n/a
- **Expected:** the file's header comment block does not contain
  `"###i"`. Derivation: #9 body, "`###i` has a stray 'i'."

### TC-1502-104 — typo fixes: `"organizationsl"` → `"organizational"`
- **Covers:** #9
- **Type:** automated minitest (static grep)
- **Setup:** read `lib/dmud/region.rb`
- **Input:** n/a
- **Expected:** contains `"organizational"`, not `"organizationsl"`.
  Derivation: #9 body, verbatim.

### TC-1502-105 — comment references to a nonexistent "GameObject" class are gone in the Gate file
- **Covers:** #9
- **Type:** automated minitest (static grep)
- **Setup:** read `lib/dmud/gate.rb`
- **Input:** n/a
- **Expected:** no comment text reads literally `"GameObject"` (as
  opposed to `MobileObject` or `GameObjects`, which are both now
  acceptable/expected elsewhere per #9). Derivation: #9 body, "`Gate#enter`
  comments refer to 'GameObject', which isn't a class in the codebase."

### TC-1502-106 — MANUAL: every new or changed method has a header comment
- **Covers:** #21 AC "Every new or changed method has a header comment."
- **Type:** manual check
- **Setup:** code review of the diff
- **Input:** n/a
- **Expected:** reviewer confirms each new/changed public method has a
  preceding comment describing it. Derivation: AC line verbatim; not
  practically automatable without a fragile heuristic (distinguishing
  "changed" from "untouched" methods requires diff context a static
  scanner over the final tree doesn't have), so left as an explicit manual
  gate rather than a flaky automated check.

---

## L. Packaging seam (config → runtime) and dependency accuracy (#8, #20)

### TC-1502-107 — `gem build dmud.gemspec` succeeds
- **Covers:** #20 AC "`gem build` ... work[s] locally"
- **Type:** automated minitest (subprocess)
- **Setup:** run from repo root
- **Input:** `gem build dmud.gemspec`
- **Expected:** exit status `0`; a `dmud-*.gem` file is produced.
  Derivation: AC line verbatim.

### TC-1502-108 — `gem install` into an isolated temp `GEM_HOME` succeeds
- **Covers:** #20 AC "`gem install` work[s] locally"
- **Type:** automated minitest (subprocess)
- **Setup:** the `.gem` from TC-1502-107; a fresh scratch directory as
  `GEM_HOME`
- **Input:** `gem install --install-dir <tmp> <built .gem> --no-document`
- **Expected:** exit status `0`; the gem's files appear under
  `<tmp>/gems/dmud-*/`. Derivation: AC line verbatim; isolated `GEM_HOME`
  used specifically so this test never touches the real system/user gem
  environment (the staging-vs-production discipline, applied to gem
  installs).

### TC-1502-109 — `require 'dmud'` works from a directory outside the repo, using only the installed gem
- **Covers:** #20 AC "`require 'dmud'` works from outside the repo" + #8
- **Type:** automated minitest (subprocess)
- **Setup:** `GEM_HOME`/`GEM_PATH` pointed at TC-1502-108's temp install
  dir; `cwd` set to an unrelated scratch directory (not inside the dmud
  repo at all)
- **Input:** `ruby -e "require 'dmud'; puts DMUDObject.new.id"`
- **Expected:** exit status `0`; stdout is a UUID-shaped string (per
  TC-1502-020's pattern); no `LoadError`. Derivation: AC line verbatim.

### TC-1502-110 — running the example world from outside the repo, via the installed gem
- **Covers:** #20 AC + #8 "running the example from outside the repo"
- **Type:** automated minitest (subprocess, ~30s timeout — see Conventions)
- **Setup:** same `GEM_HOME`/`GEM_PATH` as TC-1502-109; copy (or
  reference by absolute path) the `examples/` script to/from the scratch
  directory; `cwd` outside the repo
- **Input:** `ruby <path to the example script> < <canned command script>`
  (short script: one move, then EOF)
- **Expected:** exit status `0` (via the EOF path, per Section G); no
  `LoadError`; the output contains a `"Location: Foyer"` line (per the
  bare-area-name ban in Conventions, defect A — not a loose "room
  descriptions appear" check). Derivation: #21 AC, explicit
  required-coverage line, verbatim.

### TC-1502-111 — gemspec runtime dependencies are a superset of every bare `require` in `lib/`
- **Covers:** #21 required coverage "The gemspec's declared deps match
  what the code actually requires"
- **Type:** automated minitest (static scan + gemspec cross-check)
- **Setup:** scan every file under `lib/` for `require '<name>'` (bare
  `require`, not `require_relative`); load `dmud.gemspec`
- **Input:** the set of required gem names, minus a small stdlib allowlist
  (`securerandom` at minimum — see TC-1502-019)
- **Expected:** every remaining name appears in
  `spec.runtime_dependencies.map(&:name)`. Derivation: required-coverage
  line verbatim.

### TC-1502-112 — the code requires `reline` and calls `Reline.readline` directly; `readline`/`Readline` are absent (RULING #10, no longer a flagged contradiction)
- **Covers:** #20 "Why reline is declared" + TC-1502-111
- **Type:** automated minitest (static scan)
- **Setup:** read every file under `lib/` and `examples/`
- **Input:** n/a
- **Expected, all definitive per RULING #10:**
  1. No file contains a bare `require 'readline'`.
  2. No file references the `Readline` constant (no `Readline.readline`,
     `Readline.completion_...`, etc. — the compatibility module is not
     used anywhere).
  3. The prompt-reading file (currently `class_player.rb`, future
     `lib/dmud/player.rb`) contains `require 'reline'` and calls
     `Reline.readline(...)` (and the equivalent `Reline` completion APIs
     in place of the old `Readline.completion_*` calls).
  - Derivation: **RULING #10**, verbatim ("'requires reline directly'
    means the code calls `Reline.readline` and nothing requires
    'readline'"). This fully resolves what the step-3 draft flagged as a
    contradiction: there is now one unambiguous expected implementation,
    not an open question for I)ruid.

---

## M. Flagship end-to-end test (real process, real input, stdout + exit code)

### TC-1502-113 — full playthrough through the real example-world process
- **Covers:** required coverage "At least one end-to-end test that pipes
  real input into the real example world process (not hand-constructed
  objects) and checks stdout and exit code." Also exercises, in one run:
  #4 matching, #2 Invalid Command, the hidden-area reachability behavior,
  and #5's clean EOF exit.
- **Type:** automated minitest (subprocess, **~30s timeout** — this run
  pipes 5 commands before EOF, so its wall-clock floor from `Session`'s
  per-turn `sleep 1` (#16, unchanged) is ~5s; see Conventions and
  TC-1502-118)
- **Setup:** spawn `ruby -Ilib examples/<file>.rb` (the real process,
  real `Session`, real `Reline` prompt — not a hand-constructed
  `Player`/`Area` graph)
- **Input:** piped, in order:
  `"move foyer\n"`, `"move grand hall\n"`, `"move foyer\n"`,
  `"move secret room\n"`, `"xyzzy\n"`, then close stdin (EOF)
- **Expected:** exit status `0`; stdout contains, **in order, as
  `"Location: <name>"` lines specifically (per the bare-area-name ban in
  Conventions, defect A — not bare substring matches, since e.g. Grand
  Hall's own room description text mentions "the Foyer" and would make a
  bare-substring check pass for the wrong reason)**:
  `"Location: Foyer"`, `"Location: Grand Hall"`, `"Location: Foyer"`
  (again — noting per TC-1502-050 that this second one is reached via the
  entrance-gate/#13 path, not a dedicated loop gate, which is fine, since
  the test only asserts the `Location:` line, not the mechanism), then
  `"Location: Secret Room"`; separately, `"Invalid Command"` appears
  exactly once (for `xyzzy`); and the final line is exactly
  `"Farewell, Leeroy Jenkins."` (RULING #6). No literal `\\n` text
  anywhere (#6); no `MATCH`/`No match`/object-ID debug text anywhere,
  since `$DEBUG` is off for this run (#3). Derivation: composite of
  #21 AC's individual bullets and the step-4 rulings, each independently
  cited above, exercised together in one real subprocess per the task's
  explicit required-coverage item.

### TC-1502-114 — same playthrough, `$DEBUG` on, from the installed gem (packaging + debug-gating combined)
- **Covers:** same required-coverage line, combined with TC-1502-110's
  "from outside the repo" requirement, to get at least one E2E run that
  isn't just `-Ilib` from inside the checkout
- **Type:** automated minitest (subprocess, **~30s timeout**, same
  rationale as TC-1502-113)
- **Setup:** TC-1502-110's installed-gem/outside-repo setup, run with
  `-d`
- **Input:** same command script as TC-1502-113
- **Expected:** same `"Location: <name>"`-line sequence and exact
  `"Farewell, Leeroy Jenkins."` ending as TC-1502-113, **plus** `MATCH`
  debug lines and object-ID suffixes now present (confirms the guard
  still works correctly when driven through the real installed-gem path,
  not just the in-repo dev path). Derivation: same as TC-1502-113, run a
  second time through the packaging seam specifically.

---

## N. Regression confirmations — out-of-scope issues, where relevant (#11–#17, #19)

Per the task: these issues are explicitly out of scope for this batch.
The tests below exist only where an in-scope fix sits directly next to
documented out-of-scope behavior and could plausibly disturb it by
accident; they assert the **unchanged** behavior, not a fix.

### TC-1502-115 — the game-entrance round-trip quirk (#13) is unchanged, via `"move game lobby"`
- **Covers:** #13 (out of scope) — confirms #21's #7/#4 changes to the
  surrounding traversal code didn't accidentally alter this. See also
  TC-1502-050, which exercises the same underlying mechanism from a
  different starting command (`"move foyer"` while already in the
  Foyer, rather than `"move game lobby"` from the Foyer).
- **Type:** automated minitest
- **Setup:** Test Fixture World; `"move foyer"` then `"move game lobby"`
  from the Foyer
- **Input:** n/a
- **Expected:** the player ends up back in the Foyer, not the Game Lobby,
  with no error. Derivation: ARCHITECTURE.md, "verified by running `move
  foyer` then `move game lobby` and observing the player stays in the
  Foyer" — unchanged per #13 being out of scope.

### TC-1502-116 — a three-area gate still crashes the same way (#14) is unchanged
- **Covers:** #14 (out of scope) — cheap regression since it reuses
  existing fixtures, included despite being low-value per the report
- **Type:** automated minitest
- **Setup:** a `Gate` with three `Area`s added
- **Input:** traverse it
- **Expected:** raises `NoMethodError` (the documented, still-unfixed
  "destination unresolved" crash). Derivation: ARCHITECTURE.md, "the
  subsequent `exit(nil)` call fails with `NoMethodError`" — #14 is out
  of scope, so this must still happen.

### TC-1502-117 — `:say`/`:look`/`:inventory` dispatch remains a true no-op (#15) is unchanged
- **Covers:** #15 (out of scope) — already covered by TC-1502-045/048/
  049/060 above; this entry cross-references rather than duplicates
- **Type:** automated minitest
- **Setup:** see TC-1502-045/048/049/060
- **Input:** n/a
- **Expected:** see those test cases — listed here for completeness of the
  "confirm unchanged out-of-scope behavior" requirement, not as a new test.

### TC-1502-118 — `Session`'s infinite loop / per-turn `sleep 1` (#16) — intentionally not automated, but its timing governs every subprocess test's timeout (defect D)
- **Covers:** #16 (out of scope)
- **Type:** manual check (explicitly **not** automated as its own test —
  see rationale)
- **Setup:** n/a
- **Input:** n/a
- **Expected:** n/a
- **Rationale (not a test):** `Session.new` still never returns and
  still sleeps 1 second per turn. This is the authoritative place where
  that fact is converted into a concrete number for every other
  subprocess test in this document: a run piping `N` commands before
  EOF/Ctrl-C has a wall-clock floor of roughly `N` seconds (one per
  `sleep 1` between turns), before the process even starts tearing down.
  TC-1502-113/114 (5 commands, ~5s floor) and every test in Section G
  (1 command, ~1-2s floor) are all given a **generous ~30 second
  subprocess timeout** rather than one tightly fitted to their expected
  floor, specifically to absorb this plus ordinary CI scheduling jitter
  without becoming flaky. Writing a dedicated timing-assertion test (e.g.
  "this run takes at least N seconds") would add flakiness for no
  additional coverage, so that is explicitly skipped.

---

## O. Documentation (manual)

### TC-1502-119 — MANUAL: README/ARCHITECTURE/KNOWN_ISSUES reflect the new behavior
- **Covers:** #21 AC "Docs: README, ARCHITECTURE and KNOWN_ISSUES updated
  to match."
- **Type:** manual check
- **Setup:** code review of the diff against this document's fixed
  behaviors (#1–#9, #20)
- **Input:** n/a
- **Expected:** reviewer confirms each of #1, #2, #3, #4, #5, #6, #7, #8,
  #9's entries in `docs/KNOWN_ISSUES.md` is removed or rewritten to
  reflect the fix, and `docs/ARCHITECTURE.md`'s per-class sections,
  command table, and `$DEBUG` section are updated accordingly. Derivation:
  AC line verbatim; "updated to match" isn't mechanically checkable
  against a fixed string.

### TC-1502-120 — MANUAL: KNOWN_ISSUES.md's out-of-scope entries (#11–#17, #19) are left intact
- **Covers:** negative check paired with TC-1502-119 — confirms the
  doc update doesn't accidentally also "fix" or remove documentation for
  issues this batch didn't touch
- **Type:** manual check
- **Setup:** same review
- **Input:** n/a
- **Expected:** #11–#17 and #19's KNOWN_ISSUES entries still describe the
  same (unfixed) behavior. Derivation: task scope line ("#11-#17 and #19
  are OUT of scope"), applied to documentation specifically.

### TC-1502-121 — MANUAL: the `.ruby-version`/README Ruby-floor statement and the gemspec's `required_ruby_version` agree
- **Covers:** cross-check between TC-1502-001/002/003 (all automated
  individually, but nothing above cross-checks them against each other)
- **Type:** manual check
- **Setup:** read all three
- **Input:** n/a
- **Expected:** all three name the same minimum version (`3.3`), not
  just independently `>= 3.3`-shaped. Derivation: consistency, not a
  specific AC line; cheap enough to fold into doc review rather than a
  dedicated automated test.

### TC-1502-122 — MANUAL: the example world's gates have descriptive player-facing names, not the old generic ones
- **Covers:** #21 AC "the example gates get player-facing names" (defect C
  theme)
- **Type:** manual check
- **Setup:** read the `examples/` script's gate-construction calls
- **Input:** n/a
- **Expected:** reviewer confirms each `Gate.new(...)` call in the
  example world is given a descriptive, player-facing name (not left at
  the default `'New Gate'`, and not merely renamed mechanically) —
  spot-checked rather than automated since "descriptive" / "player-facing"
  is a qualitative judgment, and because no automated test in this
  document hard-codes any specific gate name to compare against (per the
  gate-naming convention in Conventions). Derivation: AC line verbatim.

---

## Coverage summary (by section)

| Section | Count |
| --- | --- |
| A — Ruby version floor | 3 |
| B — Gem layout | 12 |
| C — require_relative / cwd independence | 4 |
| D — Object construction | 17 |
| E — Command seam adversarial matrix | 24 |
| F — Debug-output guard | 6 |
| G — Exit handling (EOF/Ctrl-C) | 10 |
| H — Prompt format | 5 |
| I — Traversal order | 8 |
| J — Gate#connection_label/to_s/inspect | 9 |
| K — Style | 8 |
| L — Packaging seam + dependency accuracy | 6 |
| M — Flagship E2E | 2 |
| N — Out-of-scope regression confirmations | 4 |
| O — Documentation (manual) | 4 |
| **Total** | **122** |
