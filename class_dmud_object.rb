require 'securerandom'

###i
# Root Distributed Multi-User Dungeon (DMUD) Object Class
#
# This root Class mostly contains default values for variables common to all DMUD objects, as
# well as utility methods related to the object instances themselves (export/import, integrity
# validation, etc.)
#

class DMUDObject
	attr_reader :id

	# Initialization
	def initialize
		@id = SecureRandom.uuid
	end
end
