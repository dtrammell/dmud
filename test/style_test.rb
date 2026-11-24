###
# Tests for style cleanups (#9).
###

require_relative 'test_helper'

class StyleTest < DMUDTestCase
	# TC-1502-099: no leading-space indentation under lib/, examples/, or test/.
	# Derivation: RULING #9 (tabs only in all three directories).
	def test_tabs_only_indentation
		%w[lib examples test].each do |dir|
			Dir.glob("#{dir}/**/*.rb").each do |path|
				File.readlines(path).each_with_index do |line, idx|
					# Strip the trailing newline before examining indentation;
					# otherwise an empty line appears to have a newline as its
					# leading whitespace.
					leading = line.chomp[/^\s*/]
					assert_match(/\A\t*\z/, leading,
						"#{path}:#{idx + 1} has non-tab leading whitespace")
				end
			end
		end
	end

	# TC-1502-100: .editorconfig exists at repo root.
	# Derivation: #21 AC "an .editorconfig".
	def test_editorconfig_exists
		assert File.exist?('.editorconfig')
	end

	# TC-1502-101: .editorconfig declares indent_style = tab for Ruby files.
	# Derivation: RULING #9 (tabs only).
	def test_editorconfig_tabs
		content = File.read('.editorconfig')
		assert_match(/\[\*\]|\[\*\.rb\]/, content)
		assert_match(/^indent_style\s*=\s*tab$/, content)
	end

	# TC-1502-102: typo "GameOjbects" is gone.
	# Derivation: #9 body, listed typo verbatim.
	def test_gameobjects_typo_gone
		Dir.glob('lib/**/*.rb').each do |path|
			refute_includes File.read(path), 'GameOjbects'
		end
	end

	# TC-1502-103: typo "###i" stray-i comment marker is gone.
	# Derivation: #9 body, "###i has a stray 'i'."
	def test_stray_i_comment_marker_gone
		content = File.read('lib/dmud/dmud_object.rb')
		refute_includes content, '###i'
	end

	# TC-1502-104: typo "organizationsl" -> "organizational".
	# Derivation: #9 body, verbatim.
	def test_organizational_typo_fixed
		content = File.read('lib/dmud/region.rb')
		assert_includes content, 'organizational'
		refute_includes content, 'organizationsl'
	end

	# TC-1502-105: comment references to nonexistent "GameObject" class gone in Gate file.
	# Derivation: #9 body, "Gate#enter comments refer to 'GameObject', which isn't a class."
	def test_gameobject_comment_reference_gone
		content = File.read('lib/dmud/gate.rb')
		refute_includes content, 'GameObject'
	end
end
