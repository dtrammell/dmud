#!/usr/bin/env ruby

require 'dmud'

###
# Example World Definition
#
# A small house with a foyer, grand hall, stairs, and a secret room,
# plus a game lobby used as the starting location for new players.
###

# Entrance Gate for new server connections
game_entrance_gate = Gate.new( 'Game Entrance' )
game_entrance_gate.game_entrance = true

# Game Lobby Area for new server connections
lobby = Area.new( 'Game Lobby' )
lobby.add_gate( game_entrance_gate, false )

# "house" Region container for local Areas
house = Region.new( 'House' )

# Foyer area
foyer = Area.new(
	'Foyer',
	house,
	'The Foyer is large and inviting.  You see Stairs to the right and an entrance to a Grand Hall directly ahead.'
)

# Link the Foyer with the Server Entrance gate
foyer.add_gate( game_entrance_gate )

# Grand Hall Area
grand_hall = Area.new(
	'Grand Hall',
	house,
	'The Grand Hall spreads out before you.  To the South is the Foyer.'
)
gate_gh_f = Gate.new( 'Foyer<>Grand Hall Gate' )
foyer.add_gate( gate_gh_f )
grand_hall.add_gate( gate_gh_f )

# Stairs
stairs = Area.new(
	'Stairs',
	house,
	'The Stairs go up and down.  At the bottom of the Stairs is the Foyer.'
)
gate_s_f = Gate.new( 'Foyer<>Stairs Gate' )
foyer.add_gate( gate_s_f )
stairs.add_gate( gate_s_f )

# Secret Room
secret_room = Area.new(
	'Secret Room',
	house,
	'The Secret Room was not meant to be found...  What secrets might it hold???  The only way out is back to the Foyer.'
)
gate_sr_f = Gate.new( 'Foyer<>Secret Room Gate' )
foyer.add_gate( gate_sr_f )
secret_room.add_gate( gate_sr_f, false )

###
# Game Start
###

# Player Object
player  = Player.new(
	'Leeroy Jenkins',
	lobby,
	'LEEEROOOOOOOY JENKINZZZZZZ'
)

# Game Session
Session.new( player, lobby )

# Game Play should continue from within the session object from here forward based on user input
