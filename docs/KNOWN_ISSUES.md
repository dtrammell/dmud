# Known Issues

This is a plain-language summary of current limitations, quirks, and
planned design work in DMUD, grouped by area. Every item links to its
tracked issue on the [issue tracker](https://github.com/dtrammell/dmud/issues);
read the issue for the full discussion. Everything here was checked against
commit `d34cfb5ae7c51efe96d005019785497350942d42` on
`feature/issue-21-low-hanging-batch`: either read directly in
`lib/dmud/`, or confirmed by running the `test/` suite (`rake test`: 114
runs, 5173 assertions, 0 failures, 0 errors) and by running
`examples/example_world.rb` directly.

SE run #1502 ([#21](https://github.com/dtrammell/dmud/issues/21)) fixed
#1-#9 and packaged the engine as a gem
([#20](https://github.com/dtrammell/dmud/issues/20)) in this same commit;
those nine entries have been removed from this document rather than kept
as "fixed" trivia. Everything below either predates that batch and is
still open, or is new design work filed alongside it.

## Current limitations and quirks

### World-building API ergonomics

- **Constructors still take plain positional arguments, not keyword
  arguments** ([#11](https://github.com/dtrammell/dmud/issues/11), open).
  `examples/example_world.rb` no longer writes the misleading
  `name = "Foyer"` fake-keyword style that the old `test_game.rb` used —
  calls are now plain positional, e.g.
  `Area.new('Foyer', house, 'description...')` — but the constructors
  themselves (`Region.new`, `Area.new`, `Gate.new`, `MobileObject.new` and
  its subclasses, `Session.new`) are unchanged: argument order still
  matters and there's still no error if you get it wrong.
- **Several pieces of instance state are set but never used anywhere**
  ([#17](https://github.com/dtrammell/dmud/issues/17), open):
  `Gate@locked` and `Gate@traversable` (the latter is checked by `enter`,
  but nothing can set it, since there's still no accessor);
  `Area@proximity` (`:local`, presumably for the planned distributed
  model); `MobileObject@movable` and `@carryable` (never checked when
  moving an object or trying to carry one — `carryable` is set correctly
  per subclass now that [#1](https://github.com/dtrammell/dmud/issues/1) is
  fixed, but it's still not a real, checked feature, and it's still not a
  constructor parameter).

### Gates and movement

- **`Gate` still stores per-traversal state in instance variables**
  ([#12](https://github.com/dtrammell/dmud/issues/12), open).
  `Gate#enter` still keeps `@object`, `@source_area`, and
  `@destination_area` on the `Gate` itself, which is a single object
  shared by everyone who uses it. Two travelers through the same gate at
  once — or any multi-session/networked future — would still overwrite
  each other's in-flight state.
- **Moving to the Game Lobby from the Foyer still sends you back to the
  Foyer** ([#13](https://github.com/dtrammell/dmud/issues/13), open). The
  entrance gate (now named "Front Door") still unconditionally rewrites
  the traveling object's location to whichever area was linked to it
  first (the Lobby) before resolving a destination, so re-entering it
  from the Foyer still round-trips back to the Foyer with no error.
  Confirmed still present by the passing `test_entrance_round_trip_unchanged`
  and `test_move_foyer_while_in_foyer` tests.
- **A gate linking more than two areas is still unimplemented and still
  crashes when used** ([#14](https://github.com/dtrammell/dmud/issues/14),
  open). The `@areas.count > 2` branch in `Gate#enter` is still an empty
  `# TODO`; the destination is left unresolved and the subsequent
  `exit(nil)` call still fails with `NoMethodError`. `Area#exit` also still
  removes an object from its area's contents *before* calling
  `gate.enter`, so an exception raised during traversal still leaves the
  object's `location` pointing at the old area while it's already been
  removed from that area's contents, with nothing to rescue it. Confirmed
  still broken by the passing `test_three_area_gate_unsupported` test,
  which expects exactly this crash.

### Commands

- **`say`, `look`, and `inventory` are recognized but still do nothing**
  ([#15](https://github.com/dtrammell/dmud/issues/15), open).
  `Player#command` now has explicit `:say`/`:look`/`:inventory` branches
  (there used to be no branch at all for them), but each one just
  `return`s `true` — none of them produce any player-visible output. The
  symptom (silence) is unchanged even though the underlying code gained
  real branches.

### Session lifecycle

- **`Session.new` still never returns**
  ([#16](https://github.com/dtrammell/dmud/issues/16), open).
  `Session#initialize` still calls `self.start` itself, which is still an
  infinite loop, so construction and "running the game" are still the
  same call — a world file still can't keep a `Session` reference, run
  more than one, or hand control to anything else afterward. The loop
  still `sleep`s one second after every turn. (EOF and Ctrl-C no longer
  crash the process — see
  [docs/ARCHITECTURE.md](ARCHITECTURE.md#session-libdmudsessionrb) — but
  the constructor-never-returns design itself is unchanged and explicitly
  out of scope for this batch.)

### Documentation

- **There is still no "Build your first world" tutorial or generated API
  reference** ([#10](https://github.com/dtrammell/dmud/issues/10), open).
  This README/ARCHITECTURE/KNOWN_ISSUES set covers what exists today; a
  hands-on tutorial is deferred until the constructor API settles (see
  [#11](https://github.com/dtrammell/dmud/issues/11)).

## Planned design work (not yet implemented)

These are forward-looking proposals, not bugs in the current code — listed
separately from the quirks above so a reader doesn't mistake "not built
yet" for "broken."

- **Per-player display settings** ([#19](https://github.com/dtrammell/dmud/issues/19), open).
  Letting a player choose classic (no screen clears) vs. modern (clear on
  entering an Area) display, and ANSI color vs. monochrome, with the
  setting traveling with the player through `Gate`s to other nodes. This
  batch's screen-clear-at-the-start-of-traversal change
  ([docs/ARCHITECTURE.md](ARCHITECTURE.md#gateenter-step-by-step)) keeps
  clearing the screen as the hardcoded default specifically so this
  setting can replace that default later; it is not configurable yet.
- **Designer-registered custom commands with scope**
  ([#22](https://github.com/dtrammell/dmud/issues/22), open). A proposed
  API for world builders to register commands (e.g. `"pull lever"`)
  scoped to an Area, Realm, or Node, with scope-aware tab completion. This
  is a different feature from the existing, still-empty `:custom`
  dispatch stub in `Player#command`, which was left as a placeholder for
  a possible future *player*-macro system rather than *designer*-defined
  commands. Open design questions include whether "Realm" is a renamed
  `Region` or a new level above it.
- **Cryptographic cross-node rule enforcement**
  ([#23](https://github.com/dtrammell/dmud/issues/23), open). A proposal
  for provable, consistent rule application across independent DMUD
  nodes in the planned distributed model (canonical rulesets, signed
  state-transition events, hash-linked history) — relevant once
  networking and designer-defined commands exist, not relevant to the
  single-process game described in this document today.
