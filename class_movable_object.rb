###
# Class MobileObject
#
# This is the root Class for all Game Objects, such as players, other characters, items, etc.  Basically, anything that is not
# an Area or a Gate.  Objects may or may not be able to move around.  Objects may or may not be able to be acquired by other
# Objects and carried around.
#

class MobileObject < DMUDObject
	attr_accessor :metadata, :location

	# Initialization
	def initialize(
		    name,
			 location,
			 description = ''
		 )
		super()

		# Instance Variables
		@metadata = {
			:name        => name,
			:description => description 
		}
		@location  = location
		@movable   = true
		@carryable = true
	end

	# Incoming message processor for messages received by the MobileObject
	def message( message )
	end

	# Move the MobileObject
	def move( gate )
		# Exit the Area via the Gate
		self.location.exit( self, gate )
	end
end

###
# Specialized GameOjbects
#

# NPC MobileObject
class NPC < MobileObject
	# Initialization
	def initialize
		super

		@carryable = false
	end
end

# Monster Object MobileObject
class MOB < MobileObject
	# Initialization
	def initialize
		super

		@carryable = false
	end
end

# Carryable Item
class Item < MobileObject
	# Initialization
	def initialize
		super

		@carryable = true
	end
end

