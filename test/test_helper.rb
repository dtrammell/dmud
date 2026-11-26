###
# Shared test helpers for the DMUD minitest suite.
###

require 'minitest/autorun'
require 'open3'
require 'timeout'

# Load the engine via require_relative so the tests work regardless of the
# current working directory.
require_relative '../lib/dmud'

# Minimal TTY stand-in used by query_player so that Player#query follows
# its interactive Reline.readline path while tests run with a stubbed
# Reline.readline method.  Delegates output to the real stdout captured at
# construction to avoid delegating back to itself.
class FakeTTY
	def initialize(real_stdout)
		@real_stdout = real_stdout
	end

	def tty?
		true
	end

	def write(*args)
		@real_stdout.write(*args)
	end

	def puts(*args)
		@real_stdout.puts(*args)
	end

	def print(*args)
		@real_stdout.print(*args)
	end
end

class DMUDTestCase < Minitest::Test
	# Build the standard test fixture world described in
	# tests/TEST-CASES-ISSUE-21.md.  Gates are attached to the Foyer in the
	# same order as the example-world script:
	#   1. entrance gate
	#   2. Grand Hall gate
	#   3. Stairs gate
	#   4. Secret Room gate
	#
	# Returns a Hash with the created objects.
	def fixture_world
		house = Region.new('House')

		# Entrance gate: Lobby linked first (hidden), Foyer linked second.
		lobby = Area.new('Game Lobby')
		entrance_gate = Gate.new('Entrance Gate')
		entrance_gate.game_entrance = true
		lobby.add_gate(entrance_gate, false)

		foyer = Area.new('Foyer', house, 'The Foyer.')
		foyer.add_gate(entrance_gate)

		grand_hall = Area.new('Grand Hall', house, 'The Grand Hall.')
		gh_gate = Gate.new('Grand Hall Gate')
		foyer.add_gate(gh_gate)
		grand_hall.add_gate(gh_gate)

		stairs = Area.new('Stairs', house, 'The Stairs.')
		s_gate = Gate.new('Stairs Gate')
		foyer.add_gate(s_gate)
		stairs.add_gate(s_gate)

		secret_room = Area.new('Secret Room', house, 'The Secret Room.')
		sr_gate = Gate.new('Secret Room Gate')
		foyer.add_gate(sr_gate)
		secret_room.add_gate(sr_gate, false)

		player = Player.new('Leeroy Jenkins', foyer)

		{
			lobby: lobby,
			foyer: foyer,
			grand_hall: grand_hall,
			stairs: stairs,
			secret_room: secret_room,
			entrance_gate: entrance_gate,
			gh_gate: gh_gate,
			s_gate: s_gate,
			sr_gate: sr_gate,
			player: player
		}
	end

	# Feed the given input string to the example world subprocess and return
	# [stdout, stderr, exit_status].  Uses a generous 30-second timeout to
	# absorb Session's per-turn sleep 1 (#16, out of scope).
	#
	# $DEBUG is enabled by setting it in a leading -e snippet rather than
	# with the -d flag.  This lets the game's own $DEBUG-gated output print
	# while avoiding Ruby's built-in exception printer, which would otherwise
	# emit Reline internal ENOTTY noise on a pipe.
	def run_example_world(input, debug: false)
		cmd = if debug
			['ruby', '-Ilib', '-e', '$DEBUG=true; load ARGV[0]', example_world_path]
		else
			['ruby', '-Ilib', example_world_path]
		end

		stdout, stderr, status = nil
		Timeout.timeout(30) do
			stdout, stderr, status = Open3.capture3(*cmd, stdin_data: input)
		end
		[stdout, stderr, status]
	end

	# Return the single example-world script path under examples/.
	def example_world_path
		candidates = Dir.glob('examples/*.rb')
		flunk('Expected exactly one example world under examples/') unless candidates.size == 1
		candidates.first
	end

	# Send one line of input to the player's query method and return an array
	# of every message that was delivered to Player#message.
	def query_player(player, input_line)
		messages = []
		player.define_singleton_method(:message) { |msg| messages << msg }

		# Temporarily replace Reline.readline so tests can drive Player#query
		# without a real TTY.  Minitest's Object#stub is not available on the
		# Reline module, so we save and restore the original method manually.
		original_readline = Reline.method(:readline)
		Reline.define_singleton_method(:readline) { |*_args| input_line }

		# Player#query branches on $stdout.tty?.  Swap in a fake TTY so the
		# interactive Reline.readline branch runs and uses our stub.
		original_stdout = $stdout
		$stdout = FakeTTY.new(original_stdout)
		begin
			player.query
		ensure
			$stdout = original_stdout
			Reline.singleton_class.send(:define_method, :readline, original_readline)
		end

		messages
	end
end
