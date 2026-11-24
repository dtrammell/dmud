###
# Class: Gate
#
# A Gate is an entrance, exit, or both, to an Area.  A Gate allows players or other objects
# to enter or exit an Area by interacting with it.  Gates can be locked or unlocked, or have
# other prerequisites to being able to use them.  A Gate will link one Area to at least one
# other, therefore two (or more) Areas will share a Gate.  Areas that share a gate may be
# local to a single server, or reside on different servers.
###

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

	# Enter this Gate from the object's current Area and deliver it to the
	# destination Area.
	#
	# Traversal output order (per issue #21, RULING #7):
	#   1. clear-screen / cursor-home ANSI codes
	#   2. [$DEBUG] "You have entered the '<name>' Gate [<connection_label>]"
	#   3. gate_specific output
	#   4. "You step through the <name>."
	#   5. [$DEBUG] "You have exited the '<name>' Gate [<connection_label>]"
	#   6. destination Area description
	def enter( object )
		@object = object

		# Clear the screen at the start of traversal so gate messages are not
		# wiped by the upcoming Area#describe call.
		@object.message "\033[2J\033[H"

		# If the Gate is a game entrance, there is no source area
		if @game_entrance
			# Fudge the MobileObject's current location to be one of the connected areas
			@object.location = @areas[0][:object]
		end

		# Verify that the MobileObject is leaving a valid connected source Area or it's a game entrance
		@source_area = nil
		@areas.each do | area |
			if area[:object] == @object.location
				@source_area = @object.location
			end
		end
		if !@source_area
			raise "ERROR: Incoming object does not source from a connected Area"
		end

		# Verify that this gate can be traversed
		if !@traversable
			response = "Gate '%s' cannot be traversed.\n" % @metadata[:name]
			@object.message response
			raise response
		end

		# Do anything that happens while inside the gate (subclass hook).
		self.gate_specific

		# Do anything related to ingress here
		@object.message "You have entered the '%s' Gate [%s]" % [ @metadata[:name], connection_label ] if $DEBUG

		# Determine destination area for egress
		case
		# No Areas configured
		when @areas.count < 1
			raise "ERROR: This Gate has no Areas configured."
		# Only one area configured (loop gate)
		when @areas.count == 1
			@destination_area = @source_area
			@object.message "This Gate seems to only return to the Area you're leaving..."
		# When there is only one possible destination (2 Areas)
		when @areas.count == 2
			@areas.each do | area |
				@destination_area = area[:object] if area[:object] != @source_area
			end
		# When there is more than one possible destination
		when @areas.count > 2
			#TODO: menu for choices (@object.query)
		end

		# Non-debug traversal line that always prints.
		@object.message "You step through the %s." % @metadata[:name]

		# Do anything related to egress here
		@object.message "You have exited the '%s' Gate [%s]" % [ @metadata[:name], connection_label ] if $DEBUG

		# Exit the Gate
		self.exit( @destination_area )
	end

	# Exit this Gate into the given destination Area.
	def exit( destination )
		# Set the destination location on the object
		@object.location = destination

		# Enter the Area
		destination.enter( @object )

		return true
	end

	# Specific Gate actions that happen while traversing the gate.
	# Subclasses override this to add custom behavior (locks, tolls, flavor).
	def gate_specific
	end

	# Utility: Add Area
	def add_area( area, visibility )
		@areas << {
			:object => area,
			:visible => visibility
		}
	end

	# Return a short, human-readable label describing this Gate's connected
	# Areas.
	#
	# Formats (per issue #21, RULING #4):
	#   two visible sides:  "Foyer <> Grand Hall"
	#   hidden side:        "Foyer <> Secret Room (hidden)"
	#   one-area loop:      "Foyer (loop)"
	#   zero areas:         "(no areas)"
	# Area order follows @areas insertion order.
	def connection_label
		return '(no areas)' if @areas.empty?
		return "%s (loop)" % @areas[0][:object].metadata[:name] if @areas.count == 1

		@areas.map do | area |
			# Duplicate the name so appending "(hidden)" does not mutate the
			# Area's actual display name.
			label = area[:object].metadata[:name].dup
			label << ' (hidden)' unless area[:visible]
			label
		end.join(' <> ')
	end

	# Return a short display string for the Gate.
	def to_s
		"%s [%s]" % [ @metadata[:name], connection_label ]
	end

	# Return a detailed inspection string for the Gate.
	def inspect
		"#<Gate id=%s name=%s connections=%s>" % [ @id, @metadata[:name], connection_label ]
	end
end
