/// Slow moving mob which attempts to immobilise its target
/mob/living/basic/mining/goliath
	name = "goliath"
	desc = "A hulking, armor-plated beast with long tendrils arching from its back."
	icon = 'icons/mob/simple/lavaland/lavaland_monsters_wide.dmi'
	icon_state = "goliath"
	icon_living = "goliath"
	icon_dead = "goliath_dead"
	pixel_x = -12
	base_pixel_x = -12
	gender = MALE // Female ones are the bipedal elites
	speed = 30
	basic_mob_flags = IMMUNE_TO_FISTS
	maxHealth = 300
	health = 300
	friendly_verb_continuous = "wails at"
	friendly_verb_simple = "wail at"
	speak_emote = list("bellows")
	obj_damage = 100
	melee_damage_lower = 25
	melee_damage_upper = 25
	attack_sound = 'sound/weapons/punch1.ogg'
	attack_verb_continuous = "pulverizes"
	attack_verb_simple = "pulverize"
	throw_blocked_message = "does nothing to the tough hide of"
	move_force = MOVE_FORCE_VERY_STRONG
	move_resist = MOVE_FORCE_VERY_STRONG
	pull_force = MOVE_FORCE_VERY_STRONG

	ai_controller = /datum/ai_controller/basic_controller/goliath

	crusher_loot = /obj/item/crusher_trophy/goliath_tentacle
	butcher_results = list(/obj/item/food/meat/slab/goliath = 2, /obj/item/stack/sheet/bone = 2)
	guaranteed_butcher_results = list(/obj/item/stack/sheet/animalhide/goliath_hide = 1)
	/// Icon state to use when tentacles are available
	var/tentacle_warning_state = "goliath_preattack"
	/// Can this kind of goliath be tamed?
	var/tameable = TRUE
	/// Has this particular goliath been tamed?
	var/tamed = FALSE
	/// Can someone ride us around like a horse?
	var/saddled = FALSE
	/// Slight cooldown to prevent double-dipping if we use both abilities at once
	COOLDOWN_DECLARE(ability_animation_cooldown)
	/// Our base tentacles ability
	var/datum/action/cooldown/mob_cooldown/goliath_tentacles/tentacles
	/// Things we want to eat off the floor (or a plate, we're not picky)
	var/static/list/goliath_foods = list(/obj/item/food/grown/ash_flora, /obj/item/food/bait/worm)

	//monkestation edit
	//pet commands when we tame the grub
	var/list/pet_commands = list(
		/datum/pet_command/idle,
		/datum/pet_command/free,
		/datum/pet_command/follow,
		/datum/pet_command/point_targetting/fetch,
	)
	//monkestation edit

/mob/living/basic/mining/goliath/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_NO_GLIDE, INNATE_TRAIT)
	ADD_TRAIT(src, TRAIT_TENTACLE_IMMUNE, INNATE_TRAIT)
	AddElement(/datum/element/ai_retaliate)
	AddElement(/datum/element/footstep, FOOTSTEP_MOB_HEAVY)
	AddElement(/datum/element/basic_eating, heal_amt = 10, food_types = goliath_foods)
	AddComponent(/datum/component/basic_mob_attack_telegraph)
	AddComponentFrom(INNATE_TRAIT, /datum/component/shovel_hands)
	if (tameable)
		AddComponent(\
			/datum/component/tameable,\
			food_types = list(/obj/item/food/grown/ash_flora),\
			tame_chance = 10,\
			bonus_tame_chance = 5,\
			after_tame = CALLBACK(src, PROC_REF(tamed)),\
		)

	tentacles = new (src)
	tentacles.Grant(src)
	var/datum/action/cooldown/mob_cooldown/tentacle_burst/melee_tentacles = new (src)
	melee_tentacles.Grant(src)
	AddComponent(/datum/component/revenge_ability, melee_tentacles, targetting = ai_controller.blackboard[BB_TARGETTING_DATUM], max_range = 1, target_self = TRUE)
	var/datum/action/cooldown/mob_cooldown/tentacle_grasp/ranged_tentacles = new (src)
	ranged_tentacles.Grant(src)
	AddComponent(/datum/component/revenge_ability, ranged_tentacles, targetting = ai_controller.blackboard[BB_TARGETTING_DATUM], min_range = 2, max_range = 9)

	tentacles_ready()
	RegisterSignal(src, COMSIG_MOB_ABILITY_FINISHED, PROC_REF(used_ability))
	ai_controller.set_blackboard_key(BB_BASIC_FOODS, goliath_foods)
	ai_controller.set_blackboard_key(BB_GOLIATH_TENTACLES, tentacles)


/mob/living/basic/mining/goliath/Destroy()
	QDEL_NULL(tentacles)
	return ..()

/mob/living/basic/mining/goliath/examine(mob/user)
	. = ..()
	if (saddled)
		. += span_info("Someone appears to have attached a saddle to this one.")

/mob/living/basic/mining/goliath/revive(full_heal_flags, excess_healing, force_grab_ghost)
	. = ..()
	if (!.)
		return
	move_force = initial(move_force)
	move_resist = initial(move_resist)
	pull_force = initial(pull_force)

/mob/living/basic/mining/goliath/death(gibbed)
	move_force = MOVE_FORCE_DEFAULT
	move_resist = MOVE_RESIST_DEFAULT
	pull_force = PULL_FORCE_DEFAULT
	return ..()

// Goliaths can summon tentacles more frequently as they take damage, scary.
/mob/living/basic/mining/goliath/apply_damage(damage, damagetype, def_zone, blocked, forced, spread_damage, wound_bonus, bare_wound_bonus, sharpness, attack_direction, attacking_item)
	. = ..()
	if (!.)
		return
	if (damage <= 0)
		return
	if (tentacles.cooldown_time > 1 SECONDS)
		tentacles.cooldown_time -= 1 SECONDS

/mob/living/basic/mining/goliath/attackby(obj/item/attacking_item, mob/living/user, params)
	if (!istype(attacking_item, /obj/item/goliath_saddle))
		return ..()
	if (!tameable)
		balloon_alert(user, "doesn't fit!")
		return
	if (saddled)
		balloon_alert(user, "already saddled!")
		return
	if (!tamed)
		balloon_alert(user, "too rowdy!")
		return
	balloon_alert(user, "affixing saddle...")
	if (!do_after(user, delay = 5.5 SECONDS, target = src))
		return
	balloon_alert(user, "ready to ride")
	qdel(attacking_item)
	saddled = TRUE
	buckle_lying = 0
	add_overlay("goliath_saddled")
	AddElement(/datum/element/ridable, /datum/component/riding/creature/goliath)

/// When we use an ability, activate some kind of visual tell
/mob/living/basic/mining/goliath/proc/used_ability(mob/living/source, datum/action/cooldown/ability)
	SIGNAL_HANDLER
	if (stat == DEAD || ability.IsAvailable())
		return // We died or the action failed for some reason like being out of range
	if (istype(ability, /datum/action/cooldown/mob_cooldown/goliath_tentacles))
		if (ability.cooldown_time <= 2 SECONDS)
			return
		icon_state = icon_living
		addtimer(CALLBACK(src, PROC_REF(tentacles_ready)), ability.cooldown_time - 2 SECONDS, TIMER_DELETE_ME)
		return
	if (!COOLDOWN_FINISHED(src, ability_animation_cooldown))
		return
	COOLDOWN_START(src, ability_animation_cooldown, 2 SECONDS)
	playsound(src, 'sound/magic/demon_attack1.ogg', vol = 50, vary = TRUE)
	Shake(1, 0, 1.5 SECONDS)

/// Called slightly before tentacles ability comes off cooldown, as a warning
/mob/living/basic/mining/goliath/proc/tentacles_ready()
	if (stat == DEAD)
		return
	icon_state = tentacle_warning_state

/// Get ready for mounting
/mob/living/basic/mining/goliath/proc/tamed()
	new /obj/effect/temp_visual/heart(src.loc)
	tamed = TRUE
	//monkestation edit
	AddComponent(/datum/component/obeys_commands, pet_commands)
	response_help_simple = "pet"
	response_help_continuous = "pets"
	AddElement(/datum/element/pet_bonus, "wails happily!")
	//monkestation edit ends

// Copy entire faction rather than just placing user into faction, to avoid tentacle peril on station
/mob/living/basic/mining/goliath/befriend(mob/living/new_friend)
	. = ..()
	faction = new_friend.faction.Copy()

/// Legacy Goliath mob with different sprites, largely the same behaviour
/mob/living/basic/mining/goliath/ancient
	name = "ancient goliath"
	desc = "A massive beast that uses long tentacles to ensnare its prey, threatening them is not advised under any conditions."
	icon = 'icons/mob/simple/lavaland/lavaland_monsters_wide.dmi'
	icon_state = "ancient_goliath"
	icon_living = "ancient_goliath"
	icon_dead = "ancient_goliath_dead"
	tentacle_warning_state = "ancient_goliath_preattack"
	tameable = FALSE

/// Rare Goliath variant which occasionally replaces the normal mining mob, releases shitloads of tentacles
/mob/living/basic/mining/goliath/ancient/immortal
	name = "immortal goliath"
	desc = "Goliaths are biologically immortal, and rare specimens have survived for centuries. \
		This one is clearly ancient, and its tentacles constantly churn the earth around it."
	maxHealth = 400
	health = 400
	crusher_drop_chance = 30 // Wow a whole 5% more likely, how generous
	/// Don't re-check nearby turfs for this long
	COOLDOWN_DECLARE(retarget_turfs_cooldown)
	/// List of places we might spawn a tentacle, if we're alive
	var/list/tentacle_target_turfs

/mob/living/basic/mining/goliath/ancient/immortal/Life(seconds_per_tick, times_fired)
	. = ..()
	if (!. || !isturf(loc))
		return
	if (!LAZYLEN(tentacle_target_turfs) || COOLDOWN_FINISHED(src, retarget_turfs_cooldown))
		cache_nearby_turfs()
	for (var/turf/target_turf in tentacle_target_turfs)
		if (target_turf.is_blocked_turf(exclude_mobs = TRUE))
			tentacle_target_turfs -= target_turf
			continue
		if (prob(10))
			new /obj/effect/goliath_tentacle(target_turf)

/mob/living/basic/mining/goliath/ancient/immortal/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change)
	. = ..()
	if (loc == old_loc || stat == DEAD || !isturf(loc))
		return
	cache_nearby_turfs()

/// Store nearby turfs in our list so we can pop them out later
/mob/living/basic/mining/goliath/ancient/immortal/proc/cache_nearby_turfs()
	COOLDOWN_START(src, retarget_turfs_cooldown, 10 SECONDS)
	LAZYCLEARLIST(tentacle_target_turfs)
	for(var/turf/open/floor in orange(4, loc))
		LAZYADD(tentacle_target_turfs, floor)

/// Use this to ride a goliath
/obj/item/goliath_saddle
	name = "goliath saddle"
	desc = "This rough saddle will give you a serviceable seat upon a goliath! Provided you can get one to stand still."
	icon = 'icons/obj/mining.dmi'
	icon_state = "goliath_saddle"
