###
# Class MobileObject
#
# This is the root class for all Game Objects, such as players, other characters, items, etc.
# Basically, anything that is not an Area or a Gate.  Objects may or may not be able to move
# around.  Objects may or may not be able to be acquired by other Objects and carried around.
###

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
# Specialized Game Objects
###

# NPC MobileObject
class NPC < MobileObject
	# Initialization
	# Forwards name, location, and optional description to MobileObject,
	# then marks this object as non-carryable.
	def initialize(*args)
		super(*args)

		@carryable = false
	end
end

# Monster Object MobileObject
class MOB < MobileObject
	# Initialization
	# Forwards name, location, and optional description to MobileObject,
	# then marks this object as non-carryable.
	def initialize(*args)
		super(*args)

		@carryable = false
	end
end

# Carryable Item
class Item < MobileObject
	# Initialization
	# Forwards name, location, and optional description to MobileObject,
	# then marks this object as carryable.
	def initialize(*args)
		super(*args)

		@carryable = true
	end
end
