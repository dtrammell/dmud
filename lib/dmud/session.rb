###
# Class: Session
#
# This is the game session object.  The Session object interacts with the game for a single
# Player object.
###

class Session < DMUDObject
	attr_reader   :id, :player
	attr_accessor :metadata

	# Initialization
	def initialize( player, start_location )
		super()

		# Instance Variables
		@metadata = {
			:name    => 'My Session',
			:updated => Time.now,
			:saved   => nil
		}
		@player = player
		@player.location = start_location

		self.start
	end

	# Main game loop.  Prints the current area's visible exits, prompts the
	# player for a command, and repeats.  EOF (Ctrl-D) and Interrupt (Ctrl-C)
	# both exit cleanly with status 0 after printing a goodbye message.
	def start
		loop do
			# List Known Gates
			message = "Exits:\n"
			@player.location.gates.each do | gate |
				gate.areas.each do | area |
					if area[:visible]
						message << "  > %s\n" % area[:object].metadata[:name] if area[:object] != @player.location
					end
				end
			end
			@player.message( message )

			# Get Player Input and Process it
			result = @player.query

			# EOF sentinel: clean exit.
			if result == :eof
				exit_cleanly( reason: "EOF (end of input)" )
				return
			end

			sleep 1
		end
	rescue Interrupt => e
		exit_cleanly( exception: e )
	end

	private

	# Print a goodbye and exit with status 0.  When $DEBUG is on, also print
	# the exit reason, a backtrace, and the current session/player state.
	#
	# Inputs:
	#   reason    => optional String describing why the session is ending
	#                (used for EOF, which has no exception object)
	#   exception => optional Exception object (used for Interrupt/Ctrl-C)
	def exit_cleanly( reason: nil, exception: nil )
		if $DEBUG
			if reason
				puts reason
				puts caller
			end

			if exception
				puts "%s: %s" % [ exception.class, exception.message ]
				puts exception.backtrace
			end

			puts "Session: %s" % @metadata[:name]
			puts "Player:  %s" % @player.metadata[:name]
			puts "Location: %s" % @player.location.metadata[:name]
		end

		puts "Farewell, %s." % @player.metadata[:name]
		exit 0
	end
end
