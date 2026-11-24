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
		indices = {
			clear: index_of(messages, "\033[2J\033[H"),
			toll:  index_of(messages, 'TOLL: a toll troll demands payment.'),
			step:  index_of(messages, 'You step through the Toll Gate.'),
			loc:   index_of(messages, 'Location: Other')
		}
		assert_order(indices.values.compact, [indices[:clear], indices[:toll], indices[:step], indices[:loc]])
	end

	# TC-1502-083: full pinned ordering, $DEBUG on (6 elements).
	# Derivation: RULING #7 all six items.
	def test_traversal_order_debug_on
		world = build_test_gate_world
		original_debug = $DEBUG
		$DEBUG = true
		messages = query_player(world[:player], 'move other')
		$DEBUG = original_debug

		indices = {
			clear:   index_of(messages, "\033[2J\033[H"),
			entered: index_of(messages, /You have entered the 'Toll Gate' Gate/),
			toll:    index_of(messages, 'TOLL: a toll troll demands payment.'),
			step:    index_of(messages, 'You step through the Toll Gate.'),
			exited:  index_of(messages, /You have exited the 'Toll Gate' Gate/),
			loc:     index_of(messages, 'Location: Other')
		}
		assert_order(indices.values.compact,
			[indices[:clear], indices[:entered], indices[:toll], indices[:step], indices[:exited], indices[:loc]])
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
		assert_order([index_of(messages, "\033[2J\033[H"),
			index_of(messages, 'You step through the Spinning Door.')],
			[index_of(messages, "\033[2J\033[H"), index_of(messages, 'You step through the Spinning Door.')])
	end

	# TC-1502-087: Secret Room hidden-side gate ordering on a real fixture.
	# Derivation: RULING #7 applied to a real gate; gate name read dynamically.
	def test_secret_room_gate_ordering
		world = fixture_world
		gate = world[:foyer].gate_lookup('Secret Room')
		messages = query_player(world[:player], 'move secret room')
		clear_idx = index_of(messages, "\033[2J\033[H")
		step_idx  = index_of(messages, "You step through the #{gate.metadata[:name]}.")
		loc_idx   = index_of(messages, 'Location: Secret Room')
		refute_nil clear_idx
		refute_nil step_idx
		refute_nil loc_idx
		assert_operator clear_idx, :<, step_idx
		assert_operator step_idx, :<, loc_idx
	end

	# TC-1502-088: ordinary two-sided gate with default no-op gate_specific.
	# Derivation: RULING #7 applied to base Gate#gate_specific.
	def test_two_sided_gate_default_gate_specific
		world = fixture_world
		gate = world[:foyer].gate_lookup('Grand Hall')
		messages = query_player(world[:player], 'move grand hall')
		clear_idx = index_of(messages, "\033[2J\033[H")
		step_idx  = index_of(messages, "You step through the #{gate.metadata[:name]}.")
		loc_idx   = index_of(messages, 'Location: Grand Hall')
		refute_nil clear_idx
		refute_nil step_idx
		refute_nil loc_idx
		assert_operator clear_idx, :<, step_idx
		assert_operator step_idx, :<, loc_idx
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

	def index_of(messages, pattern)
		messages.index { |m| pattern.is_a?(Regexp) ? m.match?(pattern) : m.include?(pattern) }
	end

	def assert_order(actual, expected)
		assert_equal expected, actual, "expected order #{expected.inspect}, got #{actual.inspect}"
	end
end
