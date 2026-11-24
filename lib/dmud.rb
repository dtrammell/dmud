###
# DMUD — Distributed Multi-User Dungeon
#
# Entry point for the dmud gem.  Loads every class file under lib/dmud/.
# World scripts should use `require 'dmud'` and then construct Regions,
# Areas, Gates, and Players as shown in the examples/ directory.
###

require_relative 'dmud/dmud_object'
require_relative 'dmud/region'
require_relative 'dmud/area'
require_relative 'dmud/gate'
require_relative 'dmud/mobile_object'
require_relative 'dmud/player'
require_relative 'dmud/session'
