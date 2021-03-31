###
# Class Region
#
# A Region object is a container for Areas.  Regions logically segregate groups of Areas.  A game server
# will usually only house one Region for its local Areas, but it is possible to define multiple Regions
# for various organizationsl purposes.
#

class Region < DMUDObject
	attr_accessor :metadata

	# Initialization
	def initialize(
	       name        = 'New Region',
			 description = ''
	   )
		super()

		# Instance Variables
		@metadata = {
			:name        => name,
			:description => description
		}
		@areas = []
	end

	# Utility: add_area
	def add_area( area )
		# TODO: Check for duplicates
		@areas << area

		return true
	end
end
