/datum/computer_file/program/atmos_control
	filename = "atmoscontrol"
	filedesc = "Atmosphere Control"
	ui_module_path = /datum/ui_module/atmos_control
	program_icon_state = "atmos_control"
	program_key_state = "atmos_key"
	program_menu_icon = "shuffle"
	extended_desc = "This program allows remote control of air alarms. This program can not be run on tablet computers."
	required_access = access_atmospherics
	requires_ntnet = 1
	network_destination = "atmospheric control system"
	requires_ntnet_feature = NTNET_SYSTEMCONTROL
	usage_flags = PROGRAM_LAPTOP | PROGRAM_CONSOLE
	size = 17

/datum/ui_module/atmos_control
	name = "Atmospherics Control"
	var/obj/access = new()
	var/emagged = 0
	var/ui_ref
	var/list/monitored_alarms = list()

/datum/ui_module/atmos_control/New(atmos_computer, var/list/req_access, var/list/req_one_access, monitored_alarm_ids)
	..()

	if(istype(req_access))
		access.req_access = req_access
	else if(req_access)
		log_debug("\The [src] was given an unepxected req_access: [req_access]")

	if(istype(req_one_access))
		access.req_one_access = req_one_access
	else if(req_one_access)
		log_debug("\The [src] given an unepxected req_one_access: [req_one_access]")

	if(monitored_alarm_ids)
		for(var/obj/machinery/alarm/alarm in SSmachines.machinery)
			if(alarm.alarm_id && alarm.alarm_id in monitored_alarm_ids)
				monitored_alarms += alarm
		// machines may not yet be ordered at this point
		monitored_alarms = dd_sortedObjectList(monitored_alarms)

/datum/ui_module/atmos_control/Topic(href, href_list)
	if(..())
		return 1

	if(href_list["alarm"])
		if(ui_ref)
			var/obj/machinery/alarm/alarm = locate(href_list["alarm"]) in (monitored_alarms.len ? monitored_alarms : SSmachines.machinery)
			if(alarm)
				var/datum/topic_state/TS = generate_state(alarm)
				alarm.ui_interact(usr, master_ui = ui_ref, state = TS)
		return 1

/datum/ui_module/atmos_control/ui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "AtmosControlProgram")
		ui.open()

/datum/ui_module/atmos_control/proc/ui_data(mob/user)
	var/list/data = host.initial_data()
	var/alarms[0]

	// TODO: Move these to a cache, similar to cameras
	for(var/obj/machinery/alarm/alarm in (monitored_alarms.len ? monitored_alarms : SSmachines.machinery))
		alarms[++alarms.len] = list("name" = sanitize(alarm.name), "ref"= "\ref[alarm]", "danger" = max(alarm.danger_level, alarm.alarm_area.atmosalm))
	data["alarms"] = alarms

	return data

/datum/ui_module/atmos_control/proc/generate_state(air_alarm)
	var/datum/topic_state/air_alarm/state = new()
	state.atmos_control = src
	state.air_alarm = air_alarm
	return state

/datum/topic_state/air_alarm
	var/datum/ui_module/atmos_control/atmos_control	= null
	var/obj/machinery/alarm/air_alarm					= null

/datum/topic_state/air_alarm/can_use_topic(var/src_object, var/mob/user)
	if(has_access(user))
		return STATUS_INTERACTIVE
	return STATUS_UPDATE

/datum/topic_state/air_alarm/href_list(var/mob/user)
	var/list/extra_href = list()
	extra_href["remote_connection"] = 1
	extra_href["remote_access"] = has_access(user)

	return extra_href

/datum/topic_state/air_alarm/proc/has_access(var/mob/user)
	return user && (isAI(user) || atmos_control.access.allowed(user) || atmos_control.emagged || air_alarm.rcon_setting == RCON_YES || (air_alarm.alarm_area.atmosalm && air_alarm.rcon_setting == RCON_AUTO))
