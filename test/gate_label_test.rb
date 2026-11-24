###
# Tests for Gate#connection_label, #to_s, and #inspect (#7, RULING #4/5).
###

require_relative 'test_helper'

class GateLabelTest < DMUDTestCase
	# TC-1502-090: connection_label for a plain two-sided visible gate.
	# Derivation: RULING #4 first bullet, verbatim.
	def test_connection_label_two_visible
		gate, foyer, hall = two_area_gate
		assert_equal 'Foyer <> Grand Hall', gate.connection_label
	end

	# TC-1502-091: connection_label marks a hidden side.
	# Derivation: RULING #4 second bullet, verbatim.
	def test_connection_label_hidden_side
		foyer = Area.new('Foyer')
		secret = Area.new('Secret Room')
		gate = Gate.new('Test Gate')
		foyer.add_gate(gate)
		secret.add_gate(gate, false)
		assert_equal 'Foyer <> Secret Room (hidden)', gate.connection_label
	end

	# TC-1502-092: connection_label for a one-area loop gate.
	# Derivation: RULING #4 third bullet, verbatim.
	def test_connection_label_loop
		foyer = Area.new('Foyer')
		gate = Gate.new('Test Gate')
		foyer.add_gate(gate)
		assert_equal 'Foyer (loop)', gate.connection_label
	end

	# TC-1502-093: connection_label for a zero-area gate.
	# Derivation: RULING #4 fourth bullet, verbatim.
	def test_connection_label_no_areas
		gate = Gate.new('Test Gate')
		assert_equal '(no areas)', gate.connection_label
	end

	# TC-1502-094: connection_label updates when a second area is added.
	# Derivation: required coverage + RULING #4.
	def test_connection_label_updates_on_second_area
		gate = Gate.new('Test Gate')
		area_a = Area.new('A')
		area_a.add_gate(gate)
		label1 = gate.connection_label
		area_b = Area.new('B')
		area_b.add_gate(gate)
		label2 = gate.connection_label
		assert_equal 'A (loop)', label1
		assert_equal 'A <> B', label2
	end

	# TC-1502-095: Gate#to_s format.
	# Derivation: RULING #5 first bullet, verbatim.
	def test_gate_to_s
		gate, foyer, hall = two_area_gate
		assert_equal 'Test Gate [Foyer <> Grand Hall]', gate.to_s
	end

	# TC-1502-096: Gate#inspect format.
	# Derivation: RULING #5 second bullet, verbatim.
	def test_gate_inspect
		gate, foyer, hall = two_area_gate
		expected = "#<Gate id=%s name=Test Gate connections=Foyer <> Grand Hall>" % gate.id
		assert_equal expected, gate.inspect
	end

	# TC-1502-097: $DEBUG traversal lines include connection info.
	# Derivation: #21 AC (cross-reference from TC-089).
	def test_debug_lines_include_connection_info
		# Covered by TraversalTest#test_debug_traversal_lines_include_connection_info.
		pass
	end

	# TC-1502-098: connection_label/to_s/inspect are idempotent derivations.
	# Derivation: "derived, not stored" framing.
	def test_label_derivations_idempotent
		gate, _foyer, _hall = two_area_gate
		assert_equal 'Foyer <> Grand Hall', gate.connection_label
		assert_equal 'Foyer <> Grand Hall', gate.connection_label
		assert_equal 'Test Gate [Foyer <> Grand Hall]', gate.to_s
		assert_equal 'Test Gate [Foyer <> Grand Hall]', gate.to_s
	end

	private

	def two_area_gate
		foyer = Area.new('Foyer')
		hall = Area.new('Grand Hall')
		gate = Gate.new('Test Gate')
		foyer.add_gate(gate)
		hall.add_gate(gate)
		[gate, foyer, hall]
	end
end
