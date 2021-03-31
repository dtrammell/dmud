###
# Class Session
#
# This is the game session object.  The Session object interacts with the game for a single Player object.
#

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

	def start
		# Game Loop
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
			command = @player.query

			sleep 1
		end

	end
end
