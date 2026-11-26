###
# Tests for require_relative / working-directory independence (#8).
###

require_relative 'test_helper'
require 'tmpdir'

class RequireRelativeTest < DMUDTestCase
	# TC-1502-016: no require './...' left in lib/.
	# Derivation: #21 AC "require_relative is used throughout (#8)".
	def test_no_require_dot_slash_in_lib
		Dir.glob('lib/**/*.rb').each do |path|
			content = File.read(path)
			refute_match(/require\s+['"]\.\//, content, "#{path} should not use require './...'")
		end
	end

	# TC-1502-017: lib/dmud.rb is loadable from any working directory.
	# Derivation: #8 repro scenario, inverted.
	def test_loadable_from_outside_repo
		# test/ is one level below the repo root, so the library is at ../lib.
		lib_path = File.expand_path('../lib/dmud.rb', __dir__)
		Dir.mktmpdir do |tmpdir|
			stdout, stderr, status = Open3.capture3(
				'ruby', '-e',
				"require_relative '#{lib_path}'; puts 'OK'",
				chdir: tmpdir
			)
			assert status.success?, "expected success, stderr: #{stderr}"
			assert_equal "OK\n", stdout
		end
	end

	# TC-1502-018: example script does not re-require class files individually.
	# Derivation: #8 suggested-fix line.
	def test_example_no_individual_requires
		content = File.read(example_world_path)
		assert_equal 1, content.scan(/require\s+['"]dmud['"]/).size
		refute_match(/require(_relative)?\s+['"]\.?\/(class_|dmud\/)/, content)
	end

	# TC-1502-019: securerandom stays a plain stdlib require, not a gem dependency.
	# Derivation: #21 AC "Why reline is declared" paragraph, by contrast.
	def test_securerandom_not_a_gem_dependency
		spec = Gem::Specification.load('dmud.gemspec')
		refute_includes spec.runtime_dependencies.map(&:name), 'securerandom'
	end
end
