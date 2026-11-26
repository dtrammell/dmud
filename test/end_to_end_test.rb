###
# Flagship end-to-end tests that pipe real input into the real example
# world process (#113, #114).
###

require_relative 'test_helper'
require 'tmpdir'

class EndToEndTest < DMUDTestCase
	# TC-1502-113: full playthrough through the real example-world process.
	# Derivation: composite of #21 AC bullets and step-4 rulings.
	def test_full_playthrough_inside_repo
		commands = [
			"move foyer\n",
			"move grand hall\n",
			"move foyer\n",
			"move secret room\n",
			"xyzzy\n"
		].join
		stdout, _stderr, status = run_example_world(commands)
		assert status.success?, "expected exit 0, got #{status.exitstatus}"

		location_lines = stdout.lines.map(&:strip).select { |line| line.start_with?('Location: ') }
		assert_equal [
			'Location: Foyer',
			'Location: Grand Hall',
			'Location: Foyer',
			'Location: Secret Room'
		], location_lines

		assert_equal 1, stdout.scan('Invalid Command').size
		assert_equal 'Farewell, Leeroy Jenkins.', stdout.lines.last&.strip
		refute_includes stdout, '\\n'
		refute_match(/MATCH|No match/, stdout)
		refute_match(/\(ID:/, stdout)
	end

	# TC-1502-114: same playthrough, $DEBUG on, from the installed gem.
	# Derivation: same as TC-113 combined with TC-110's outside-repo requirement.
	def test_full_playthrough_from_installed_gem_debug_on
		gem_file = build_gem
		Dir.mktmpdir do |gem_home|
			install_gem(gem_file, gem_home)
			Dir.mktmpdir do |cwd|
				example_path = File.expand_path(example_world_path)
				env = { 'GEM_HOME' => gem_home, 'GEM_PATH' => gem_home }
				commands = [
					"move foyer\n",
					"move grand hall\n",
					"move foyer\n",
					"move secret room\n",
					"xyzzy\n"
				].join
				# Enable $DEBUG via -e rather than -d to avoid Ruby's exception
				# printer adding Reline ENOTTY noise to stdout.
				stdout, stderr, status = Open3.capture3(
					env, 'ruby', '-e', '$DEBUG=true; load ARGV[0]', example_path,
					stdin_data: commands,
					chdir: cwd
				)
				assert status.success?, "expected exit 0, got #{status.exitstatus}, stderr: #{stderr}"

				# With $DEBUG on, Location lines include object IDs.  The debug
				# dump also prints a bare "Location: <name>" line; filter it out
				# by requiring the (ID:) suffix that Area#describe adds under
				# $DEBUG.
				location_lines = stdout.lines.map(&:strip)
					.select { |line| line.start_with?('Location: ') && line.include?('(ID:') }
					.map { |line| line.sub(/\s+\(ID:[^)]+\)\z/, '') }
				assert_equal [
					'Location: Foyer',
					'Location: Grand Hall',
					'Location: Foyer',
					'Location: Secret Room'
				], location_lines

				assert_equal 1, stdout.scan('Invalid Command').size
				assert_equal 'Farewell, Leeroy Jenkins.', stdout.lines.last&.strip
				assert_match(/MATCH/, stdout)
				assert_match(/\(ID:/, stdout)
			end
		end
	ensure
		Dir.glob('dmud-*.gem').each { |f| File.delete(f) }
	end

	private

	def build_gem
		stdout, stderr, status = Open3.capture3('gem', 'build', 'dmud.gemspec')
		assert status.success?, "gem build failed: #{stderr}"
		Dir.glob('dmud-*.gem').first
	end

	def install_gem(gem_file, gem_home)
		stdout, stderr, status = Open3.capture3(
			'gem', 'install', '--install-dir', gem_home, gem_file, '--no-document'
		)
		assert status.success?, "gem install failed: #{stderr}"
	end
end
