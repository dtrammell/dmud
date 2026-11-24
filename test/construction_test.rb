###
# Tests for object construction (#1 and unchanged construction behavior).
###

require_relative 'test_helper'

class ConstructionTest < DMUDTestCase
	# TC-1502-020: DMUDObject#id is a UUID-shaped string.
	# Derivation: ARCHITECTURE.md "sets @id to SecureRandom.uuid".
	def test_dmud_object_id_is_uuid
		obj = DMUDObject.new
		assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, obj.id)
	end

	# TC-1502-021: DMUDObject#id is unique per instance.
	# Derivation: same as TC-020 (random UUID implies uniqueness).
	def test_dmud_object_ids_are_unique
		refute_equal DMUDObject.new.id, DMUDObject.new.id
	end

	# TC-1502-022: Region defaults and add_area duplicate behavior unchanged.
	# Derivation: ARCHITECTURE.md Region section (no duplicate check).
	def test_region_defaults_and_duplicate_add_area
		r = Region.new
		assert_equal 'New Region', r.metadata[:name]

		a = Area.new
		assert r.add_area(a)
		assert r.add_area(a)
		assert_equal 2, r.instance_variable_get(:@areas).count
	end

	# TC-1502-023: Area#gate_lookup stays case-insensitive.
	# Derivation: ARCHITECTURE.md "case-insensitively searches ... for a name match."
	def test_gate_lookup_case_insensitive
		world = fixture_world
		assert_same world[:foyer].gate_lookup('GRAND HALL'), world[:foyer].gate_lookup('grand hall')
	end

	# TC-1502-024: Area#gate_lookup ignores the hidden/visible flag.
	# Derivation: ARCHITECTURE.md "ignores the gate/area's visible flag entirely."
	def test_gate_lookup_ignores_visibility
		world = fixture_world
		assert_equal world[:sr_gate], world[:foyer].gate_lookup('Secret Room')
	end

	# TC-1502-025: MobileObject.new with both required args.
	# Derivation: unchanged constructor signature.
	def test_mobile_object_with_required_args
		area = Area.new('A')
		obj = MobileObject.new('Thing', area)
		assert_equal 'Thing', obj.metadata[:name]
		assert_equal area, obj.location
		assert_equal '', obj.metadata[:description]
	end

	# TC-1502-026: MobileObject.new missing location raises.
	# Derivation: location has no default.
	def test_mobile_object_missing_location_raises
		assert_raises(ArgumentError) { MobileObject.new('Thing') }
	end

	# TC-1502-027: MobileObject.new with zero args raises.
	# Derivation: same signature, boundary of required-arg count.
	def test_mobile_object_zero_args_raises
		assert_raises(ArgumentError) { MobileObject.new }
	end

	# TC-1502-028: Item.new(name, location) succeeds.
	# Derivation: #21 AC "Item, NPC and MOB forward their constructor
	# arguments, so they can be created"; #1 repro command.
	def test_item_new_with_name_and_location
		area = Area.new('A')
		item = Item.new('Sword', area)
		assert_equal 'Sword', item.metadata[:name]
		assert_equal area, item.location
	end

	# TC-1502-029: NPC.new(name, location) succeeds, @carryable false.
	# Derivation: #21 AC + unchanged subclass body.
	def test_npc_new_with_name_and_location
		area = Area.new('A')
		npc = NPC.new('Bob', area)
		assert_equal 'Bob', npc.metadata[:name]
		assert_equal false, npc.instance_variable_get(:@carryable)
	end

	# TC-1502-030: MOB.new(name, location) succeeds, @carryable false.
	# Derivation: same as TC-029, mirrored for MOB.
	def test_mob_new_with_name_and_location
		area = Area.new('A')
		mob = MOB.new('Rat', area)
		assert_equal 'Rat', mob.metadata[:name]
		assert_equal false, mob.instance_variable_get(:@carryable)
	end

	# TC-1502-031: Item.new @carryable true.
	# Derivation: same pattern, Item's unchanged body.
	def test_item_carryable_true
		area = Area.new('A')
		item = Item.new('Sword', area)
		assert_equal true, item.instance_variable_get(:@carryable)
	end

	# TC-1502-032: Item.new with description forwards all three args.
	# Derivation: #21 AC "forward their constructor arguments" (all args).
	def test_item_new_forwards_description
		area = Area.new('A')
		item = Item.new('Sword', area, 'A sharp blade')
		assert_equal 'A sharp blade', item.metadata[:description]
	end

	# TC-1502-033: Item.new missing location still raises.
	# Derivation: #1 fix only forwards; requiredness propagates.
	def test_item_missing_location_raises
		assert_raises(ArgumentError) { Item.new('Sword') }
	end

	# TC-1502-034: Item.new with zero args still raises.
	# Derivation: same reasoning as TC-033; mirrors #1's second repro.
	def test_item_zero_args_raises
		assert_raises(ArgumentError) { Item.new }
	end

	# TC-1502-035: carryable is not constructor-settable.
	# Derivation: #1's suggested fix only forwards to MobileObject's 3-arg
	# signature; it does not add a new parameter.
	def test_item_no_carryable_constructor_param
		area = Area.new('A')
		assert_raises(ArgumentError) { Item.new('Sword', area, 'desc', true) }
	end

	# TC-1502-036: Player.new construction stays unchanged.
	# Derivation: ARCHITECTURE.md Player section; regression guard.
	def test_player_new_unchanged
		area = Area.new('A')
		player = Player.new('Leeroy Jenkins', area)
		assert_equal 'Leeroy Jenkins', player.metadata[:name]
		assert_equal false, player.instance_variable_get(:@carryable)
	end
end
