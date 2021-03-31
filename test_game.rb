#!/usr/bin/ruby

require './dmud.rb' # This will be replaced with a gem later
require './class_region.rb'
require './class_area.rb'
require './class_gate.rb'
require './class_movable_object.rb'
require './class_session.rb'

###
# Test Game Definition
#

# Entrance Gate for new server connections
game_entrance_gate = Gate.new( name = 'Game Entrance' )
game_entrance_gate.game_entrance = true

# Game Lobby Area for new server connections
lobby = Area.new( name = 'Game Lobby' )
lobby.add_gate( game_entrance_gate, false )

# "house" Region container for local Areas
house = Region.new( name = 'House' )

# Foyer area for new server connections
foyer = Area.new(
	name = "Foyer",
	region = house,
	description = 'The Foyer is large and inviting.  You see Stairs to the right and an entrance to a Grand Hall directly ahead.'
)

# Link the Foyer with the Server Entrance gate
foyer.add_gate( game_entrance_gate )

# Grand Hall Area
grand_hall = Area.new(
	name = 'Grand Hall',
	region = house,
	description = 'The Grand Hall spreads out before you.  To the South is the Foyer.'
	)
gate_gh_f = Gate.new( name = 'Foyer<>Grand Hall Gate' )
foyer.add_gate( gate_gh_f )
grand_hall.add_gate( gate_gh_f )

# Stairs
stairs = Area.new(
	name = 'Stairs',
	region = house,
	description = 'The Stairs go up and down.  At the bottom of the Stairs is the Foyer.'
)
gate_s_f = Gate.new( name = 'Foyer<>Stairs Gate' )
foyer.add_gate( gate_s_f )
stairs.add_gate( gate_s_f )

# Secret Room
secret_room = Area.new(
	name = 'Secret Room',
	region = house,
	description = 'The Secret Room was not meant to be found...  What secrets might it hold???  The only way out is back to the Foyer.'
)
gate_sr_f = Gate.new( name = 'Foyer<>Secret Room Gate' )
foyer.add_gate( gate_sr_f )
secret_room.add_gate( gate_sr_f, visible = false )

###
# Game Start
#

# Player Object
player  = Player.new(
	name = 'Leeroy Jenkins',
	location = lobby,
	description = 'LEEEROOOOOOOY JENKINZZZZZZ'
)

# Game Session
session = Session.new( player, lobby )

# Game Play should continue from within the session object from here forward based on user input
