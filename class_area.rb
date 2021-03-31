###
# Class: Area
#
# The Area object.  This object represents a distinct area that can be described in the game, such
# as a room in a castle, an open field, a forest grove, etc.  Areas have gates (or exits in MUD
# nomenclature) which provide an entrance, exit, or both, to the area.  Areas may have unique
# commands relative to the area.  Areas can contain other objects, including players.
#

class Area < DMUDObject
	attr_accessor :metadata, :gates, :contents

	# Initialization
	def initialize(
			name        = 'New Area',
	      region      = nil,
			description = ''
		)
		super()

		# Add the Area to the Region if one was specified
		region.add_area( self ) if region

		# Instance Variables
		@metadata = {
			:name        => name,
			:description => description
		}
		@proximity   = :local
		@gates       = []
		@contents    = []

		# DEBUG Output
		if $DEBUG
			puts "Area '%s' (ID:%s) Initialized" % [ @metadata[:name], @id ]
		end
	end

	# Enter the Area
	def enter( object )
		# Set the object's location
		object.location = self
		# Add the object to the Area's contents
		@contents << object
		# Message the object
		object.message self.describe

		return true
	end

	# Exit the Area
	def exit( object, gate )
		# Remove the object from the Area's contents
		@contents.delete( object )
		
		# Enter the Gate
		gate.enter( object )

		return true
	end

	def describe
		desc = ''
		if !$DEBUG
			desc << "\033[2J" # Clear the Screen
			desc << "\033[H" # Move cursor to HOME position
		end
		desc << "Location: %s" % @metadata[:name]
		desc << " (ID:%s)" % @id if $DEBUG
		desc << "\n\n" + @metadata[:description] + "\n"
		desc << "\n%s contains:\n" % @metadata[:name] if @contents.count > 0
		@contents.each do | obj |
			desc << "  * %s" % obj.metadata[:name]
			desc << " (ID:%s)" % obj.id
			desc << "\n"
		end
		desc << "\n"

		return desc
	end

	# Utility: Add Gate
	def add_gate( gate, visible = true )
		# Add the gate to the Area's Gates List
		@gates << gate
		
		# Add the Area to the Gate's Areas List
		gate.add_area( self, visible )

		# Success
		return true
	end

	# Utility: Gate Lookup
	def gate_lookup( name )
		# Traverse the list of the Area's Gates
		@gates.each do | gate |
			# Traverse the list of each gate's other Areas
			gate.areas.each do | area |
				# Return the Gate if the requested Area is connected to it
				return gate if area[:object].metadata[:name].downcase == name.downcase
			end
		end

		# No gate found
		return nil
	end

end

