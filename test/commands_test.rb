###
# Tests for the command seam: word boundaries, input stripping,
# case-insensitivity, Invalid Command, Move where?, and no-op dispatch
# for out-of-scope commands (#2, #4).
###

require_relative 'test_helper'

class CommandsTest < DMUDTestCase
	# TC-1502-037: empty line -> Invalid Command.
	# Derivation: #2 AC (no pattern matches an empty string).
	def test_empty_line_invalid_command
		world = fixture_world
		messages = query_player(world[:player], '')
		assert_equal ['Invalid Command'], messages
	end

	# TC-1502-038: whitespace-only line -> Invalid Command.
	# Derivation: #2 AC + RULING #1 (input is stripped before matching).
	def test_whitespace_only_invalid_command
		world = fixture_world
		messages = query_player(world[:player], '   ')
		assert_equal ['Invalid Command'], messages
	end

	# TC-1502-039: leading/trailing spaces around a valid command still match.
	# Derivation: RULING #1 applied to a two-area move.
	def test_padded_valid_command_matches
		world = fixture_world
		messages = query_player(world[:player], '  move grand hall  ')
		assert_equal world[:grand_hall], world[:player].location
	end

	# TC-1502-040: command keyword is case-insensitive: "MOVE Foyer" succeeds.
	# Derivation: RULING #2 verbatim.
	def test_uppercase_command_keyword
		world = fixture_world
		world[:player].location = world[:grand_hall]
		query_player(world[:player], 'MOVE Foyer')
		assert_equal world[:foyer], world[:player].location
	end

	# TC-1502-041: mixed-case area name resolves with a lowercase keyword.
	# Derivation: TC-023 (unchanged gate_lookup case-insensitivity on area
	# names specifically).
	def test_uppercase_area_name
		world = fixture_world
		query_player(world[:player], 'move GRAND HALL')
		assert_equal world[:grand_hall], world[:player].location
	end

	# TC-1502-042: "lookout" must NOT match :look.
	# Derivation: #4 AC "commands match on word boundaries".
	def test_lookout_prefix_collision
		world = fixture_world
		messages = query_player(world[:player], 'lookout')
		assert_equal ['Invalid Command'], messages
	end

	# TC-1502-043: "items" must NOT match :inventory.
	# Derivation: #4 AC (word boundary for i/inventory).
	def test_items_prefix_collision
		world = fixture_world
		messages = query_player(world[:player], 'items')
		assert_equal ['Invalid Command'], messages
	end

	# TC-1502-044: "moved" must NOT match :move.
	# Derivation: #4 AC (word boundary for move).
	def test_moved_prefix_collision
		world = fixture_world
		messages = query_player(world[:player], 'moved')
		assert_equal ['Invalid Command'], messages
	end

	# TC-1502-045: bare "say" matches :say but stays a no-op.
	# Derivation: #4 AC (bare say matches) + #15 out of scope (dispatch
	# unchanged).
	def test_bare_say_no_op
		world = fixture_world
		messages = query_player(world[:player], 'say')
		assert_empty messages
	end

	# TC-1502-046: "m" alone matches :move with missing target -> "Move where?".
	# Derivation: #4 AC "move with no target says 'Move where?'".
	def test_m_alias_move_where
		world = fixture_world
		messages = query_player(world[:player], 'm')
		assert_equal ['Move where?'], messages
	end

	# TC-1502-047: "move" alone -> "Move where?".
	# Derivation: #4 AC verbatim.
	def test_move_alone_move_where
		world = fixture_world
		messages = query_player(world[:player], 'move')
		assert_equal ['Move where?'], messages
	end

	# TC-1502-048: "i" alone matches :inventory but stays a no-op.
	# Derivation: same reasoning as TC-045 applied to :inventory.
	def test_i_alias_inventory_no_op
		world = fixture_world
		messages = query_player(world[:player], 'i')
		assert_empty messages
	end

	# TC-1502-049: bare "look" matches :look but stays a no-op.
	# Derivation: #4 repro inverted + #15 out of scope.
	def test_bare_look_no_op
		world = fixture_world
		messages = query_player(world[:player], 'look')
		assert_empty messages
	end

	# TC-1502-050: "move foyer" while in Foyer resolves through entrance gate.
	# Derivation: derived from source order + ARCHITECTURE.md game-entrance
	# mechanism; #13 out of scope.
	def test_move_foyer_while_in_foyer
		world = fixture_world
		entrance_gate = world[:foyer].gate_lookup('Foyer')
		before = world[:player].location
		messages = query_player(world[:player], 'move foyer')
		assert_same before, world[:player].location
		assert_includes messages, "You step through the #{entrance_gate.metadata[:name]}."
	end

	# TC-1502-051: multi-word area name: "move Grand Hall".
	# Derivation: unchanged argument-extraction behavior from ARCHITECTURE.md.
	def test_multi_word_area_name
		world = fixture_world
		query_player(world[:player], 'move Grand Hall')
		assert_equal world[:grand_hall], world[:player].location
	end

	# TC-1502-052: nonexistent area name -> unchanged message.
	# Derivation: class_player.rb existing literal string; #21 AC does not
	# change it.
	def test_nonexistent_area_name
		world = fixture_world
		messages = query_player(world[:player], 'move Dungeon')
		assert_equal ["Area 'Dungeon' not accessible from here."], messages
	end

	# TC-1502-053: hidden-but-reachable area from Foyer.
	# Derivation: TC-024 + ARCHITECTURE.md Secret Room explanation.
	def test_hidden_area_reachable
		world = fixture_world
		query_player(world[:player], 'move Secret Room')
		assert_equal world[:secret_room], world[:player].location
		foyer_exits = world[:foyer].gates.flat_map do |gate|
			gate.areas.select { |a| a[:visible] }.map { |a| a[:object].metadata[:name] }
		end
		refute_includes foyer_exits, 'Secret Room'
	end

	# TC-1502-054: unicode in a nonexistent area name round-trips correctly.
	# Derivation: extrapolated from TC-052's unchanged message format.
	def test_unicode_area_name
		world = fixture_world
		messages = query_player(world[:player], 'move Café')
		assert_equal ["Area 'Café' not accessible from here."], messages
	end

	# TC-1502-055: unicode non-command line -> Invalid Command, no crash.
	# Derivation: #2 fix applied to non-ASCII input.
	def test_unicode_non_command
		world = fixture_world
		messages = query_player(world[:player], '你好')
		assert_equal ['Invalid Command'], messages
	end

	# TC-1502-056: emoji-only line -> Invalid Command, no crash.
	# Derivation: same as TC-055; probes \b edge behavior.
	def test_emoji_non_command
		world = fixture_world
		messages = query_player(world[:player], '🎮')
		assert_equal ['Invalid Command'], messages
	end

	# TC-1502-057: stops-at-first-match for first entry.
	# Derivation: #2 AC verbatim + unchanged hash-insertion order.
	def test_stops_at_first_match_first_entry
		world = fixture_world
		original_debug = $DEBUG
		$DEBUG = true
		stdout = StringIO.new
		original_stdout = $stdout
		$stdout = stdout
		query_player(world[:player], 'move foyer')
		$stdout = original_stdout
		$DEBUG = original_debug
		output = stdout.string
		assert_match(/MATCH.*move/, output)
		refute_match(/No match/, output)
	end

	# TC-1502-058: stops-at-first-match across a later entry.
	# Derivation: #2 AC verbatim.
	def test_stops_at_first_match_later_entry
		world = fixture_world
		original_debug = $DEBUG
		$DEBUG = true
		stdout = StringIO.new
		original_stdout = $stdout
		$stdout = stdout
		query_player(world[:player], 'say hello')
		$stdout = original_stdout
		$DEBUG = original_debug
		output = stdout.string
		assert_match(/No match.*move/, output)
		assert_match(/MATCH.*say/, output)
		refute_match(/Processing command 'look'/, output)
		refute_match(/Processing command 'inventory'/, output)
	end

	# TC-1502-059: unknown single word -> Invalid Command with $DEBUG on and off.
	# Derivation: #2 AC verbatim.
	def test_unknown_word_invalid_command
		world = fixture_world
		[false, true].each do |debug|
			original_debug = $DEBUG
			$DEBUG = debug
			messages = query_player(Player.new('Leeroy Jenkins', world[:foyer]), 'xyzzy')
			$DEBUG = original_debug
			assert_equal ['Invalid Command'], messages
		end
	end

	# TC-1502-060: "say" no-op is truly silent for trailing whitespace too.
	# Derivation: #15 out of scope (no branch for :say extended dispatch).
	def test_say_trailing_whitespace_no_op
		world = fixture_world
		['say', 'say  '].each do |input|
			messages = query_player(Player.new('Leeroy Jenkins', world[:foyer]), input)
			assert_empty messages, "expected no output for '#{input}'"
		end
	end
end
