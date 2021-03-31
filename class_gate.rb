###
# Class: Gate
#
# A Gate is an entrance, exit, or both, to an Area.  A Gate allows players or other objects to enter or exit
# an Area by interacting with it.  Gates can be locked or unlocked, or have other prerequisites to being
# able to use them.  A Gate will link one Area to at least one other, therefore two (or more) Areas will share a Gate.
# Areas that share a gate may be local to a single server, or reside on different servers.
#

class Gate < DMUDObject
	attr_reader   :metadata, :areas
	attr_accessor :game_entrance, :visible

	# Initialization
	def initialize(
	       name = 'New Gate'
		)
		super()

		# Instance Variables
		@metadata = {
			:name        => name,
			:description => ''
		}
		@game_entrance = false
		@visible       = true
		@traversable   = true
		@locked        = false
		@areas         = []

	end

	# Enter this Gate
	def enter( object )
		@object = object
		response = ''

		# If the Gate is a game entrance, there is no source area
		if @game_entrance
			# Fudge the GameObject's current location to be one of the connected areas 
			@object.location = @areas[0][:object]
		end

		# Verify that the GameObject is leaving a valid connected source Area or it's a game entrance
		@source_area = nil
		@areas.each do | area |
			if area[:object] == @object.location
				@source_area = @object.location
			end
		end
		if !@source_area	
			response << "ERROR: Incoming object does not source from a connected Area"
			raise response
		end

		# Verify that this gate can be traversed 
		if !@traversable
			response << "Gate '%s' cannot be traversed.\n" % @metadata[:name]
			@object.message response
			raise response
		end

		# Do anything that happens while inside the gate
		self.gate_specific

		# Do anything related to ingress here
		@object.message "You have entered the '%s' Gate" % @metadata[:name]

		# Determine destination area for egress
		case
		# No Areas configured
		when @areas.count < 1
			response << "ERROR: This Gate has no Areas configured."
			raise response
		# Only one area configured
		when @areas.count == 1
			@destination_area = @source_area
			response << "This Gate seems to only return to the Area you're leaving...\n"
		# When there is only one possible destination (2 Areas) 
		when @areas.count == 2
			@areas.each do | area |
				@destination_area = area[:object] if area[:object] != @source_area
			end
			response << "You traverse the gate...\n"
		# When there is more than one possible destination
		when @areas.count > 2
			#TODO: menu for choices (@object.query)
		end
		@object.message response

		# Exit the Gate
		self.exit( @destination_area )
	end

	# Exit this Gate
	def exit( destination )
		# Set the destination location on the object
		@object.location = destination

		# Do anything related to egress here
		@object.message "You have exited the '%s' Gate" % @metadata[:name]

		# Enter the Area
		destination.enter( @object )

		return true
	end

	# Specific Gate actions that happen while traversing the gate
	# (this should be overridden by any inhereting classes)
	def gate_specific
	end

	# Utility: Add Area
	def add_area( area, visibility )
		@areas << {
			:object => area,
			:visible => visibility
		}
	end

end

