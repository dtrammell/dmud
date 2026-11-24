###
# Tests for the gem layout, Ruby version floor, and example-world wiring
# (#20, #8, #21 AC).
###

require_relative 'test_helper'

class GemLayoutTest < DMUDTestCase
	# TC-1502-001: .ruby-version pins 3.3 or newer.
	# Derivation: #21 AC "Ruby 3.3+" and "Add a `.ruby-version` file".
	def test_ruby_version_floor
		assert(File.exist?('.ruby-version'), '.ruby-version should exist')
		version = Gem::Version.new(File.read('.ruby-version').strip)
		assert_operator version, :>=, Gem::Version.new('3.3.0')
	end

	# TC-1502-002: README states the minimum Ruby version.
	# Derivation: #21 AC "the README states the minimum".
	def test_readme_states_ruby_floor
		readme = File.read('README.md')
		assert_match(/Ruby.{0,20}3\.3/, readme)
	end

	# TC-1502-003: gemspec required_ruby_version boundary.
	# Derivation: #21 AC "dmud.gemspec sets required_ruby_version >= 3.3".
	def test_gemspec_ruby_boundary
		spec = Gem::Specification.load('dmud.gemspec')
		assert spec.required_ruby_version.satisfied_by?(Gem::Version.new('3.3.0'))
		refute spec.required_ruby_version.satisfied_by?(Gem::Version.new('3.2.9'))
	end

	# TC-1502-004: lib/dmud.rb exists and loads every class file via
	# require_relative.  Derivation: #20 AC and #21 AC "require_relative is
	# used throughout (#8)".
	def test_lib_dmud_loads_classes_with_require_relative
		content = File.read('lib/dmud.rb')
		%w[dmud_object region area gate mobile_object player session].each do |stem|
			assert_match(/require_relative\s+['"]dmud\/#{stem}['"]/, content,
				"lib/dmud.rb should require_relative dmud/#{stem}")
		end
	end

	# TC-1502-005: one class per file, file named after its class.
	# Derivation: #20 AC parenthetical example.
	def test_class_files_named_after_classes
		{
			'DMUDObject'    => 'dmud_object',
			'Region'        => 'region',
			'Area'          => 'area',
			'Gate'          => 'gate',
			'MobileObject'  => 'mobile_object',
			'Player'        => 'player',
			'Session'       => 'session'
		}.each do |class_name, stem|
			path = "lib/dmud/#{stem}.rb"
			assert(File.exist?(path), "#{path} should exist for #{class_name}")
		end
	end

	# TC-1502-006: old flat files are deleted.
	# Derivation: step-4 RULING #8.
	def test_old_flat_files_deleted
		assert_empty Dir.glob('class_*.rb'), 'Old class_*.rb files should be deleted'
		refute File.exist?('dmud.rb'), 'Old root dmud.rb should be deleted'
	end

	# TC-1502-007: mobile_object.rb defines MobileObject, not MovableObject.
	# Derivation: #21 AC "The MobileObject class name is kept."
	def test_mobile_object_class_name_kept
		assert defined?(MobileObject), 'MobileObject should be defined'
		refute defined?(MovableObject), 'MovableObject should not be defined'
	end

	# TC-1502-008: gemspec runtime dependency on reline.
	# Derivation: #20 AC "declares runtime dependency reline".
	def test_gemspec_runtime_dependency_reline
		spec = Gem::Specification.load('dmud.gemspec')
		deps = spec.runtime_dependencies.map(&:name)
		assert_includes deps, 'reline'
	end

	# TC-1502-009: gemspec development dependencies minitest + rake.
	# Derivation: #20 AC "development dependencies minitest and rake".
	def test_gemspec_development_dependencies
		spec = Gem::Specification.load('dmud.gemspec')
		deps = spec.development_dependencies.map(&:name)
		assert_includes deps, 'minitest'
		assert_includes deps, 'rake'
	end

	# TC-1502-010: Gemfile contains only the source line and gemspec.
	# Derivation: #21 AC verbatim.
	def test_gemfile_contents
		lines = File.read('Gemfile').lines.map(&:strip).reject { |l| l.empty? || l.start_with?('#') }
		assert_equal 2, lines.size
		assert_match(/source\s+['"]https:\/\/rubygems\.org['"]/, lines[0])
		assert_equal 'gemspec', lines[1]
	end

	# TC-1502-011: example world lives under examples/ and uses require 'dmud'.
	# Derivation: #20 AC verbatim.
	def test_example_world_uses_gem_require
		path = example_world_path
		content = File.read(path)
		assert_match(/require\s+['"]dmud['"]/, content)
	end

	# TC-1502-012: no stray world-builder script left at repo root.
	# Derivation: step-4 RULING #8.
	def test_no_test_game_at_root
		refute File.exist?('test_game.rb')
	end

	# TC-1502-013: example world runs locally via -Ilib without installing.
	# Derivation: #20 (dev-loop sanity) and the Conventions section's
	# "Location:"-line assertion rule (defect A).
	def test_example_world_runs_under_ilb
		stdout, _stderr, status = run_example_world("move foyer\n")
		assert status.success?, "example world should exit 0, got #{status.exitstatus}"
		assert_includes stdout.lines.map(&:strip), 'Location: Foyer'
	end

	# TC-1502-014: Item/NPC/MOB are reachable via require 'dmud'.
	# Derivation: gem layout completeness (same public API as flat files).
	def test_subclasses_reachable
		assert defined?(Item)
		assert defined?(NPC)
		assert defined?(MOB)
	end

	# TC-1502-015: loading dmud twice is idempotent.
	# Derivation: standard require semantics regression guard.
	def test_double_require_idempotent
		result = require_relative '../lib/dmud'
		refute result, 'second require_relative should return false'
	end
end
