#define NUKESCALINGMODIFIER 6

/proc/issyndicate(mob/living/M as mob)
	return istype(M) && M.mind && SSticker && SSticker.mode && (M.mind in SSticker.mode.syndicates)

/datum/game_mode/nuclear
	name = "nuclear emergency"
	config_tag = "nuclear"
	tdm_gamemode = TRUE
	required_players = 30	// 30 players - 5 players to be the nuke ops = 25 players remaining
	required_enemies = 5
	recommended_enemies = 5
	single_antag_positions = list()

	var/const/agents_possible = 5 //If we ever need more syndicate agents.

	var/nukes_left = 1 //Call 3714-PRAY right now and order more nukes! Limited offer!
	var/nuke_off_station = 0 //Used for tracking if the syndies actually haul the nuke to the station
	var/syndies_didnt_escape = 0 //Used for tracking if the syndies got the shuttle off of the z-level
	var/total_tc = 0 //Total amount of telecrystals shared between nuke ops

/datum/game_mode/nuclear/announce()
	to_chat(world, "<B>The current game mode is - Nuclear Emergency!</B>")
	to_chat(world, "<B>A [syndicate_name()] Strike Force is approaching [station_name()]!</B>")
	to_chat(world, "A nuclear explosive was being transported by Nanotrasen to a military base. The transport ship mysteriously lost contact with Space Traffic Control (STC). About that time a strange disk was discovered around [station_name()]. It was identified by Nanotrasen as a nuclear authentication disk and now Syndicate Operatives have arrived to retake the disk and detonate SS13! There are most likely Syndicate starships are in the vicinity, so take care not to lose the disk!\n<B>Syndicate</B>: Reclaim the disk and detonate the nuclear bomb anywhere on SS13.\n<B>Personnel</B>: Hold the disk and <B>escape with the disk</B> on the shuttle!")

/datum/game_mode/nuclear/can_start()//This could be better, will likely have to recode it later
	if(!..())
		return 0

	var/list/possible_syndicates = get_players_for_role(ROLE_OPERATIVE)
	var/agent_number = 0

	if(length(possible_syndicates) < 1)
		return 0

	if(LAZYLEN(possible_syndicates) > agents_possible)
		agent_number = agents_possible
	else
		agent_number = length(possible_syndicates)

	var/n_players = num_players()
	if(agent_number > n_players)
		agent_number = n_players/2

	while(agent_number > 0)
		var/datum/mind/new_syndicate = pick(possible_syndicates)
		syndicates += new_syndicate
		possible_syndicates -= new_syndicate //So it doesn't pick the same guy each time.
		agent_number--

	for(var/datum/mind/synd_mind in syndicates)
		synd_mind.assigned_role = SPECIAL_ROLE_NUKEOPS //So they aren't chosen for other jobs.
		synd_mind.special_role = SPECIAL_ROLE_NUKEOPS
	return 1


/datum/game_mode/nuclear/pre_setup()
	..()
	return 1

/datum/game_mode/proc/remove_operative(datum/mind/operative_mind)
	if(operative_mind in syndicates)
		SSticker.mode.syndicates -= operative_mind
		operative_mind.special_role = null
		operative_mind.objective_holder.clear(/datum/objective/nuclear)
		operative_mind.current.create_attack_log("<span class='danger'>No longer nuclear operative</span>")
		operative_mind.current.create_log(CONVERSION_LOG, "No longer nuclear operative")
		if(issilicon(operative_mind.current))
			to_chat(operative_mind.current, "<span class='userdanger'>You have been turned into a robot! You are no longer a Syndicate operative.</span>")
		else
			to_chat(operative_mind.current, "<span class='userdanger'>You have been brainwashed! You are no longer a Syndicate operative.</span>")
		SSticker.mode.update_synd_icons_removed(operative_mind)

////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////

/datum/game_mode/proc/update_synd_icons_added(datum/mind/synd_mind)
	var/datum/atom_hud/antag/opshud = GLOB.huds[ANTAG_HUD_OPS]
	opshud.join_hud(synd_mind.current)
	set_antag_hud(synd_mind.current, "hudoperative")

/datum/game_mode/proc/update_synd_icons_removed(datum/mind/synd_mind)
	var/datum/atom_hud/antag/opshud = GLOB.huds[ANTAG_HUD_OPS]
	opshud.leave_hud(synd_mind.current)
	set_antag_hud(synd_mind.current, null)

////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////

/datum/game_mode/nuclear/post_setup()

	var/list/turf/synd_spawn = list()

	for(var/obj/effect/landmark/spawner/syndie/S in GLOB.landmarks_list)
		synd_spawn += get_turf(S)
		qdel(S)
		continue

	var/obj/machinery/nuclearbomb/syndicate/the_bomb
	var/nuke_code = rand(10000, 99999)
	var/leader_selected = 0
	var/agent_number = 1
	var/spawnpos = 1

	for(var/obj/effect/landmark/spawner/nuclear_bomb/syndicate/nuke_spawn in GLOB.landmarks_list)
		if(!length(synd_spawn))
			break

		the_bomb = new /obj/machinery/nuclearbomb/syndicate(get_turf(nuke_spawn))
		the_bomb.r_code = nuke_code
		break

	for(var/datum/mind/synd_mind in syndicates)
		if(spawnpos > length(synd_spawn))
			spawnpos = 2
		synd_mind.current.loc = synd_spawn[spawnpos]
		synd_mind.offstation_role = TRUE
		forge_syndicate_objectives(synd_mind)
		create_syndicate(synd_mind, the_bomb)
		greet_syndicate(synd_mind)
		equip_syndicate(synd_mind.current)

		if(!leader_selected)
			prepare_syndicate_leader(synd_mind, the_bomb)
			leader_selected = 1
		else
			synd_mind.current.real_name = "[syndicate_name()] Operative #[agent_number]"
			update_syndicate_id(synd_mind, FALSE)

			agent_number++
		spawnpos++
		update_synd_icons_added(synd_mind)

	scale_telecrystals()
	share_telecrystals()

	return ..()

/datum/game_mode/nuclear/proc/scale_telecrystals()
	var/list/living_crew = get_living_players(exclude_nonhuman = FALSE, exclude_offstation = TRUE)
	var/danger = length(living_crew)
	while(!ISMULTIPLE(++danger, 10)) //Increments danger up to the nearest multiple of ten

	total_tc += danger * NUKESCALINGMODIFIER

/datum/game_mode/nuclear/proc/share_telecrystals()
	var/player_tc
	var/remainder

	player_tc = round(total_tc / length(GLOB.nuclear_uplink_list)) //round to get an integer and not floating point
	remainder = total_tc % length(GLOB.nuclear_uplink_list)

	for(var/obj/item/radio/uplink/nuclear/U in GLOB.nuclear_uplink_list)
		U.hidden_uplink.uses += player_tc
	while(remainder > 0)
		for(var/obj/item/radio/uplink/nuclear/U in GLOB.nuclear_uplink_list)
			if(remainder <= 0)
				break
			U.hidden_uplink.uses++
			remainder--

/datum/game_mode/proc/create_syndicate(datum/mind/synd_mind, obj/machinery/nuclearbomb/syndicate/the_bomb) // So we don't have inferior species as ops - randomize a human
	var/mob/living/carbon/human/M = synd_mind.current

	M.set_species(/datum/species/human, TRUE)
	M.dna.flavor_text = null
	M.flavor_text = null
	M.dna.ready_dna(M) // Quadriplegic Nuke Ops won't be participating in the paralympics
	M.dna.species.create_organs(M)
	M.cleanSE() //No fat/blind/colourblind/epileptic/whatever ops.
	M.overeatduration = 0

	var/obj/item/organ/external/head/head_organ = M.get_organ("head")
	var/hair_c = pick("#8B4513","#000000","#FF4500","#FFD700") // Brown, black, red, blonde
	var/eye_c = pick("#000000","#8B4513","1E90FF") // Black, brown, blue
	var/skin_tone = pick(-50, -30, -10, 0, 0, 0, 10) // Caucasian/black
	head_organ.facial_colour = hair_c
	head_organ.sec_facial_colour = hair_c
	head_organ.hair_colour = hair_c
	head_organ.sec_hair_colour = hair_c
	M.change_eye_color(eye_c)
	M.s_tone = skin_tone
	head_organ.h_style = random_hair_style(M.gender, head_organ.dna.species.name)
	head_organ.f_style = random_facial_hair_style(M.gender, head_organ.dna.species.name)
	M.body_accessory = null
	M.regenerate_icons()
	M.update_body()

	if(!the_bomb)
		the_bomb = locate(/obj/machinery/nuclearbomb/syndicate) in GLOB.poi_list

	if(the_bomb)
		synd_mind.store_memory("<B>Syndicate [the_bomb.name] Code</B>: [the_bomb.r_code]")
		to_chat(synd_mind.current, "The code for \the [the_bomb.name] is: <B>[the_bomb.r_code]</B>")

/datum/game_mode/proc/prepare_syndicate_leader(datum/mind/synd_mind, obj/machinery/nuclearbomb/syndicate/the_bomb)
	var/leader_title = pick("Czar", "Boss", "Commander", "Chief", "Kingpin", "Director", "Overlord")
	synd_mind.current.real_name = "[syndicate_name()] Team [leader_title]"
	to_chat(synd_mind.current, "<B>You are the Syndicate leader for this mission. You are responsible for the distribution of telecrystals and your ID is the only one who can open the launch bay doors.</B>")
	to_chat(synd_mind.current, "<B>If you feel you are not up to this task, give your ID to another operative.</B>")
	to_chat(synd_mind.current, "<B>In your hand you will find a special item capable of triggering a greater challenge for your team. Examine it carefully and consult with your fellow operatives before activating it.</B>")

	var/obj/item/nuclear_challenge/challenge = new /obj/item/nuclear_challenge
	synd_mind.current.equip_to_slot_or_del(challenge, ITEM_SLOT_RIGHT_HAND)

	update_syndicate_id(synd_mind, leader_title, TRUE)

	if(the_bomb)
		var/obj/item/paper/P = new
		P.info = "The code for \the [the_bomb.name] is: <B>[the_bomb.r_code]</B>"
		P.name = "nuclear bomb code"
		var/obj/item/stamp/syndicate/stamp = new
		P.stamp(stamp)
		qdel(stamp)

		if(SSticker.mode.config_tag=="nuclear")
			P.loc = synd_mind.current.loc
		else
			var/mob/living/carbon/human/H = synd_mind.current
			P.loc = H.loc
			H.equip_to_slot_or_del(P, ITEM_SLOT_RIGHT_POCKET, 0)
			H.update_icons()


/datum/game_mode/proc/update_syndicate_id(datum/mind/synd_mind, is_leader = FALSE)
	var/list/found_ids = synd_mind.current.search_contents_for(/obj/item/card/id)

	if(LAZYLEN(found_ids))
		for(var/obj/item/card/id/ID in found_ids)
			ID.name = "[synd_mind.current.real_name] ID card"
			ID.registered_name = synd_mind.current.real_name
			if(is_leader)
				ID.access += ACCESS_SYNDICATE_LEADER
	else
		message_admins("Warning: Operative [key_name_admin(synd_mind.current)] spawned without an ID card!")

/datum/game_mode/proc/forge_syndicate_objectives(datum/mind/syndicate)
	syndicate.add_mind_objective(/datum/objective/nuclear)

/datum/game_mode/proc/greet_syndicate(datum/mind/syndicate, you_are=1)
	SEND_SOUND(syndicate.current, sound('sound/ambience/antag/ops.ogg'))
	var/list/messages = list()
	if(you_are)
		messages.Add("<span class='notice'>You are a [syndicate_name()] agent!</span>")

	messages.Add(syndicate.prepare_announce_objectives(FALSE))
	messages.Add("<span class='motd'>For more information, check the wiki page: ([GLOB.configuration.url.wiki_url]/index.php/Nuclear_Agent)</span>")
	to_chat(syndicate.current, chat_box_red(messages.Join("<br>")))
	syndicate.current.create_log(MISC_LOG, "[syndicate.current] was made into a nuclear operative")


/datum/game_mode/proc/random_radio_frequency()
	return 1337 // WHY??? -- Doohl


/datum/game_mode/proc/equip_syndicate(mob/living/carbon/human/synd_mob, uplink_uses = 100)
	var/radio_freq = SYND_FREQ

	var/obj/item/radio/R = new /obj/item/radio/headset/syndicate/alt(synd_mob)
	R.set_frequency(radio_freq)
	synd_mob.equip_to_slot_or_del(R, ITEM_SLOT_LEFT_EAR)

	var/back

	switch(synd_mob.backbag)
		if(GBACKPACK, DBACKPACK)
			back = /obj/item/storage/backpack
		if(GSATCHEL, DSATCHEL)
			back = /obj/item/storage/backpack/satchel_norm
		if(GDUFFLEBAG, DDUFFLEBAG)
			back = /obj/item/storage/backpack/duffel
		if(LSATCHEL)
			back = /obj/item/storage/backpack/satchel
		else
			back = /obj/item/storage/backpack

	synd_mob.equip_to_slot_or_del(new /obj/item/clothing/under/syndicate(synd_mob), ITEM_SLOT_JUMPSUIT)
	synd_mob.equip_to_slot_or_del(new /obj/item/clothing/shoes/combat(synd_mob), ITEM_SLOT_SHOES)
	synd_mob.equip_or_collect(new /obj/item/clothing/gloves/combat(synd_mob), ITEM_SLOT_GLOVES)
	synd_mob.equip_to_slot_or_del(new /obj/item/card/id/syndicate(synd_mob), ITEM_SLOT_ID)
	synd_mob.equip_to_slot_or_del(new back(synd_mob), ITEM_SLOT_BACK)
	synd_mob.equip_to_slot_or_del(new /obj/item/gun/projectile/automatic/pistol(synd_mob), ITEM_SLOT_BELT)
	synd_mob.equip_to_slot_or_del(new /obj/item/storage/box/survival_syndie(synd_mob.back), ITEM_SLOT_IN_BACKPACK)
	synd_mob.equip_to_slot_or_del(new /obj/item/pinpointer/nukeop(synd_mob), ITEM_SLOT_PDA)
	var/obj/item/radio/uplink/nuclear/U = new /obj/item/radio/uplink/nuclear(synd_mob)
	U.hidden_uplink.uplink_owner="[synd_mob.key]"
	U.hidden_uplink.uses = uplink_uses
	synd_mob.equip_to_slot_or_del(U, ITEM_SLOT_IN_BACKPACK)
	synd_mob.mind.offstation_role = TRUE

	if(synd_mob.dna.species)
		var/race = synd_mob.dna.species.name

		switch(race)
			if("Vox")
				synd_mob.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/syndicate(synd_mob), ITEM_SLOT_MASK)
				synd_mob.equip_to_slot_or_del(new /obj/item/tank/internals/emergency_oxygen/double/vox(synd_mob), ITEM_SLOT_LEFT_HAND)
				synd_mob.internal = synd_mob.l_hand
				synd_mob.update_action_buttons_icon()

			if("Plasmaman")
				synd_mob.equip_to_slot_or_del(new /obj/item/clothing/mask/gas/syndicate(synd_mob), ITEM_SLOT_MASK)
				synd_mob.equip_or_collect(new /obj/item/tank/internals/plasmaman(synd_mob), ITEM_SLOT_SUIT_STORE)
				synd_mob.equip_or_collect(new /obj/item/extinguisher_refill(synd_mob), ITEM_SLOT_IN_BACKPACK)
				synd_mob.equip_or_collect(new /obj/item/extinguisher_refill(synd_mob), ITEM_SLOT_IN_BACKPACK)
				synd_mob.internal = synd_mob.get_item_by_slot(ITEM_SLOT_SUIT_STORE)
				synd_mob.update_action_buttons_icon()

	synd_mob.rejuvenate() //fix any damage taken by naked vox/plasmamen/etc while round setups
	var/obj/item/bio_chip/explosive/E = new/obj/item/bio_chip/explosive(synd_mob)
	E.implant(synd_mob)
	synd_mob.faction |= "syndicate"
	synd_mob.update_icons()
	return 1


/datum/game_mode/proc/is_operatives_are_dead()
	for(var/datum/mind/operative_mind in syndicates)
		if(!ishuman(operative_mind.current))
			if(operative_mind.current)
				if(operative_mind.current.stat!=2)
					return 0
	return 1


/datum/game_mode/nuclear/declare_completion()
	var/disk_rescued = 1
	for(var/obj/item/disk/nuclear/D in GLOB.poi_list)
		if(!D.onCentcom())
			disk_rescued = 0
			break
	var/crew_evacuated = (SSshuttle.emergency.mode >= SHUTTLE_ESCAPE)
	//var/operatives_are_dead = is_operatives_are_dead()


	//nukes_left
	//station_was_nuked
	//derp //Used for tracking if the syndies actually haul the nuke to the station	//no
	//herp //Used for tracking if the syndies got the shuttle off of the z-level	//NO, DON'T FUCKING NAME VARS LIKE THIS

	if(!disk_rescued && station_was_nuked && !syndies_didnt_escape)
		SSticker.mode_result = "nuclear win - syndicate nuke"
		to_chat(world, "<FONT size = 3><B>Syndicate Major Victory!</B></FONT>")
		to_chat(world, "<B>[syndicate_name()] operatives have destroyed [station_name()]!</B>")

	else if(!disk_rescued && station_was_nuked && syndies_didnt_escape)
		SSticker.mode_result = "nuclear halfwin - syndicate nuke - did not evacuate in time"
		to_chat(world, "<FONT size = 3><B>Total Annihilation</B></FONT>")
		to_chat(world, "<B>[syndicate_name()] operatives destroyed [station_name()] but did not leave the area in time and got caught in the explosion.</B> Next time, don't lose the disk!")

	else if(!disk_rescued && !station_was_nuked && nuke_off_station && !syndies_didnt_escape)
		SSticker.mode_result = "nuclear halfwin - blew wrong station"
		to_chat(world, "<FONT size = 3><B>Crew Minor Victory</B></FONT>")
		to_chat(world, "<B>[syndicate_name()] operatives secured the authentication disk but blew up something that wasn't [station_name()].</B> Next time, don't lose the disk!")

	else if(!disk_rescued && !station_was_nuked && nuke_off_station && syndies_didnt_escape)
		SSticker.mode_result = "nuclear halfwin - blew wrong station - did not evacuate in time"
		to_chat(world, "<FONT size = 3><B>[syndicate_name()] operatives have earned Darwin Award!</B></FONT>")
		to_chat(world, "<B>[syndicate_name()] operatives blew up something that wasn't [station_name()] and got caught in the explosion.</B> Next time, don't lose the disk!")

	else if(disk_rescued && is_operatives_are_dead())
		SSticker.mode_result = "nuclear loss - evacuation - disk secured - syndi team dead"
		to_chat(world, "<FONT size = 3><B>Crew Major Victory!</B></FONT>")
		to_chat(world, "<B>The Research Staff has saved the disc and killed the [syndicate_name()] Operatives</B>")

	else if(disk_rescued)
		SSticker.mode_result = "nuclear loss - evacuation - disk secured"
		to_chat(world, "<FONT size = 3><B>Crew Major Victory</B></FONT>")
		to_chat(world, "<B>The Research Staff has saved the disc and stopped the [syndicate_name()] Operatives!</B>")

	else if(!disk_rescued && is_operatives_are_dead())
		SSticker.mode_result = "nuclear loss - evacuation - disk not secured"
		to_chat(world, "<FONT size = 3><B>Syndicate Minor Victory!</B></FONT>")
		to_chat(world, "<B>The Research Staff failed to secure the authentication disk but did manage to kill most of the [syndicate_name()] Operatives!</B>")

	else if(!disk_rescued && crew_evacuated)
		SSticker.mode_result = "nuclear halfwin - detonation averted"
		to_chat(world, "<FONT size = 3><B>Syndicate Minor Victory!</B></FONT>")
		to_chat(world, "<B>[syndicate_name()] operatives recovered the abandoned authentication disk but detonation of [station_name()] was averted.</B> Next time, don't lose the disk!")

	else if(!disk_rescued && !crew_evacuated)
		SSticker.mode_result = "nuclear halfwin - interrupted"
		to_chat(world, "<FONT size = 3><B>Neutral Victory</B></FONT>")
		to_chat(world, "<B>Round was mysteriously interrupted!</B>")
	..()
	return


/datum/game_mode/proc/auto_declare_completion_nuclear()
	if(length(syndicates) || GAMEMODE_IS_NUCLEAR)
		var/list/text = list("<br><FONT size=3><B>The syndicate operatives were:</B></FONT>")

		var/purchases = ""
		var/TC_uses = 0

		for(var/datum/mind/syndicate in syndicates)

			text += "<br><b>[syndicate.get_display_key()]</b> was <b>[syndicate.name]</b> ("
			if(syndicate.current)
				if(syndicate.current.stat == DEAD)
					text += "died"
				else
					text += "survived"
				if(syndicate.current.real_name != syndicate.name)
					text += " as <b>[syndicate.current.real_name]</b>"
			else
				text += "body destroyed"
			text += ")"
			for(var/obj/item/uplink/H in GLOB.world_uplinks)
				if(H && H.uplink_owner && H.uplink_owner==syndicate.key)
					TC_uses += H.used_TC
					purchases += H.purchase_log

		text += "<br>"

		text += "(Syndicates used [TC_uses] TC) [purchases]"

		if(TC_uses==0 && station_was_nuked && !is_operatives_are_dead())
			text += "<BIG><IMG CLASS=icon SRC=\ref['icons/badass.dmi'] ICONSTATE='badass'></BIG>"

		return text.Join("")

/proc/nukelastname(mob/M as mob) //--All praise goes to NEO|Phyte, all blame goes to DH, and it was Cindi-Kate's idea. Also praise Urist for copypasta ho.
	var/randomname = pick(GLOB.last_names)
	var/newname = sanitize(copytext_char(input(M,"You are the nuke operative [pick("Czar", "Boss", "Commander", "Chief", "Kingpin", "Director", "Overlord")]. Please choose a last name for your family.", "Name change", randomname), 1, MAX_NAME_LEN))

	if(!newname)
		newname = randomname

	else
		if(newname == "Unknown" || newname == "floor" || newname == "wall" || newname == "rwall" || newname == "_")
			to_chat(M, "That name is reserved.")
			return nukelastname(M)

	return newname


/datum/game_mode/nuclear/set_scoreboard_vars()
	var/datum/scoreboard/scoreboard = SSticker.score
	var/foecount = 0

	for(var/datum/mind/M in SSticker.mode.syndicates)
		foecount++
		if(!M || !M.current)
			scoreboard.score_ops_killed++
			continue

		if(M.current.stat == DEAD)
			scoreboard.score_ops_killed++

		else if(M.current.restrained())
			scoreboard.score_arrested++

	if(foecount == scoreboard.score_arrested)
		scoreboard.all_arrested = TRUE // how the hell did they manage that

	var/obj/machinery/nuclearbomb/syndicate/nuke = locate() in GLOB.poi_list
	if(nuke?.r_code != "Nope")
		var/area/A = get_area(nuke)

		var/list/thousand_penalty = list(/area/station/engineering/solar)
		var/list/fiftythousand_penalty = list(
			/area/station/security/main,
			/area/station/security/brig,
			/area/station/security/armory,
			/area/station/security/checkpoint/secondary
			)

		if(is_type_in_list(A, thousand_penalty))
			scoreboard.nuked_penalty = 1000

		else if(is_type_in_list(A, fiftythousand_penalty))
			scoreboard.nuked_penalty = 50000

		else if(istype(A, /area/station/engineering/engine))
			scoreboard.nuked_penalty = 100000

		else
			scoreboard.nuked_penalty = 10000

	var/killpoints = scoreboard.score_ops_killed * 250
	var/arrestpoints = scoreboard.score_arrested * 1000
	scoreboard.crewscore += killpoints
	scoreboard.crewscore += arrestpoints
	if(scoreboard.nuked)
		scoreboard.crewscore -= scoreboard.nuked_penalty



/datum/game_mode/nuclear/get_scoreboard_stats()
	var/datum/scoreboard/scoreboard = SSticker.score
	var/foecount = 0
	var/crewcount = 0

	var/diskdat = ""
	var/bombdat = null

	for(var/datum/mind/M in SSticker.mode.syndicates)
		foecount++

	for(var/mob in GLOB.mob_living_list)
		var/mob/living/C = mob
		if(ishuman(C) || is_ai(C) || isrobot(C))
			if(C.stat == DEAD)
				continue
			if(!C.client)
				continue
			crewcount++

	var/obj/item/disk/nuclear/N = locate() in GLOB.poi_list
	if(istype(N))
		var/atom/disk_loc = N.loc
		while(!isturf(disk_loc))
			if(ismob(disk_loc))
				var/mob/M = disk_loc
				diskdat += "Carried by [M.real_name] "
			if(isobj(disk_loc))
				var/obj/O = disk_loc
				diskdat += "in \a [O]"
			disk_loc = disk_loc.loc
		diskdat += "in [disk_loc.loc]"


	if(!diskdat)
		diskdat = "WARNING: Nuked_penalty could not be found, look at [__FILE__], [__LINE__]."

	var/dat = ""
	dat += "<b><u>Mode Statistics</b></u><br>"

	dat += "<b>Number of Operatives:</b> [foecount]<br>"
	dat += "<b>Number of Surviving Crew:</b> [crewcount]<br>"

	dat += "<b>Final Location of Nuke:</b> [bombdat]<br>"
	dat += "<b>Final Location of Disk:</b> [diskdat]<br>"

	dat += "<br>"

	dat += "<b>Operatives Arrested:</b> [scoreboard.score_arrested] ([scoreboard.score_arrested * 1000] Points)<br>"
	dat += "<b>All Operatives Arrested:</b> [scoreboard.all_arrested ? "Yes" : "No"] (Score tripled)<br>"

	dat += "<b>Operatives Killed:</b> [scoreboard.score_ops_killed] ([scoreboard.score_ops_killed * 1000] Points)<br>"
	dat += "<b>Station Destroyed:</b> [scoreboard.nuked ? "Yes" : "No"] (-[scoreboard.nuked_penalty] Points)<br>"
	dat += "<hr>"

	return dat

#undef NUKESCALINGMODIFIER
