# DMUD — Distributed Multi-User Dungeon

DMUD is Dustin Trammell's Ruby world-building project: a set of plain Ruby
classes (`Region`, `Area`, `Gate`, `MobileObject`, `Session`, ...) that a
developer composes into a MUD-style game world, the way the example in
`test_game.rb` does.

**Distributed networking is planned, not implemented.** The name describes
where the project is going: multiple game servers linked by `Gate`s, likely
over [libp2p](https://libp2p.io/) (not yet integrated — no networking code
exists in this repo). **Today, DMUD runs as a single-player game in one
terminal.** You build a world in a Ruby script, run that script, and play it
yourself from the same process, as `test_game.rb` does.

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
- **`MobileObject`** — the base class (defined, despite the file name, in
  `class_movable_object.rb`) for anything that exists inside an `Area` and
  has a location: its subclasses are `Player` (a human player, with command
  parsing and a Readline prompt), `NPC` (a non-player character), `MOB` (a
  monster), and `Item` (a carryable object).
- **`Session`** — ties one `Player` to a running game loop: it prints the
  current area's exits, asks the player for a command, and repeats.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full class
reference, constructor arguments, a movement sequence diagram, and a
walkthrough of the example world.

## Requirements

- **Ruby.** The example world and commands below were verified against
  **Ruby 4.0.5** (this repo's development machine) and the project's issue
  history also references **Ruby 3.4.6**. No `Gemfile`, gemspec, or
  `.ruby-version` file pins a version yet; there is no reason to expect
  anything below Ruby 3.x to work, since the code relies on `Readline` behavior
  found in modern Ruby's Reline-backed implementation.
- **Standard library only:** `readline` (command-line editing/history/tab
  completion) and `securerandom` (object IDs). No third-party gems.

## Quick start

```bash
git clone https://github.com/dtrammell/dmud.git
cd dmud
ruby test_game.rb
```

You must run it from inside the `dmud` directory. Every file loads its
dependencies with `require './other_file.rb'`, which resolves relative to
your current working directory, not the script's location — running it from
anywhere else fails with a `LoadError` ([#8](https://github.com/dtrammell/dmud/issues/8)).

`test_game.rb` builds a small five-area house (see the map in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#example-world-walkthrough-test_gamerb))
and starts a `Session` for one player, "Leeroy Jenkins." You'll see the
current area described, an `Exits:` list, and a prompt:

```
Leeroy Jenkins: Command>
```

### Commands you can type today

| You type | Matches | What happens right now |
| --- | --- | --- |
| `move <area>`, `m <area>`, `go <area>`, `walk <area>`, `run <area>` | `:move` | Looks up a `Gate` to the named area from where you are and, if found, moves you there. The area name must follow the keyword with a space (`move foyer`); a bare `move` with nothing after it, or the word with no trailing space, does not match at all ([#4](https://github.com/dtrammell/dmud/issues/4)). |
| `say <text>`, `s <text>`, `talk <text>`, `yell <text>` | `:say` | Recognized by the parser but **does nothing** — no message is sent anywhere ([#15](https://github.com/dtrammell/dmud/issues/15)). |
| `look`, `l`, `inspect` | `:look` | Recognized but **does nothing** yet; it does not re-print the room ([#15](https://github.com/dtrammell/dmud/issues/15)). Also needs a trailing space to match as a prefix today, so a bare `look` only matches via the catch-all below, not the `:look` entry ([#4](https://github.com/dtrammell/dmud/issues/4)). |
| `i`, `inventory` | `:inventory` | Recognized but **does nothing** yet ([#15](https://github.com/dtrammell/dmud/issues/15)). |
| anything else | internal catch-all | Matches silently; you will never actually see "Invalid Command" no matter what you type ([#2](https://github.com/dtrammell/dmud/issues/2)). |
| Ctrl-D (EOF) | — | Crashes the game with a `NoMethodError` ([#5](https://github.com/dtrammell/dmud/issues/5)) — this is a known, currently-expected failure mode, not something new you broke. |

Debug output (which command pattern matched, object UUIDs) currently
prints unconditionally, regardless of `$DEBUG` ([#3](https://github.com/dtrammell/dmud/issues/3)).
See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md#the-debug-flag) for where
`$DEBUG` is actually checked today.

A worked example, from a real run:

```
Leeroy Jenkins: Command> move foyer
You have entered the 'Game Entrance' Gate
You traverse the gate...
You have exited the 'Game Entrance' Gate
Location: Foyer

The Foyer is large and inviting.  You see Stairs to the right and an entrance to a Grand Hall directly ahead.

Foyer contains:
  * Leeroy Jenkins

Exits:
  > Grand Hall
  > Stairs
```

## Writing your own world

There is no tutorial yet. The constructors you'd use to build a world
(`Area.new`, `Gate.new`, `Region.new`, ...) currently take plain
**positional** arguments, and `test_game.rb`'s style of calling them —
`Area.new( name = "Foyer", region = house, description = '...' )` — only
*looks* like keyword arguments; `name = "Foyer"` is really just a local
variable assignment, and the values are passed positionally in that exact
order ([#11](https://github.com/dtrammell/dmud/issues/11)). A real
"Build your first world" guide is planned once this API shape is settled
([#10](https://github.com/dtrammell/dmud/issues/10)); until then, read
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) and `test_game.rb` itself,
which is the only working example world in the repo.

## More documentation

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — class-by-class reference,
  the movement sequence, the `Gate` model, command matching, the `Session`
  loop, the `$DEBUG` flag, and a map of the example world.
- [docs/KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md) — current limitations and
  quirks, grouped by area, each linking to its tracked issue.
- [Issue tracker](https://github.com/dtrammell/dmud/issues) — the full,
  up-to-date list, including feature requests like real keyword arguments
  ([#11](https://github.com/dtrammell/dmud/issues/11)) and the planned
  tutorial ([#10](https://github.com/dtrammell/dmud/issues/10)).
