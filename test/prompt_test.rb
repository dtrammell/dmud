###
# Tests for prompt format (#6).
###

require_relative 'test_helper'

class PromptTest < DMUDTestCase
	# TC-1502-077: no literal backslash-n text anywhere in one turn's output.
	# Derivation: #21 AC "No literal \n."
	def test_no_literal_backslash_n
		stdout, _stderr, status = run_example_world("move foyer\n")
		assert status.success?
		refute_includes stdout, '\\n'
	end

	# TC-1502-078: the prompt line itself is single-line text.
	# Derivation: #21 AC "the prompt is a single line" + player-name convention.
	def test_prompt_line_single_line
		stdout, _stderr, _status = run_example_world("move foyer\n")
		# Use chomp (not rstrip) so the trailing space that belongs to the
		# prompt is preserved while the newline is removed.
		prompt_lines = stdout.lines.select { |line| line.include?('Command>') }.map(&:chomp)
		assert_includes prompt_lines, 'Leeroy Jenkins: Command> '
	end

	# TC-1502-079: the blank line before the prompt is a separate, real newline.
	# Derivation: #21 AC "the blank line printed separately".
	def test_blank_line_before_prompt
		stdout, _stderr, _status = run_example_world("move foyer\n")
		lines = stdout.lines
		prompt_index = lines.index { |line| line.include?('Command>') }
		refute_nil prompt_index
		assert_equal "\n", lines[prompt_index - 1]
	end

	# TC-1502-080: the prompt is drawn once per turn on a non-interactive pipe.
	# Derivation: #6 bug fix (weak, pipe-capturable form).
	def test_prompt_once_per_turn
		stdout, _stderr, _status = run_example_world("move foyer\n")
		prompt_count = stdout.scan(/Leeroy Jenkins: Command>/).size
		assert_equal 1, prompt_count
	end
end
