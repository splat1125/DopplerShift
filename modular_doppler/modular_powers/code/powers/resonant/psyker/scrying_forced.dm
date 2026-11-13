/*
	Requires scrying. Allows you to get an estimate of range on a target from their blood regardless of whether they are immune or not, at risk of significant backlash.
	I handwave this like this being a more aggressive form of psychic scrying that's exceptionally noticeable by the person being tracked and people around the person scrying.
*/

/datum/power/psyker_power/scrying_forced
	name = "Forced Scrying"
	desc = "For a moderate stress cost, allows you to forcibly estimate your distance from a creature regardless of whether they are immune to scrying or not. \
	Watch out for backlash; scrying-immune subjects will stun you!"
	security_record_text = "Subject can psychically estimate people's distances from themselves using blood samples."
	value = 3
	magic_flags = POWER_MAGIC_STANDARD | POWER_MAGIC_MENTAL | POWER_MAGIC_SCRYING
	action_path = /datum/action/cooldown/power/psyker/scrying_forced
	required_powers = list(/datum/power/psyker_power/scrying)
	required_allow_subtypes = FALSE

/datum/action/cooldown/power/psyker/scrying_forced
	name = "Forced Scrying"
	desc = "Using a sample of a creature's blood, you can estimate your distance from them remotely."
	button_icon = 'icons/mob/actions/actions_animal.dmi'
	button_icon_state = "gaze"
	use_time = 1 SECONDS
	cooldown_time = 5 SECONDS
	click_to_activate = TRUE
	target_range = 1

	var/atom/movable/scry_target

//most of the blood discerning stuff is lifted from scrying.dm because this power is derivative,,,,,,,,

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
		to_chat(user, span_userdanger("Your scrying backlashes off of your target!"))
		StartCooldownSelf(20 SECONDS)
		playsound(user, 'sound/effects/magic/blind.ogg', 25, TRUE, SILENCED_SOUND_EXTRARANGE)
		modify_stress(PSYKER_STRESS_MAJOR * 1.5)	//be careful!

		//scrying someone immune always causes a mild event regardless of your cooldowns
		pick_psyker_event(/datum/psyker_event/mild, user)
		user.Stun(3 SECONDS)

		if(rand() < 0.25)	//25% chance to warn shielded
			to_chat(chosen_target, span_warning("A presence menaces at your mind, seeking you out!"))

	else if(rand() < 0.05)	//5% chance to warn
		to_chat(chosen_target, span_warning("A cold wind rushes through your mind; something is looking for you!"))
	scry_target = chosen_target

	var/turf/here = get_turf(user)
	var/turf/there = get_turf(scry_target)

	//try to see if we're in a stack-adjacent Z-level. if this returns anything UP or DOWN, we're close!
	var/combined_dir = get_dir_multiz(here, there)
	if(combined_dir == NONE && here.z != there.z)
		to_chat(user, span_warning("You can feel that your target is nowhere near at all..."))
		modify_stress(PSYKER_STRESS_MINOR)
	else
		var/dist_str = ""
		var/dir_str_v = ""
		var/dir_str_h = ""
		var/punct = "."

		var/turf/here_z_amended = get_step_multiz(user, combined_dir)
		var/dist_amended = get_dist_euclidean(here_z_amended,there)

		if(dist_amended < 1)
			dist_str = " jarringly close"
			punct = "!"
		else if(dist_amended < 3)
			dist_str = " very close"
			punct = "!"
		else if(dist_amended < 8)
			dist_str = " close"
			punct = "!"
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
			else          dir_str_h = ""

		user.adjust_eye_blur_up_to(3 SECONDS, 4 SECONDS)
		user.adjust_temp_blindness_up_to(2 SECONDS, 3 SECONDS)
		to_chat(user, span_warning("You can feel your target is[dist_str][dir_str_v][dir_str_h][punct]"))
		modify_stress(PSYKER_STRESS_MODERATE)


	playsound(user, SFX_PORTAL_CREATED, 50, TRUE, SHORT_RANGE_SOUND_EXTRARANGE)



/// Picks the backlash event after a stress breakdown
/datum/action/cooldown/power/psyker/scrying_forced/proc/pick_psyker_event(base_type, mob/living/carbon/human/human)
	var/list/candidates = list()

	// We check for abstract types and assign the weights
	for(var/subtype in subtypesof(base_type))
		var/datum/psyker_event/event_type = subtype

		if(initial(event_type.abstract_type) == subtype)
			continue

		var/weight = initial(event_type.weight)
		candidates[subtype] = weight

	// We check the candidates, pick one, try it. If it returns true, we end. If it returns false, we try another.
	// In principle this should never fail because each category has one that will always return true.
	while(length(candidates))
		var/subtype = pick_weight(candidates)
		candidates -= subtype

		var/datum/psyker_event/event = new subtype

		if(!event.can_execute(human, src))
			qdel(event)
			continue

		// We check if it actually successfully executed. Qdel it under normal circumstances; if it lingers we don't.
		if(event.execute(human))
			if(!event.lingering)
				qdel(event)
			return

		// Execution failed? We retry
		qdel(event)

	return


//procs lifted from scrying.dm
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

/datum/action/cooldown/power/psyker/scrying_forced/proc/get_blood_dna_list_from_target(atom/target)
	if(isnull(target))
		return null

	var/list/dna_list = list()

	if(ismob(target))
		return dna_list

	// Gets dna from a blood decal.
	if(istype(target, /obj/effect/decal/cleanable/blood))
		var/list/blood = GET_ATOM_BLOOD_DNA(target)
		for(var/dna in blood)
			dna_list += dna
		return dna_list

	// Gets dna from blood from reagent containers. Note: There's a bug with scraping blood not saving DNA; so if it acts weirds its likely that (as of 20/02/26)
	if(istype(target, /obj/item/reagent_containers))
		for(var/datum/reagent/present_reagent as anything in target.reagents?.reagent_list)
			if(!istype(present_reagent, /datum/reagent/blood))
				continue
			var/blood_dna = present_reagent.data?["blood_DNA"]
			if(isnull(blood_dna))
				continue
			if(islist(blood_dna))
				for(var/dna in blood_dna)
					dna_list += dna
			else
				dna_list += blood_dna

	// Any non-mob atom with forensics blood on it (e.g. clothes, tools)
	var/list/blood = GET_ATOM_BLOOD_DNA(target)
	if(length(blood))
		for(var/dna in blood)
			dna_list += dna

	return dna_list
