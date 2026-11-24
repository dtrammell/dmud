require 'reline'

###
# Class: Player
#
# The Player object represents a player in the game.  Players are able to move around and
# interact with Areas and Objects via their available command index.  Players are queried
# for input via the 'query' method which then processes the command index for a match and
# executes the 'command' method if a valid command is matched.
###

class Player < MobileObject
	# Command table.
	#
	# Each entry maps a command symbol to a hash with:
	#   :type  => :extended or :generic
	#   :match => Regexp that must match the stripped input line
	#
	# Regexes use word boundaries (\b) and case-insensitive matching so that
	# bare keywords such as "look" or "i" match, while prefix collisions such
	# as "lookout" or "items" do not.
	COMMAND_PATTERNS = {
		:move => {
			:type  => :extended,
			:match => /^(m|move|go|walk|run)\b/i,
		},
		:say => {
			:type  => :extended,
			:match => /^(s|say|talk|yell)\b/i,
		},
		:look => {
			:type  => :extended,
			:match => /^(l|look|inspect)\b/i,
		},
		:inventory => {
			:type  => :extended,
			:match => /^(i|inventory)\b/i,
		},
	}.freeze

	# Initialization
	def initialize(
		name,
		location,
		description = ''
	)
		super

		@carryable = false

		@commands = COMMAND_PATTERNS.dup

		# Create a separate list of just the commands for Reline auto-completion
		@commandlist = @commands.keys.map(&:to_s)

		# Set up Reline auto-completion
		Reline.completion_append_character = ' '
		Reline.completion_proc = proc { |s| @commandlist.grep(/^#{Regexp.escape(s)}/) }
	end

	# Incoming message processor for messages received by the MobileObject.
	# Player is the only MobileObject subclass that actually renders messages
	# to the player's console today.
	def message( message )
		puts message
	end

	# Query the player for a command, match it against the command index, and
	# dispatch the first matching command.
	#
	# Side effects: reads a line from stdin via Reline, prints a blank line
	# followed by the prompt, and may print "Invalid Command" or dispatch a
	# command that produces its own output.
	def query
		# Print the blank line separately from the prompt so the prompt stays
		# a single line and no literal "\n" characters appear in the output.
		puts

		# Read Player input.  Reline.readline returns nil on EOF; Session#start
		# catches the :eof sentinel and exits cleanly.
		input = Reline.readline( "%s: Command> " % @metadata[:name], true )
		return :eof if input.nil?

		puts "Input: '%s'" % input if $DEBUG

		# Strip leading/trailing whitespace before matching.
		input = input.strip

		# Match input against command index, stopping at the first match.
		matched = false
		@commands.each do | key, hash |
			puts "Processing command '%s'..." % key.to_s if $DEBUG
			if input.match( hash[:match] )
				puts "  MATCH!!! (%s vs. %s)" % [ input, hash[:match].to_s ] if $DEBUG
				self.command( key, hash, input )
				matched = true
				break
			else
				puts "  No match (%s vs. %s)" % [ input, hash[:match].to_s ] if $DEBUG
			end
		end

		self.message "Invalid Command" unless matched
	end

	# Process a matched Player command.
	#
	# Inputs:
	#   command => the command symbol that matched
	#   hash    => the command table entry for that symbol
	#   input   => the full, stripped input line
	def command( command, hash, input )

		case hash[:type]
		# Process Extended Commands
		when :extended
			case command
			# Move Command
			when :move
				# Remove the matched keyword, leaving the target area name.
				area = input.sub(hash[:match], '').strip

				if area.empty?
					self.message "Move where?"
					return false
				end

				puts "Moving to Area '%s'" % area if $DEBUG

				# Lookup the destination Area's Gate by name
				gate = self.location.gate_lookup( area )

				# Move object to the target Area
				if gate
					return self.move( gate )
				else
					self.message "Area '%s' not accessible from here." % area
					return false
				end
			# :say, :look, and :inventory are intentionally no-ops today (#15
			# is out of scope).  Matching them and doing nothing is the
			# unchanged behavior, now reachable because of the word-boundary
			# regex fix.
			when :say, :look, :inventory
				return true
			end
		# Process Custom Commands
		when :custom
			# TODO: Design and build custom command (macros) system for Players to register their own
		end
	end

	# TODO: Player command to register/delete custom commands from index

end
