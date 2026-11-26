###
# Tests for gem packaging seam and dependency accuracy (#8, #20).
###

require_relative 'test_helper'
require 'tmpdir'

class PackagingTest < DMUDTestCase
	# TC-1502-107: gem build dmud.gemspec succeeds.
	# Derivation: #20 AC "gem build ... works locally".
	def test_gem_build_succeeds
		stdout, stderr, status = Open3.capture3('gem', 'build', 'dmud.gemspec')
		assert status.success?, "gem build failed: #{stderr}"
		assert Dir.glob('dmud-*.gem').any?, 'expected a .gem file to be produced'
	ensure
		Dir.glob('dmud-*.gem').each { |f| File.delete(f) }
	end

	# TC-1502-108: gem install into an isolated temp GEM_HOME succeeds.
	# Derivation: #20 AC "gem install ... works locally".
	def test_gem_install_into_isolated_home
		gem_file = build_gem
		Dir.mktmpdir do |gem_home|
			stdout, stderr, status = Open3.capture3(
				'gem', 'install', '--install-dir', gem_home, gem_file, '--no-document'
			)
			assert status.success?, "gem install failed: #{stderr}"
			assert Dir.glob("#{gem_home}/gems/dmud-*").any?
		end
	ensure
		Dir.glob('dmud-*.gem').each { |f| File.delete(f) }
	end

	# TC-1502-109: require 'dmud' works from outside the repo using only the
	# installed gem.
	# Derivation: #20 AC "require 'dmud' works from outside the repo" + #8.
	def test_require_from_outside_repo
		gem_file = build_gem
		Dir.mktmpdir do |gem_home|
			install_gem(gem_file, gem_home)
			Dir.mktmpdir do |cwd|
				env = { 'GEM_HOME' => gem_home, 'GEM_PATH' => gem_home }
				stdout, stderr, status = Open3.capture3(
					env, 'ruby', '-e', "require 'dmud'; puts DMUDObject.new.id",
					chdir: cwd
				)
				assert status.success?, "require failed: #{stderr}"
				assert_match(/\A[0-9a-f-]{36}\n\z/, stdout)
			end
		end
	ensure
		Dir.glob('dmud-*.gem').each { |f| File.delete(f) }
	end

	# TC-1502-110: running the example world from outside the repo via the
	# installed gem.
	# Derivation: #20 AC + #8 + Conventions "Location:"-line assertion.
	def test_example_world_from_outside_repo
		gem_file = build_gem
		Dir.mktmpdir do |gem_home|
			install_gem(gem_file, gem_home)
			Dir.mktmpdir do |cwd|
				example_path = File.expand_path(example_world_path)
				env = { 'GEM_HOME' => gem_home, 'GEM_PATH' => gem_home }
				stdout, stderr, status = Open3.capture3(
					env, 'ruby', example_path,
					stdin_data: "move foyer\n",
					chdir: cwd
				)
				assert status.success?, "example world failed: #{stderr}"
				assert_includes stdout.lines.map(&:strip), 'Location: Foyer'
			end
		end
	ensure
		Dir.glob('dmud-*.gem').each { |f| File.delete(f) }
	end

	# TC-1502-111: gemspec runtime dependencies are a superset of bare
	# require calls in lib/.
	# Derivation: required coverage "The gemspec's declared deps match what
	# the code actually requires".
	def test_gemspec_deps_match_requires
		spec = Gem::Specification.load('dmud.gemspec')
		declared = spec.runtime_dependencies.map(&:name)
		stdlib_allowlist = %w[securerandom]
		required = Dir.glob('lib/**/*.rb').flat_map do |path|
			File.readlines(path).select { |line| line =~ /^\s*require\s+['"]/ }.flat_map do |line|
				line.scan(/require\s+['"]([^'"]+)['"]/).flatten
			end
		end.uniq - stdlib_allowlist
		required.each do |name|
			assert_includes declared, name, "#{name} is required but not declared in gemspec"
		end
	end

	# TC-1502-112: code requires reline and calls Reline.readline directly;
	# readline/Readline absent.
	# Derivation: RULING #10 verbatim.
	def test_reline_usage_no_readline
		lib_and_examples = Dir.glob('lib/**/*.rb') + Dir.glob('examples/**/*.rb')
		lib_and_examples.each do |path|
			content = File.read(path)
			refute_match(/require\s+['"]readline['"]/, content, "#{path} should not require readline")
			refute_match(/\bReadline\b/, content, "#{path} should not reference Readline")
		end
		player_content = File.read('lib/dmud/player.rb')
		assert_match(/require\s+['"]reline['"]/, player_content)
		assert_match(/Reline\.readline/, player_content)
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
