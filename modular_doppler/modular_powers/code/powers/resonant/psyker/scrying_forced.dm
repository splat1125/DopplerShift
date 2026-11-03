/*
	Requires scrying. Allows you to get an estimate of range on a target from their blood regardless of whether they are immune or not, at risk of significant backlash.
	I handwave this like this being a more aggressive form of psychic scrying that's exceptionally noticeable by the person being tracked and people around the person scrying.
*/

/datum/power/psyker_power/scrying_forced
	name = "Forced Scrying"
	desc = "Using a sample of a creature's blood, you can estimate your distance from that creature. While you still cannot track creatures without a complex mind, \
	this violent pulse of psychic energy will reap results even from those shielded against scrying at risk of psychic backlash. Forced scrying is extremely noticeable \
	to anyone around you and also to the creature you are forcing a scry towards. Costs a moderate amount of stress each time it is used. Forcing through anti-magic or \
	anti-scrying measures will backlash towards you with even more stress."
	security_record_text = "Subject can psychically estimate people's distances from themselves using blood samples."
	value = 3
	magic_flags = POWER_MAGIC_STANDARD | POWER_MAGIC_MENTAL | POWER_MAGIC_SCRYING
	action_path = /datum/action/cooldown/power/psyker/scrying_forced
	required_powers = list(/datum/power/psyker_power/scrying)

/datum/action/cooldown/power/psyker/scrying_forced
	name = "Forced Scrying"
	desc = "Using a sample of a creature's blood, you can estimate your distance from them remotely."
	button_icon = 'icons/mob/actions/actions_animal.dmi'
	button_icon_state = "gaze"
	click_to_activate = TRUE
	target_range = 1

//mostly lifted from scrying.dm because this power is derivative

/datum/action/cooldown/power/psyker/scrying_forced/use_action(mob/living/user, atom/target)
	var/list/dna_samples = get_blood_dna_list_from_target(target)
	if(!length(dna_samples))
		to_chat(user, span_warning("You need blood to focus your scrying."))
		return FALSE

	// If your list of dna samples has multiples then my man you gotta clean your samples. Chooses a random one.
	var/selected_dna = pick(dna_samples)
	var/mob/living/chosen_target = find_scry_target_from_dna(selected_dna)
	if(!chosen_target)
		to_chat(user, span_warning("No mind to link to."))
		return FALSE

	//bounce off of antimagic with negative effects
	if(!can_affect_scrying(chosen_target))
		to_chat(user, span_warning("Your sight strains against the mind you seek!"))
		//double cost. maybe more?
		modify_stress(PSYKER_STRESS_MODERATE)

	scry_target = chosen_target

	var/turf/here = get_turf(src)
	var/turf/there = get_turf(scry_target)

	//try to see if we're in a stack-adjacent Z-level. if this returns anything UP or DOWN, we're close!
	var/combined_dir = get_dir_multiz(here, there)
	if(combined_dir == NONE)
		to_chat(user, span_warning("You can feel that your target is nowhere near at all..."))
		modify_stress(PSYKER_STRESS_MINOR)
	else
		var/dist_str = ""
		var/dir_str_v = ""
		var/dir_str_h = ""

		var/turf/here_z_amended = get_step_multiz(src, combined_dir)
		var/dist_amended = get_dist_euclidean(here_z_amended,there)

		if(dist_amended < 1)
			dist_str = " jarringly close"
		else if(dist_amended < 3)
			dist_str = " very close"
		else if(dist_amended < 8)
			dist_str = " close"
		else if(dist_amended < 32)
			dist_str = " somewhere"
		else if(dist_amended < 64)
			dist_str = " far"
		else
			dist_str = " vaguely"

		if(combined_dir & UP)
			dir_str_v = " above"
		else if(combined_dir & DOWN)
			dir_str_v = " below"

		var/horiz_dir = combined_dir & (NORTH | SOUTH | EAST | WEST)
		switch(horiz_dir)
			if(NORTH)     dir_str_h = " to the north"
			if(SOUTH)     dir_str_h = " to the south"
			if(EAST)      dir_str_h = " to the east"
			if(WEST)      dir_str_h = " to the west"
			if(NORTHEAST) dir_str_h = " to the northeast"
			if(NORTHWEST) dir_str_h = " to the northwest"
			if(SOUTHEAST) dir_str_h = " to the southeast"
			if(SOUTHWEST) dir_str_h = " to the southwest"
			else          dir_str_h = "" //


		to_chat(user, span_warning("You can feel your target is[dist_str][dir_str_v][dir_str_h].]"))
		modify_stress(PSYKER_STRESS_MODERATE)


	playsound(user, 'sound/effects/magic/swap.ogg', 75, TRUE, SILENCED_SOUND_EXTRARANGE)




///	 Checks the blood for a dna match.
/datum/action/cooldown/power/psyker/scrying_forced/proc/find_scry_target_from_dna(selected_dna)
	if(!selected_dna)
		return null

	for(var/mob/living/target in GLOB.mob_list)
		if(isobserver(target))
			continue
		var/list/blood_dna = target.get_blood_dna_list()
		if(blood_dna && blood_dna[selected_dna])
			return target
	return null
