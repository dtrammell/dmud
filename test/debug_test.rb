###
# Tests for $DEBUG output gating (#3).
###

require_relative 'test_helper'

class DebugTest < DMUDTestCase
	# TC-1502-061: MATCH/No match lines absent with $DEBUG off.
	# Derivation: #3 AC and #21 AC.
	def test_match_lines_absent_when_debug_off
		world = fixture_world
		original_debug = $DEBUG
		$DEBUG = false
		stdout = StringIO.new
		original_stdout = $stdout
		$stdout = stdout
		['move foyer', 'look', 'xyzzy'].each do |input|
			query_player(Player.new('Leeroy Jenkins', world[:foyer]), input)
		end
		$stdout = original_stdout
		$DEBUG = original_debug
		output = stdout.string
		refute_match(/MATCH/, output)
		refute_match(/No match/, output)
	end

	# TC-1502-062: MATCH line present with $DEBUG on.
	# Derivation: #3/#21 AC positive direction.
	def test_match_lines_present_when_debug_on
		world = fixture_world
		original_debug = $DEBUG
		$DEBUG = true
		stdout = StringIO.new
		original_stdout = $stdout
		$stdout = stdout
		query_player(world[:player], 'move foyer')
		$stdout = original_stdout
		$DEBUG = original_debug
		assert_match(/MATCH/, stdout.string)
	end

	# TC-1502-063: per-item (ID:...) suffix absent with $DEBUG off.
	# Derivation: #3 AC and #21 AC.
	def test_contents_id_suffix_absent_when_debug_off
		area = Area.new('A')
		Player.new('P', area)
		original_debug = $DEBUG
		$DEBUG = false
		desc = area.describe
		$DEBUG = original_debug
		refute_match(/\(ID:/, desc)
	end

	# TC-1502-064: per-item (ID:...) suffix present with $DEBUG on.
	# Derivation: #3/#21 AC positive direction.
	def test_contents_id_suffix_present_when_debug_on
		area = Area.new('A')
		player = Player.new('P', area)
		area.enter(player)
		original_debug = $DEBUG
		$DEBUG = true
		desc = area.describe
		$DEBUG = original_debug
		assert_includes desc, " (ID:#{player.id})"
	end

	# TC-1502-065: Area's own (ID:...) line stays correctly $DEBUG-gated.
	# Derivation: ARCHITECTURE.md (already correct pre-#21).
	def test_area_id_gated
		area = Area.new('X')
		[false, true].each do |debug|
			original_debug = $DEBUG
			$DEBUG = debug
			desc = area.describe
			$DEBUG = original_debug
			if debug
				assert_match(/Location: X \(ID:/, desc)
			else
				assert_match(/Location: X\n/, desc)
				refute_match(/Location: X \(ID:/, desc)
			end
		end
	end

	# TC-1502-066: Area#initialize's "Initialized" debug line stays gated.
	# Derivation: ARCHITECTURE.md (already correct pre-#21).
	def test_area_initialize_debug_gated
		original_debug = $DEBUG
		[false, true].each do |debug|
			$DEBUG = debug
			stdout = StringIO.new
			original_stdout = $stdout
			$stdout = stdout
			Area.new('X')
			$stdout = original_stdout
			if debug
				assert_match(/Area 'X' \(ID:/, stdout.string)
			else
				assert_empty stdout.string
			end
		end
		$DEBUG = original_debug
	end
end
