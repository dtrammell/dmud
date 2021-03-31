require 'readline'

###
# Class Player
#
# The Player object represents a player in the game.  Players are able to move around and interact
# with Areas and Objects via their available command index.  Players are queried for input via the
# 'query' method which then processes the command index for a match and executes the 'command'
# method if a valid command is matched.
#

class Player < MobileObject
	# Initialization
	def initialize(
	       name,
			 location,
			 description = ''
		 )
		super

		@carryable = false

		@commands = {
			:move => {
				:type  => :extended,
				:match => /^m |^move |^go |^walk |^run /,
			},
			:say => {
				:type  => :extended,
				:match => /^s |^say |^talk |^yell /,
			},
			:look => {
				:type  => :extended,
				:match => /^l |^look |^inspect /,
			},
			:inventory => {
				:type  => :extended,
				:match => /^i |^inventory /,
			},
			:somecommand => {
				:type => :generic,
				:match => //,
				:method => 'somemethod',
				:args => 'args'
			}
		}

		# Create a separate list of just the commands for Readline auto-completion
		@commandlist = []
		@commands.each do | key, hash |
			@commandlist << key.to_s
		end

		# Set up Readline auto-completion
		Readline.completion_append_character = ' '
		Readline.completion_proc = proc { |s| @commandlist.grep(/^#{Regexp.escape(s)}/) }
	end

	# Incoming message processor for messages received by the MobileObject
	def message( message )
		#TODO: Send these messages to the player's console, puts for now
		puts message
	end

	# Query Player for input
	def query
		@prompt ||= "\n%s: Command> " % @metadata[:name]

		# Read Player input
		input = Readline.readline( @prompt, true )

#		input = ARGF.gets
		puts "Input: '%s'" % input if $DEBUG

		# Match input against command index
		validcommand = false
		@commands.each do | key, hash |
			puts "Processing command '%s'..." % key.to_s if $DEBUG
			if input.match( hash[:match] )
				puts "  MATCH!!! (%s vs. %s)" % [ input, hash[:match].to_s ]
				self.command( key, hash, input.chomp )
				validcommand = true
			else
				puts "  No match (%s vs. %s)" % [ input, hash[:match].to_s ]
			end
		end

		self.message "Invalid Command" if validcommand == false	
	end

	# Process a Player Command
	def command( command, hash, input )

		case hash[:type]
		# Process Generic Command
		when :generic
		# Process Extended Commands
		when :extended
			case command
			# Move Command
			when :move
				# Extract the Area name from input (everything after the first whitespace)
				area = input.match(/[^\s]\s(.*)/).captures[0]
				puts "Moving to Area '%s'" % area if $DEBUG

      	   # Lookup the destination Area's Gate by name
         	gate = self.location.gate_lookup( area )

	         # Move object to the target Area
   	      if gate
      	      return self.move( gate )
         	else
            	puts "Area '%s' not accessible from here." % area
					return false
   	      end
			end
		# Process Custom Commands
		when :custom
			# TODO: Design and build custom command (macros) system for Players to register their own
		end
	end

	# TODO: Player command to register/delete custom commands from index

end

