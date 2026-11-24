###
# Tests for exit handling: EOF and Ctrl-C with/without $DEBUG (#5).
###

require_relative 'test_helper'

class ExitTest < DMUDTestCase
	# TC-1502-067: EOF, $DEBUG off: exit 0 + exact goodbye, no stack trace.
	# Derivation: #5 scope-extension comment + RULING #6.
	def test_eof_debug_off
		stdout, stderr, status = run_example_world("move foyer\n")
		assert status.success?, "expected exit 0, got #{status.exitstatus}"
		assert_equal 'Farewell, Leeroy Jenkins.', stdout.lines.last&.strip
		combined = stdout + stderr
		refute_match(/NoMethodError|Interrupt|\.rb:\d+/, combined)
	end

	# TC-1502-068: EOF, $DEBUG on: exit 0 + pinned debug dump + exact goodbye.
	# Derivation: RULING #3 + #5 comment + RULING #6.
	def test_eof_debug_on
		stdout, stderr, status = run_example_world("move foyer\n", debug: true)
		assert status.success?, "expected exit 0, got #{status.exitstatus}"
		combined = stdout + stderr
		assert_match(/EOF \(end of input\)/, combined)
		assert_match(/\.rb:\d+/, combined)
		assert_match(/Leeroy Jenkins|My Session/, combined)
		# The goodbye must be the final game-produced stdout line; stderr may
		# contain Ruby $DEBUG exception-printer noise after the process exits.
		assert_equal 'Farewell, Leeroy Jenkins.', stdout.lines.last&.strip
	end

	# TC-1502-069: Ctrl-C, $DEBUG off: exit 0 + exact goodbye, no stack trace.
	# Derivation: #5 scope-extension comment + RULING #6.
	def test_ctrl_c_debug_off
		stdout, stderr, status = spawn_and_signal("move foyer\n")
		assert status.success?, "expected exit 0, got #{status.exitstatus}"
		assert_equal 'Farewell, Leeroy Jenkins.', stdout.lines.last&.strip
		combined = stdout + stderr
		refute_match(/Interrupt|\.rb:\d+/, combined)
	end

	# TC-1502-070: Ctrl-C, $DEBUG on: exit 0 + pinned debug dump + exact goodbye.
	# Derivation: RULING #3 + RULING #6.
	def test_ctrl_c_debug_on
		stdout, stderr, status = spawn_and_signal("move foyer\n", debug: true)
		assert status.success?, "expected exit 0, got #{status.exitstatus}"
		combined = stdout + stderr
		assert_match(/Interrupt/, combined)
		assert_match(/\.rb:\d+/, combined)
		assert_match(/Leeroy Jenkins|My Session/, combined)
		# The goodbye must be the final game-produced stdout line; stderr may
		# contain Ruby $DEBUG exception-printer noise after the process exits.
		assert_equal 'Farewell, Leeroy Jenkins.', stdout.lines.last&.strip
	end

	# TC-1502-071: EOF as the very first input.
	# Derivation: #5 boundary + RULING #6.
	def test_eof_first_input
		stdout, stderr, status = run_example_world('')
		assert status.success?, "expected exit 0, got #{status.exitstatus}"
		assert_equal 'Farewell, Leeroy Jenkins.', stdout.lines.last&.strip
	end

	# TC-1502-072: Ctrl-C as the very first input.
	# Derivation: #5 boundary + RULING #6.
	def test_ctrl_c_first_input
		stdout, stderr, status = spawn_and_signal('')
		assert status.success?, "expected exit 0, got #{status.exitstatus}"
		assert_equal 'Farewell, Leeroy Jenkins.', stdout.lines.last&.strip
	end

	# TC-1502-073: EOF and Ctrl-C produce the same goodbye string.
	# Derivation: RULING #6 (one fixed format string).
	def test_goodbye_string_identical
		eof_out, _, _ = run_example_world("move foyer\n")
		sig_out, _, _ = spawn_and_signal("move foyer\n")
		assert_equal eof_out.lines.last&.strip, sig_out.lines.last&.strip
	end

	# TC-1502-074: $DEBUG-off exit paths contain none of the debug-dump markers.
	# Derivation: #21 AC negative direction + RULING #3.
	def test_debug_off_no_dump_markers
		eof_combined = run_example_world("move foyer\n").then { |out, err, _| out + err }
		sig_combined = spawn_and_signal("move foyer\n").then { |out, err, _| out + err }
		[eof_combined, sig_combined].each do |combined|
			refute_match(/EOF \(end of input\)/, combined)
			refute_match(/Interrupt/, combined)
			refute_match(/\.rb:\d+/, combined)
			# "Location:" also appears in ordinary Area#describe output, so the
			# dump-marker check is limited to the Session/Player lines emitted
			# only by exit_cleanly.
			refute_match(/Session: My Session/, combined)
			refute_match(/Player:  Leeroy Jenkins/, combined)
		end
	end

	private

	# Spawn the example world, optionally with $DEBUG enabled via -e, send
	# input, then signal SIGINT while it waits for the next line.
	# Returns [stdout, stderr, status].
	def spawn_and_signal(input, debug: false)
		cmd = if debug
			['ruby', '-Ilib', '-e', '$DEBUG=true; load ARGV[0]', example_world_path]
		else
			['ruby', '-Ilib', example_world_path]
		end
		stdout = ''
		stderr = ''
		status = nil

		Timeout.timeout(30) do
			Open3.popen3(*cmd) do |stdin, stdout_io, stderr_io, wait_thr|
				stdin.write(input)
				# Let the process finish the first turn's sleep and reach the
				# blocking read before signalling.
				sleep 2.5
				Process.kill('INT', wait_thr.pid)
				stdin.close
				stdout = stdout_io.read
				stderr = stderr_io.read
				status = wait_thr.value
			end
		end

		[stdout, stderr, status]
	end
end
