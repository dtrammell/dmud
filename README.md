# DMUD — Distributed Multi-User Dungeon

DMUD is Dustin Trammell's Ruby world-building project: a gem of plain Ruby
classes (`Region`, `Area`, `Gate`, `MobileObject`, `Session`, ...) that a
developer composes into a MUD-style game world, the way
`examples/example_world.rb` does.

**Distributed networking is planned, not implemented.** The name describes
where the project is going: multiple game servers linked by `Gate`s, likely
over [libp2p](https://libp2p.io/) (not yet integrated — no networking code
exists in this repo). **Today, DMUD runs as a single-player game in one
terminal.** You build a world in a Ruby script that requires the `dmud` gem,
run that script, and play it yourself from the same process, as
`examples/example_world.rb` does.

This README describes what exists in the code right now, including its
rough edges. See [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) for a full list
of quirks and bugs, and the [issue tracker](https://github.com/dtrammell/dmud/issues)
for everything that's tracked.

## Core concepts

- **`DMUDObject`** — the root class of every DMUD object. It assigns every
  instance a random UUID (`id`) and nothing else; every other class
  inherits from it.
- **`Region`** — a named container that groups `Area`s together for
  organizational purposes (a server will usually have one).
- **`Area`** — a single place in the game (a room, a field, a grove) with a
  name, a description, a list of connecting `Gate`s, and a list of objects
  currently inside it.
- **`Gate`** — a link between two (or, in a one-area case, back to the same)
  `Area`s that an object passes through to travel between them; it's what
  MUD players usually call an "exit."
- **`MobileObject`** — the base class, defined in
  [`lib/dmud/mobile_object.rb`](lib/dmud/mobile_object.rb), for anything that exists
  inside an `Area` and has a location: its subclasses are `Player` (a human
  player, with command parsing and a Reline prompt), `NPC` (a non-player
  character), `MOB` (a monster), and `Item` (a carryable object).
- **`Session`** — ties one `Player` to a running game loop: it prints the
  current area's exits, asks the player for a command, and repeats.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full class
reference, constructor arguments, a movement sequence diagram, and a
walkthrough of the example world.

## Requirements

- **Ruby 3.3 or newer.** The `.ruby-version` file pins `3.3.0`, and
  `dmud.gemspec` declares `required_ruby_version '>= 3.3'`. Everything in this
  document was run on Ruby **4.0.5**; older supported versions (3.3, 3.4)
  are not tested here.
- **Runtime dependency: `reline`** (`~> 0.5` in the gemspec; `0.7.0` is what
  actually resolved and was used for every example in this document). On
  Ruby 3.4+ and 4.0, `reline` (along with `minitest` and `rake`) ships as a
  *bundled* gem, not stdlib, so a world project that uses Bundler needs it
  declared explicitly — that's why it's a real gemspec dependency instead of
  an assumed-available stdlib `require`. The code requires `'reline'` and
  calls `Reline.readline` directly; it does not use the older `Readline`
  compatibility module at all.
- **Development dependencies:** `minitest` (`>= 5.0, < 7` — the suite is written
  to run under both minitest 5 and 6; `6.1.0` is what this document's test
  run used) and `rake` (`~> 13.0`; `13.4.2` here).
- **Standard library:** `securerandom` (object IDs) — this one stays a plain
  stdlib require, it is not a gem dependency.

## Quick start

### From a clone, for development

```bash
git clone https://github.com/dtrammell/dmud.git
cd dmud
bundle install        # installs reline, minitest, rake
ruby -Ilib examples/example_world.rb
```

`-Ilib` puts the repo's own `lib/` on the load path, so
`examples/example_world.rb`'s `require 'dmud'` finds the gem's code without
installing anything. Unlike the old flat-file layout, it no longer matters
which directory you run this from — `require_relative` inside `lib/`
resolves relative to the files themselves, not your current directory.

### As an installed gem

```bash
gem build dmud.gemspec
gem install ./dmud-0.0.1.gem
ruby -e "require 'dmud'; puts DMUDObject.new.id"
```

Both `gem build` and `gem install` work locally, and once installed,
`require 'dmud'` works from anywhere — it does **not** need to be run from
inside this repo. This gem has not been published to RubyGems.org; publishing
and a versioning policy are explicitly out of scope for now (tracked in
[#20](https://github.com/dtrammell/dmud/issues/20)).

**`examples/example_world.rb` itself is not packaged into the installed
gem** — `dmud.gemspec`'s file list only ships `lib/**/*.rb` plus `LICENSE` and
the two docs in `docs/`. To run the example world against an installed
gem rather than `-Ilib`, keep a copy of `examples/example_world.rb` from a
clone (it only needs `require 'dmud'` to find the installed gem).

Either way, you'll see the current area described, an `Exits:` list, and a
prompt:

```
Leeroy Jenkins: Command> 
```

### Commands you can type today

| You type | Matches | What happens right now |
| --- | --- | --- |
| `move <area>`, `m <area>`, `go <area>`, `walk <area>`, `run <area>` | `:move` | Looks up a `Gate` to the named area from where you are and, if found, moves you there. Matching is now case-insensitive and happens on a word boundary, so bare `move` (with nothing after it) matches the command but prints exactly `"Move where?"` instead of silently failing or crashing. |
| `say <text>`, `s <text>`, `talk <text>`, `yell <text>` | `:say` | Recognized (including bare `say` with nothing after it) but **still does nothing** — no message is sent anywhere ([#15](https://github.com/dtrammell/dmud/issues/15)). |
| `look`, `l`, `inspect` | `:look` | Recognized, including the bare word with nothing after it, but **still does nothing**; it does not re-print the room ([#15](https://github.com/dtrammell/dmud/issues/15)). |
| `i`, `inventory` | `:inventory` | Recognized, including bare `i`/`inventory`, but **still does nothing** ([#15](https://github.com/dtrammell/dmud/issues/15)). |
| anything else | — | Prints exactly `"Invalid Command"`. Matching now stops at the first command whose pattern matches the (whitespace-stripped) input, so a command is only ever dispatched once. |
| Ctrl-D (EOF) | — | Prints `"Farewell, <your name>."` and exits with status `0`. With `$DEBUG` on (`ruby -d`), it first prints `"EOF (end of input)"`, a backtrace, and the session/player state, then the goodbye line. |
| Ctrl-C (Interrupt) | — | Same clean exit as EOF: goodbye and status `0`; with `$DEBUG` on, the `Interrupt` exception and its backtrace print first, then state, then goodbye. |

A word-boundary match means `lookout`, `items`, and `moved` do **not** match
`look`/`inventory`/`move` respectively — they fall through to `"Invalid
Command"` instead of being swallowed by a stray prefix match. Debug output
(which command pattern matched, object UUIDs, the gate traversal's
entered/exited lines) only prints when `$DEBUG` is on — see
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#the-debug-flag).

A worked example, from a real run (`ruby -Ilib examples/example_world.rb`,
piped commands `move foyer`, `look`, `say hi`, `move secret room`, `xyzzy`, then
EOF). The only editing done to this transcript is stripping the ANSI
clear-screen escape bytes that `Gate#enter` sends at the start of each
traversal, so it's readable in Markdown — everything else, including the
fact that `look` and `say hi` produce no visible output at all, is exactly
what printed:

```
Exits:
  > Foyer

Leeroy Jenkins: Command> 
You step through the Front Door.
Location: Foyer

The Foyer is large and inviting.  You see Stairs to the right and an entrance to a Grand Hall directly ahead.

Foyer contains:
  * Leeroy Jenkins

Exits:
  > Grand Hall
  > Stairs

Leeroy Jenkins: Command> 
Exits:
  > Grand Hall
  > Stairs

Leeroy Jenkins: Command> 
Exits:
  > Grand Hall
  > Stairs

Leeroy Jenkins: Command> 
You step through the Hidden Passage.
Location: Secret Room

The Secret Room was not meant to be found...  What secrets might it hold???  The only way out is back to the Foyer.

Secret Room contains:
  * Leeroy Jenkins

Exits:
  > Foyer

Leeroy Jenkins: Command> 
Invalid Command
Exits:
  > Foyer
Farewell, Leeroy Jenkins.
```

## Writing your own world

There is no tutorial yet ([#10](https://github.com/dtrammell/dmud/issues/10),
still deferred). The public constructors (`Area.new`, `Gate.new`,
`Region.new`, `MobileObject.new` and its subclasses, `Session.new`) take
plain **positional** arguments — unlike the old `test_game.rb`,
`examples/example_world.rb` no longer writes calls in the misleading
`name = "Foyer"` fake-keyword style, but the constructors themselves still
don't accept real keyword arguments, so argument order still matters and
there's still no error if you get it wrong
([#11](https://github.com/dtrammell/dmud/issues/11), open). Until there's a
tutorial, read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and
`examples/example_world.rb` itself, which is the only working example
world in the repo.

## Development

```bash
bundle install
rake test
```

`rake test` (the Rakefile's default task) runs the full `test/` suite under
minitest; it passed cleanly here (114 runs, 5173 assertions, 0 failures,
0 errors) on Ruby 4.0.5 with minitest 6.1.0. The suite includes a
regression test for every fixed issue plus an end-to-end test that pipes
commands into the example world and checks both its output and its exit
code.

## More documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — class-by-class reference
  (with `lib/dmud/` file paths), the movement sequence, the `Gate` model,
  command matching, the `Session` loop and its exit handling, the
  `$DEBUG` flag, and a map of the example world.
- [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) — current limitations and
  quirks, grouped by area, each linking to its tracked issue.
- [Issue tracker](https://github.com/dtrammell/dmud/issues) — the full,
  up-to-date list, including feature requests like real keyword arguments
  ([#11](https://github.com/dtrammell/dmud/issues/11)) and the planned
  tutorial ([#10](https://github.com/dtrammell/dmud/issues/10)).
