###
# Tests for traversal output order (#7).
###

require_relative 'test_helper'

# Test subclass that emits identifiable gate_specific output.
class TestGate < Gate
	def gate_specific
		@object.message('TOLL: a toll troll demands payment.')
	end
end

class TraversalTest < DMUDTestCase
	# TC-1502-082: full pinned ordering, $DEBUG off (4 elements).
	# Derivation: RULING #7 items 1, 3, 4, 6.
	def test_traversal_order_debug_off
		world = build_test_gate_world
		messages = query_player(world[:player], 'move other')
		assert_order(messages, [
			"\033[2J\033[H",
			'TOLL: a toll troll demands payment.',
			'You step through the Toll Gate.',
			'Location: Other'
		])
	end

	# TC-1502-083: full pinned ordering, $DEBUG on (6 elements).
	# Derivation: RULING #7 all six items.
	def test_traversal_order_debug_on
		world = build_test_gate_world
		original_debug = $DEBUG
		$DEBUG = true
		messages = query_player(world[:player], 'move other')
		$DEBUG = original_debug

		assert_order(messages, [
			"\033[2J\033[H",
			/You have entered the 'Toll Gate' Gate/,
			'TOLL: a toll troll demands payment.',
			'You step through the Toll Gate.',
			/You have exited the 'Toll Gate' Gate/,
			'Location: Other'
		])
	end

	# TC-1502-084: step-through line's literal content.
	# Derivation: #21 AC verbatim.
	def test_step_through_line_content
		world = build_test_gate_world
		messages = query_player(world[:player], 'move other')
		assert_includes messages, 'You step through the Toll Gate.'
	end

	# TC-1502-085: entered/exited lines gated by $DEBUG with pinned wording.
	# Derivation: #21 AC "entered/exited lines only under $DEBUG" + RULING #7.
	def test_entered_exited_debug_gated
		world = build_test_gate_world
		[false, true].each do |debug|
			original_debug = $DEBUG
			$DEBUG = debug
			messages = query_player(Player.new('Leeroy Jenkins', world[:start]), 'move other')
			$DEBUG = original_debug
			if debug
				assert messages.any? { |m| m.include?("You have entered the 'Toll Gate' Gate") }
				assert messages.any? { |m| m.include?("You have exited the 'Toll Gate' Gate") }
			else
				refute messages.any? { |m| m.include?("You have entered the 'Toll Gate' Gate") }
				refute messages.any? { |m| m.include?("You have exited the 'Toll Gate' Gate") }
			end
		end
	end

	# TC-1502-086: one-area (loop) gate traversal: pinned order holds.
	# Derivation: ARCHITECTURE.md one-area case + RULING #7.
	def test_loop_gate_traversal
		start = Area.new('Start')
		gate = TestGate.new('Spinning Door')
		start.add_gate(gate)
		player = Player.new('Leeroy Jenkins', start)
		messages = query_player(player, 'move start')
		assert_order(messages, [
			"\033[2J\033[H",
			'You step through the Spinning Door.'
		])
	end

	# TC-1502-090: one-area loop gate ordering: loop text is between
	# gate_specific output and the step-through line.
	# Derivation: RULING #7 one-area case, gate_specific + loop text ordering.
	def test_loop_gate_ordering_debug_off
		start = Area.new('Start')
		gate = TestGate.new('Spinning Door')
		start.add_gate(gate)
		player = Player.new('Leeroy Jenkins', start)
		messages = query_player(player, 'move start')
		assert_order(messages, [
			'TOLL: a toll troll demands payment.',
			'This Gate seems to only return to the Area you\'re leaving...',
			'You step through the Spinning Door.'
		])
	end

	# TC-1502-091: one-area loop gate ordering with $DEBUG on: entered,
	# gate_specific, loop text, step-through, exited.
	# Derivation: RULING #7 one-area case with debug lines included.
	def test_loop_gate_ordering_debug_on
		start = Area.new('Start')
		gate = TestGate.new('Spinning Door')
		start.add_gate(gate)
		player = Player.new('Leeroy Jenkins', start)
		original_debug = $DEBUG
		$DEBUG = true
		messages = query_player(player, 'move start')
		$DEBUG = original_debug
		assert_order(messages, [
			/You have entered the 'Spinning Door' Gate/,
			'TOLL: a toll troll demands payment.',
			'This Gate seems to only return to the Area you\'re leaving...',
			'You step through the Spinning Door.',
			/You have exited the 'Spinning Door' Gate/
		])
	end

	# TC-1502-087: Secret Room hidden-side gate ordering on a real fixture.
	# Derivation: RULING #7 applied to a real gate; gate name read dynamically.
	def test_secret_room_gate_ordering
		world = fixture_world
		gate = world[:foyer].gate_lookup('Secret Room')
		messages = query_player(world[:player], 'move secret room')
		assert_order(messages, [
			"\033[2J\033[H",
			"You step through the #{gate.metadata[:name]}.",
			'Location: Secret Room'
		])
	end

	# TC-1502-088: ordinary two-sided gate with default no-op gate_specific.
	# Derivation: RULING #7 applied to base Gate#gate_specific.
	def test_two_sided_gate_default_gate_specific
		world = fixture_world
		gate = world[:foyer].gate_lookup('Grand Hall')
		messages = query_player(world[:player], 'move grand hall')
		assert_order(messages, [
			"\033[2J\033[H",
			"You step through the #{gate.metadata[:name]}.",
			'Location: Grand Hall'
		])
	end

	# TC-1502-089: $DEBUG traversal lines include connection info.
	# Derivation: #21 AC "the $DEBUG traversal lines include them".
	def test_debug_traversal_lines_include_connection_info
		world = fixture_world
		gate = world[:foyer].gate_lookup('Grand Hall')
		label = gate.connection_label
		original_debug = $DEBUG
		$DEBUG = true
		messages = query_player(Player.new('Leeroy Jenkins', world[:foyer]), 'move grand hall')
		$DEBUG = original_debug
		entered = messages.find { |m| m.include?("You have entered the '#{gate.metadata[:name]}' Gate") }
		exited  = messages.find { |m| m.include?("You have exited the '#{gate.metadata[:name]}' Gate") }
		refute_nil entered
		refute_nil exited
		assert_includes entered, label
		assert_includes exited, label
	end

	# TC-1502-115: entrance round-trip behaviour is unchanged (#13).
	# Derivation: RULING #13 entrance-gate behaviour regression.
	def test_entrance_round_trip_unchanged
		world = fixture_world
		player = Player.new('Leeroy Jenkins', world[:lobby])
		# From the Lobby the entrance gate is hidden, but the player can still
		# traverse to the connected area by name.
		messages = query_player(player, 'move foyer')
		assert messages.any? { |m| m.include?('Location: Foyer') }
		assert_equal world[:foyer], player.location
		# Returning through the entrance gate currently lands back in the Foyer
		# because the game_entrance flag forces the source area to the Lobby
		# side (#13, unchanged behaviour).
		messages = query_player(player, 'move game lobby')
		assert messages.any? { |m| m.include?('Location: Foyer') }
		assert_equal world[:foyer], player.location
	end

	# TC-1502-116: 3+ area gates still raise/behaviour unchanged (#14 out of scope).
	# Derivation: RULING #14 multi-destination gates are not yet supported.
	def test_three_area_gate_unsupported
		start = Area.new('Start')
		a = Area.new('A')
		b = Area.new('B')
		gate = Gate.new('Three-Way Gate')
		start.add_gate(gate)
		a.add_gate(gate)
		b.add_gate(gate)
		player = Player.new('Leeroy Jenkins', start)
		# Moving through a >2-area gate currently crashes because destination
		# selection is unimplemented.  This test pins that behaviour until #14
		# is in scope.
		assert_raises(NoMethodError) { query_player(player, 'move a') }
	end

	private

	def build_test_gate_world
		start = Area.new('Start')
		other = Area.new('Other')
		gate = TestGate.new('Toll Gate')
		start.add_gate(gate)
		other.add_gate(gate)
		player = Player.new('Leeroy Jenkins', start)
		{ start: start, other: other, gate: gate, player: player }
	end

	# Return the index of the first message matching pattern.
	def index_of(messages, pattern)
		messages.index { |m| pattern.is_a?(Regexp) ? m.match?(pattern) : m.include?(pattern) }
	end

	# Assert that the given patterns appear in the captured messages in exactly
	# the order supplied.  Each pattern must be present, and each must occur at
	# a strictly lower index than the next.
	def assert_order(messages, patterns)
		indices = patterns.map { |pattern| index_of(messages, pattern) }
		labels = patterns.map { |p| p.is_a?(Regexp) ? p.source : p }
		indices.each_with_index do |idx, i|
			refute_nil idx, "expected '#{labels[i]}' to appear in output"
		end
		(1...indices.size).each do |i|
			assert_operator indices[i - 1], :<, indices[i],
				"expected '#{labels[i - 1]}' (index #{indices[i - 1]}) before '#{labels[i]}' (index #{indices[i]})"
		end
	end
end
