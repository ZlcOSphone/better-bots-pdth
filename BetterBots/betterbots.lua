if RequiredScript == "lib/managers/criminalsmanager" then
	for k, v in pairs(tweak_data.character.presets.weapon.gang_member) do
		v.aim_delay = { 0, 0 }
		v.focus_delay = 0
		v.RELOAD_SPEED = 1
		v.spread = 5
	end
	for k, v in pairs(tweak_data.character.presets.weapon.gang_member.beretta92.FALLOFF) do
		v.recoil = { 0.15, 0.15 }
	end
	for k, v in pairs(tweak_data.character) do
		if type(v) == "table" and v.speech_prefix == "rb2" then
			v.SPEED_WALK = tweak_data.player.movement_state.standard.movement.speed.STANDARD_MAX
			v.SPEED_RUN = tweak_data.player.movement_state.standard.movement.speed.RUNNING_MAX
			v.dodge = tweak_data.character.presets.dodge.ninja
			v.damage.hurt_severity = tweak_data.character.tank.damage.hurt_severity
			v.damage.MIN_DAMAGE_INTERVAL = 0.15
		end
	end
end

if RequiredScript == "lib/managers/group_ai_states/groupaistatebase" then
	local old_tasestart = GroupAIStateBase.on_tase_start
	function GroupAIStateBase:on_tase_start(cop_key, criminal_key)
		local bot_record = self._ai_criminals[criminal_key]
		if bot_record then
			local taser_unit = self._police[cop_key].unit
			if not managers.game_play_central._enemy_contour_units[taser_unit:key()] then
				bot_record.unit:sound():say("f32x_any", true)
				managers.game_play_central:add_enemy_contour(taser_unit)
			end
		end
		return old_tasestart(self, cop_key, criminal_key)
	end
end

if RequiredScript == "lib/units/player_team/teamaidamage" then
	local old_damage = TeamAIDamage._apply_damage
	function TeamAIDamage:_apply_damage(attack_data, result)
		local damage_percent, health_subtracted = old_damage(self, attack_data, result)
		local data = self._unit:brain()._logic_data
		if data then
			if not data.internal_data.said_hurt and self._health_ratio <= 0.2 and not self:need_revive() then
				data.internal_data.said_hurt = true
				self._unit:sound():say("g80x_plu", true)
			end
		end
		return damage_percent, health_subtracted
	end
	local old_regen = TeamAIDamage._regenerated
	function TeamAIDamage:_regenerated()
		local data = self._unit:brain()._logic_data
		if data then
			if data.internal_data.said_hurt and self._health_ratio == 1 then
				data.internal_data.said_hurt = false
			end
		end
		return old_regen(self)
	end
	function TeamAIDamage:friendly_fire_hit()
		return
	end
end

if RequiredScript == "lib/units/weapons/raycastweaponbase" then
	-- This code was originally written by Martini
	local init_original = RaycastWeaponBase.init
	local setup_original = RaycastWeaponBase.setup
	function RaycastWeaponBase:init(unit)
		init_original(self, unit)
		self._bullet_slotmask = self._bullet_slotmask - World:make_slot_mask(16)
	end
	function RaycastWeaponBase:setup(setup_data)
		setup_original(self, setup_data)
		self._bullet_slotmask = self._bullet_slotmask - World:make_slot_mask(16)
	end
end

if RequiredScript == "lib/managers/navigationmanager" then
	function NavigationManager:find_cover_in_nav_seg_near_pos(nav_seg_id, defend_pos, max_distance)
		local search_params = {
			near_pos = defend_pos,
			in_nav_seg = nav_seg_id,
			max_distance = max_distance
		}
		return self._quad_field:find_cover(search_params)
	end
end

if RequiredScript == "lib/units/player_team/logics/teamailogicassault" then
	local old_upd = TeamAILogicAssault._upd_aim
	function TeamAILogicAssault._upd_aim(data, my_data)
		old_upd(data, my_data)
		if my_data.focus_enemy then
			if my_data.focus_enemy.verified then
				if not my_data.firing then
					data.unit:movement():set_allow_fire(true)
					my_data.firing = true
				end
			end
		end
	end
	function TeamAILogicAssault.find_escort(criminal)
		local head_pos = criminal:movement():m_head_pos()
		local look_vec = criminal:movement():m_rot():y()
		local best_esc
		local my_tracker = criminal:movement():nav_tracker()
		local chk_vis_func = my_tracker.check_visibility
		for key, u_data in pairs(managers.enemy:all_civilians()) do
			if chk_vis_func(my_tracker, u_data.unit:movement():nav_tracker()) then
				if tweak_data.character[u_data.unit:base()._tweak_table].is_escort then
					local anim_data = u_data.unit:anim_data()
					if anim_data.move or anim_data.panic then
						local u_head_pos = u_data.unit:movement():m_head_pos()
						local vec = u_head_pos - head_pos
						if vec:angle(look_vec) <= 90 then
							if mvector3.normalize(vec) <= 300 then
								local slotmask = managers.slot:get_mask("AI_visibility")
								if not World:raycast("ray", head_pos, u_head_pos, "slot_mask", slotmask, "ray_type", "ai_vision") then
									best_esc = u_data.unit
								end
							end
						end
					end
				end
			end
		end
		return best_esc
	end
	function TeamAILogicAssault.find_dom_target(criminal)
		local head_pos = criminal:movement():m_head_pos()
		local look_vec = criminal:movement():m_rot():y()
		local best_dom, best_dom_prio
		local my_tracker = criminal:movement():nav_tracker()
		local chk_vis_func = my_tracker.check_visibility
		for key, u_data in pairs(managers.enemy:all_enemies()) do
			if not managers.groupai:state():get_assault_mode() then
				if chk_vis_func(my_tracker, u_data.unit:movement():nav_tracker()) then
					local char_tweak = tweak_data.character[u_data.unit:base()._tweak_table]
					if char_tweak.surrender_easy or char_tweak.surrender_hard then
						local anim_data = u_data.unit:anim_data()
						if not anim_data.hands_tied then
							if managers.groupai:state():police_hostage_count() < 4 or (anim_data.hands_back or anim_data.surrender) then
								local u_head_pos = u_data.unit:movement():m_head_pos()
								local vec = u_head_pos - head_pos
								if vec:angle(look_vec) <= 90 then
									if mvector3.normalize(vec) <= 1200 then
										local slotmask = managers.slot:get_mask("AI_visibility")
										if not World:raycast("ray", head_pos, u_head_pos, "slot_mask", slotmask, "ray_type", "ai_vision") then
											local is_turned = u_data.unit:movement():m_rot():y():dot(vec) > 0
											local is_hurt = u_data.unit:character_damage()._health_ratio < 1
											if anim_data.hands_back or anim_data.surrender or is_turned or is_hurt then
												u_data.priority = anim_data.hands_back and 1 or anim_data.surrender and 2 or is_turned and 3 or is_hurt and 4 or 5
												if not best_dom_prio or u_data.priority < best_dom_prio then
													best_dom = u_data.unit
													best_dom_prio = u_data.priority
												end
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
		return best_dom
	end
	function TeamAILogicAssault.intimidate_target(data, criminal, intim_unit)
		local sound_name
		local act_name = "arrest"
		local anim_data = intim_unit:anim_data()
		local is_escort = tweak_data.character[intim_unit:base()._tweak_table].is_escort
		if anim_data.move and is_escort then
			sound_name = "e05x_sin"
		elseif anim_data.panic and is_escort then
			sound_name = "e03x_sin"
		elseif anim_data.hands_back then
			sound_name = "l03x_sin"
		elseif anim_data.surrender then
			sound_name = "l02x_sin"
		else
			sound_name = "l01x_sin"
			act_name = "stop"
		end
		criminal:sound():say(sound_name, true)
		if not criminal:movement():chk_action_forbidden("action") then
			local intim_action = { type = "act", variant = act_name, body_part = 3, align_sync = true }
			if criminal:brain():action_request(intim_action) then
				data.internal_data.gesture_arrest = true
			end
		end
		if intim_unit then
			intim_unit:brain():on_intimidated(1, criminal)
		end
	end
	function TeamAILogicAssault.interact_check(data)
		if not data.unit:character_damage():need_revive() then
			if not data.unit:anim_data().tased then
				local my_data = data.internal_data
				if not my_data.acting then
					if not data.unit:sound():speaking() then
						if not my_data._intimidate_t or my_data._intimidate_t + 2 < data.t then
							local nmy = TeamAILogicAssault.find_enemy_to_mark(data.unit)
							local civ = TeamAILogicIdle.find_civilian_to_intimidate(data.unit, 90, 1200)
							local dom = TeamAILogicAssault.find_dom_target(data.unit)
							local esc = TeamAILogicAssault.find_escort(data.unit)
							my_data._intimidate_t = data.t
							if nmy and not managers.game_play_central._enemy_contour_units[nmy:key()] then
								TeamAILogicAssault._mark_special_t = data.t
								TeamAILogicAssault.mark_enemy(data, data.unit, nmy, true, true)
							elseif civ then
								TeamAILogicIdle.intimidate_civilians(data, data.unit, true, true)
							elseif dom then
								TeamAILogicAssault.intimidate_target(data, data.unit, dom)
							elseif esc then
								TeamAILogicAssault.intimidate_target(data, data.unit, esc)
							end
						end
					end
				end
			end
		end
	end
	function TeamAILogicAssault._chk_change_weapon(data, my_data)
		local selection
		local weapon_base = data.unit:inventory():equipped_unit():base()
		if weapon_base._ammo_remaining_in_clip <= math.ceil(weapon_base._ammo_max_per_clip/10) then
			local equipped_selection = data.unit:inventory():equipped_selection()
			local damage = data.unit:character_damage()
			if equipped_selection == 1 and not damage:need_revive() then
				selection = 2
			else
				selection = 1
			end
		end
		if selection and not data.unit:anim_data().reload then
			data.unit:inventory():equip_selection(selection, false)
			weapon_base:on_reload()
		end
	end
	function TeamAILogicAssault._get_priority_enemy(data, enemies)
		if managers.groupai:state():whisper_mode() then return end
		local best_target, best_target_priority_slot, best_target_priority, best_threat, best_threat_priority_slot, best_threat_priority
		for key, enemy_data in pairs(enemies) do
			local enemy_vec = data.m_pos - enemy_data.m_pos
			local distance = mvector3.normalize(enemy_vec)
			local dis_var = math.ceil(distance/267)
			local reaction
			local target_priority = distance
			local target_priority_slot = 0
			local threat_priority = distance
			local threat_priority_slot = 0
			local enemy_type = enemy_data.unit:base()._tweak_table
			if enemy_data.verified then
				reaction = "assault"
				target_priority_slot = dis_var
				if enemy_type == "sniper" then
					target_priority_slot = 1
				elseif enemy_type == "taser" then
					target_priority_slot = (target_priority_slot/4)
				elseif enemy_type == "spooc" then
					target_priority_slot = (target_priority_slot/3)
				elseif enemy_type == "tank" then
					target_priority_slot = (target_priority_slot/2)
				elseif enemy_type == "shield" then
					local spin = enemy_vec:to_polar_with_reference(enemy_data.unit:movement():m_rot():y(), math.UP).spin
					target_priority_slot = math.abs(spin) >= 60 and target_priority_slot or 0
				end
				if target_priority_slot > 10 then
					target_priority_slot = 10
				end
			else
				reaction = "idle"
				threat_priority_slot = dis_var
				if threat_priority_slot > 10 then
					threat_priority_slot = 10
				end
			end
			if target_priority_slot ~= 0 then
				local best = false
				if not best_target then
					best = true
				elseif best_target_priority_slot > target_priority_slot then
					best = true
				elseif target_priority_slot == best_target_priority_slot and best_target_priority > target_priority then
					best = true
				end
				if best then
					best_target = {
						enemy_data = enemy_data,
						reaction = reaction,
						key = key
					}
					best_target_priority_slot = target_priority_slot
					best_target_priority = target_priority
				end
			end
			if threat_priority_slot ~= 0 then
				local best = false
				if not best_threat then
					best = true
				elseif best_threat_priority_slot > threat_priority_slot then
					best = true
				elseif threat_priority_slot == best_threat_priority_slot and best_threat_priority > threat_priority then
					best = true
				end
				if best then
					best_threat = {
						enemy_data = enemy_data,
						reaction = reaction,
						key = key
					}
					best_threat_priority_slot = threat_priority_slot
					best_threat_priority = threat_priority
				end
			end
		end
		return best_target, best_threat, best_target_priority_slot, best_threat_priority_slot
	end
	function TeamAILogicAssault.get_cover_data(data)
		local cover_data
		if data.objective then
			if data.objective.follow_unit then
				local player_pos = mvector3.copy(data.objective.follow_unit:movement():nav_tracker():field_position())
				local nav_seg = managers.navigation:get_nav_seg_from_pos(player_pos, false)
				cover_data = managers.navigation:find_cover_in_nav_seg_near_pos(nav_seg, player_pos, 800)
			end
		end
		return cover_data
	end
	function TeamAILogicAssault._update_cover(data)
		data.t = TimerManager:game():time()
		local my_data = data.internal_data
		local best_cover = my_data.best_cover
		if my_data.want_cover then
			local focus_enemy = my_data.focus_enemy
			if focus_enemy then
				local threat_pos = mvector3.copy(focus_enemy.unit:movement():nav_tracker():field_position())
				local find_new = (focus_enemy.verified and focus_enemy.verified_dis <= 800) or data.unit:anim_data().reload or not my_data.moving_to_cover
				if find_new then
					if not best_cover or not CopLogicAttack._verify_cover(best_cover[1], threat_pos, 100, 800) then
						local found_cover = TeamAILogicAssault.get_cover_data(data)
						if found_cover then
							local better_cover = {found_cover}
							CopLogicAttack._set_best_cover(data, my_data, better_cover)
							local offset_pos, yaw = CopLogicAttack._get_cover_offset_pos(data, better_cover, threat_pos)
							if offset_pos then
								better_cover[5] = offset_pos
								better_cover[6] = yaw
							end
						end
					end
				end
				local in_cover = my_data.in_cover
				if in_cover then
					in_cover[3], in_cover[4] = CopLogicAttack._chk_covered(data, data.m_pos, threat_pos, my_data.ai_visibility_slotmask)
				end
			end
		else
			local nearest_cover = my_data.nearest_cover
			if nearest_cover and 100 < mvector3.distance(nearest_cover[1][1], data.m_pos) then
				CopLogicAttack._set_nearest_cover(my_data, nil)
			end
			if best_cover and 100 < mvector3.distance(best_cover[1][1], data.m_pos) then
				CopLogicAttack._set_best_cover(data, my_data, nil)
			end
		end
		CopLogicBase.queue_task(my_data, my_data.cover_update_task_key, TeamAILogicAssault._update_cover, data, TimerManager:game():time() + 1)
	end
	local old_update = TeamAILogicAssault._update_enemy_detection
	function TeamAILogicAssault._update_enemy_detection(data)
		TeamAILogicAssault.interact_check(data)
		return old_update(data)
	end
end

if RequiredScript == "lib/units/player_team/logics/teamailogicidle" then
	local old_enter = TeamAILogicIdle.enter
	function TeamAILogicIdle.enter(data, new_logic_name, enter_params)
		old_enter(data, new_logic_name, enter_params)
		if managers.groupai:state():enemy_weapons_hot() then
			if not data.internal_data.acting then
				if not data.unit:anim_data().crouch then
					CopLogicAttack._chk_request_action_crouch(data)
				end
				if not data.unit:anim_data().reload then
					local equipped_selection = data.unit:inventory():equipped_selection()
					local damage = data.unit:character_damage()
					if equipped_selection ~= 2 and not damage:need_revive() then
						data.unit:inventory():equip_selection(2, false)
					end
					local ammo_max, ammo_cur = data.unit:inventory():equipped_unit():base():ammo_info()
					if ammo_cur < ammo_max then
						local reload_action = { type = "reload", body_part = 3 }
						data.unit:brain():action_request(reload_action)
					end
				end
			end
		end
	end
	local old_relocate = TeamAILogicIdle._calculate_should_relocate
	function TeamAILogicIdle._calculate_should_relocate(data, my_data, objective)
		old_relocate(data, my_data, objective)
		my_data.relocate_chk_t = data.t
	end
	local old_detect = TeamAILogicIdle._detect_enemies
	function TeamAILogicIdle._detect_enemies(data, my_data)
		local delay = old_detect(data, my_data)
		for e_key, e_data in pairs(managers.enemy:all_enemies()) do
			local anim_data = e_data.unit:anim_data()
			if anim_data.surrender or anim_data.hands_back or e_data.unit:brain()._current_logic_name == ("trade" or "intimidated") then
				my_data.detected_enemies[e_key] = nil
			end
		end
		return delay
	end
	local old_update = TeamAILogicIdle._update_enemy_detection
	function TeamAILogicIdle._update_enemy_detection(data)
		TeamAILogicAssault.interact_check(data)
		return old_update(data)
	end
end

if RequiredScript == "lib/units/player_team/logics/teamailogictravel" then
	local old_enter = TeamAILogicTravel.enter
	function TeamAILogicTravel.enter(data, new_logic_name, enter_params)
		old_enter(data, new_logic_name, enter_params)
		if not data.internal_data.acting then
			CopLogicAttack._chk_request_action_stand(data)
		end
	end
	local old_occ = TeamAILogicTravel._determine_destination_occupation
	function TeamAILogicTravel._determine_destination_occupation(data, objective)
		local occupation = old_occ(data, objective)
		if objective.follow_unit then
			if objective.type ~= "revive" then
				local cover = TeamAILogicAssault.get_cover_data(data)
				if cover then
					local cover_entry = {cover}
					occupation = { type = "defend", cover = cover_entry }
				else
					local follow_pos = mvector3.copy(objective.follow_unit:movement():nav_tracker():field_position())
					local to_pos = CopLogicTravel._get_pos_on_wall(follow_pos, 400)
					if to_pos then
						occupation = { type = "defend", pos = to_pos }
					end
				end
			end
		end
		return occupation
	end
	local old_upd = TeamAILogicTravel._upd_pathing
	function TeamAILogicTravel._upd_pathing(data, my_data)
		if data.objective then
			if data.objective.follow_unit then
				if data.objective.type ~= "revive" then
					if data.objective.in_place then
						if not my_data.moving_to_cover then
							if not data.unit:anim_data().reload then
								local head_pos = data.unit:movement():m_head_pos()
								local u_head_pos = data.objective.follow_unit:movement():m_head_pos()
								local slotmask = managers.slot:get_mask("AI_visibility")
								local ray = World:raycast("ray", head_pos, u_head_pos, "slot_mask", slotmask, "ray_type", "ai_vision")
								if mvector3.distance(head_pos, u_head_pos) <= 800 and not ray then
									local focus_enemy = my_data.focus_enemy
									if focus_enemy and focus_enemy.verified then
										CopLogicBase._exit(data.unit, "assault")
									else
										CopLogicBase._exit(data.unit, "idle", {scan = true})
									end
								end
							end
						end
					end
				end
			end
		end
		return old_upd(data, my_data)
	end
	local old_update = TeamAILogicTravel._update_enemy_detection
	function TeamAILogicTravel._update_enemy_detection(data)
		TeamAILogicAssault.interact_check(data)
		return old_update(data)
	end
end