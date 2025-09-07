pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- ant & mouse house
-- by cole cecil

debug = false
debug_was_on = false
is_menu = true
last_frame_time = 0
delta_t = 0

selected_mode = "active"
menu_cursor = {}
menu_cursor_visible_time = .4
menu_cursor_cycle_time = .8

mouse = nil
ants = {}
foods = {}
phrmns = {}
tv = {}
faucet = {}
last_ant_entry = nil
ant_entry_interval = 5

function _init()
 poke(0x5f36, 64)

 menu_cursor.active = true
 menu_cursor.elapsed_time = 0
 
 init_ant_hole_pos()
 init_mouse()
 init_tv()
 init_faucet()
end

function _update60()
 delta_t = time() -
   last_frame_time
 last_frame_time = time()
 
 if is_menu then
  update_menu()
 else
  update_game()
 end
end

function _draw()
 if is_menu then
  draw_menu()
 else
  draw_game()
 end
end

function update_menu()
 if selected_mode == "active"
   then
  menu_cursor.pos = {
   x = 41,
   y = 52
  }
 else
  menu_cursor.pos = {
   x = 41,
   y = 58
  }
 end
 
 menu_cursor.elapsed_time +=
   delta_t
 if menu_cursor.elapsed_time >
   menu_cursor_cycle_time then
  menu_cursor.elapsed_time = 0
 end
 
 if menu_cursor.active then
  if btnp(⬆️) then
   selected_mode = "active"
   menu_cursor.elapsed_time = 0
  end
  if btnp(⬇️) then
   selected_mode = "passive"
   menu_cursor.elapsed_time = 0
  end
 
  if btnp(❎) then
   menu_cursor.active = false
   menu_cursor.elapsed_time = 0
   menu_cursor.submit_time = 0
  end
 else
  menu_cursor.submit_time +=
    delta_t
  if menu_cursor.submit_time >
    3 * menu_cursor_cycle_time
    then
   is_menu = false
  end
 end
end

function update_game()
 if btnp(🅾️) then
  debug = not debug
  if debug then
   printh("", "log",
     not debug_was_on)
   debug_was_on = true
  end
 end

 for i, food in ipairs(foods) do
  if food.amount <= 0 then
   if debug then
    log("food completely eaten",
      {
       id = food.id,
       pos = food.pos,
       amount = food.amount
      })
   end
   for ant in all(ants) do
    if ant.food_detected and
      ant.food_detected.id ==
      food.id then
     log("ant's detected " ..
       "food was eaten", {
        id = ant.id,
        pos = ant.pos,
        dir = ant.dir,
        food_id = food.id,
        food_pos = food.pos
       })
     ant.food_detected = nil
    end
   end
   deli(foods, i)
  end
 end

 if count(ants) == 0 or
   time() - last_ant_entry > 5
   then
  add(
   ants,
   spawn_ant(foods, phrmns)
  )
  last_ant_entry = time()
 end
 
 for i, ant in ipairs(ants) do
  if ant.home_arrival_time !=
    nil and time() -
    ant.home_arrival_time > .75
    then
   deli(ants, i)
  else
   ant_try_eating(ant)
   ant_excrete_phrmn(ant,
     phrmns)
   set_ant_dir(ant, foods,
     phrmns)
   move_ant(ant)
  end
 end

 check_mouse_eating()
 set_mouse_dir()
 move_mouse()
 
 phrmns_evap(phrms)
 
 update_tv()
 update_faucet()
end

function draw_menu()
 cls(0)
	palt(0, true)
	palt(15, true)

	color(14)
	print("\^w\^tant & mouse" ..
	  "\nhouse", 21, 5)
 color(7)
	print("select mode:\n", 41, 40)

 local cursor_visible =
   menu_cursor.elapsed_time <=
   menu_cursor_visible_time
 if cursor_visible and
   menu_cursor.active	then
	 spr(16, menu_cursor.pos.x - 1,
	   menu_cursor.pos.y - 2, 1, 1,
	   true)
	end
	
	if menu_cursor.active or
	  (selected_mode == "active"
	  and cursor_visible) then
	 local clr = 7
	 if selected_mode == "active"
	   then
	  clr = 9
	 end
	 print("  active", 41, 52, clr)
	end
	if menu_cursor.active or
	  (selected_mode == "passive"
	  and cursor_visible) then
	 local clr = 7
	 if selected_mode == "passive"
	   then
	  clr = 9
	 end
	 print("  passive", 41, 58,
	   clr)
	end
	
	if menu_cursor.active then
  color(2)
  line(8, 72, 120, 72)
  if selected_mode == "active"
    then
   print("control the mouse " ..
     "and place", 8, 82)
   print("cheese crumbs for " ..
     "the ants!\n")
   print("⬅️➡️⬆️⬇️: move")
   print("❎: nibble " ..
     "cheese")
  else
   print("the mouse is " ..
     "controlled", 8, 82)
   print("automatically. " ..
     "sit back and")
   print("enjoy the show!\n")
  end
  print("🅾️: toggle blacklight")
  print("    (to see pheromone trails)")
	end
end

function draw_game()
	cls(15)
	palt(0, false)
	palt(15, true)
	
	map(0, 0, 0, 0, 16, 16)

 if debug then
  draw_phrmns(phrmns)
  local hole =
    get_ant_hole_pos()
  pset(hole.x - .5, hole.y - .5,
    14)
 end
 
 for ant in all(ants) do
  draw_ant(ant)
 end

 if mouse.anim != "run_up" and
   mouse.anim != "run_down" then
  draw_mouse()
 end

 for food in all(foods) do
  draw_food(food)
 end
 
 if mouse.anim == "run_up" or
   mouse.anim == "run_down" then
  draw_mouse()
 end

 map(16, 0, 0, 0, 16, 16)
 
 draw_tv()
 draw_faucet_drip()
end
-->8
-- ants

ant_hole_pos = nil
ant_current_id = 0

ant_speed = 1.5
ant_time_limit = 120
ant_dir_change_time = 1
ant_max_angle_change = .15
ant_food_detect_dist = 10
ant_sense_area_vrtcs = 6
ant_phrmn_detect_angle = .2
ant_phrmn_detect_dist = 5

function spawn_ant(foods,
  phrmns)
 local ant = {
  id = get_ant_id(),
  pos = get_ant_hole_pos(),
  waypoints = {
   get_ant_hole_pos()
  },
		entry_time = time(),
		home_arrival_time = nil,
		dir = nil,
		dir_change_time = nil,
		food_detected = nil,
		food_held = nil,
		sense_area = nil,
		phrmn_following = nil
 }
 set_ant_dir(ant, foods, phrmns)

 if debug then
  log("ant spawned", {
   id = ant.id,
   pos = ant.pos,
   dir = ant.dir
  })
 end

 return ant
end

function init_ant_hole_pos()
 local pos_options = {}

 for y = 52, 95 do
  add(pos_options, {
   x = 8,
   y = y
  })
 end
 for y = 112, 122 do
  add(pos_options, {
   x = 8,
   y = y
  })
 end
 for y = 64, 80 do
  add(pos_options, {
   x = 119,
   y = y
  })
 end
 for x = 58, 100 do
  add(pos_options, {
   x = x,
   y = 16
  })
 end
 for x = 9, 67 do
  add(pos_options, {
   x = x,
   y = 122
  })
 end
 
 ant_hole_pos = rnd(pos_options)
 ant_hole_pos.x += .5
 ant_hole_pos.y += .5
end

function get_ant_hole_pos()
 return {
  x = ant_hole_pos.x,
  y = ant_hole_pos.y
 }
end

function get_ant_id()
 if ant_current_id == 32767 then
  ant_current_id = 1
 else
  ant_current_id += 1
 end
 return ant_current_id
end

function set_ant_sense_area(ant)
 local sense_area = {}
 local look_angle =
   atan2(ant.dir.x, ant.dir.y)
 local angle_incr = (2 *
   ant_phrmn_detect_angle) /
   (ant_sense_area_vrtcs - 2)

 sense_area[1] = ant.pos
 for i = 2, ant_sense_area_vrtcs
   do
  local angle_to_vrtx =
    (look_angle -
    ant_phrmn_detect_angle) +
    angle_incr * (i - 2)
  local vrtx_dir = {
   x = cos(angle_to_vrtx),
   y = sin(angle_to_vrtx)
  }
  sense_area[i] = {
   x = ant.pos.x + vrtx_dir.x *
     ant_phrmn_detect_dist,
   y = ant.pos.y + vrtx_dir.y *
     ant_phrmn_detect_dist
  }
 end

 ant.sense_area = sense_area
end

function set_ant_dir(ant, foods,
  phrmns)
 if ant.dir == nil or time() -
   ant.dir_change_time >
   ant_dir_change_time then
  if ant_returning(ant) then
   set_ant_home_dir(ant, phrmns)
  else
   local food =
     ant.food_detected
   if food == nil then
    food = ant_detect_food(ant,
      foods)
    if food != nil then
     if debug then
      log("ant detected food", {
       id = ant.id,
       pos = ant.pos,
       dir = ant.dir,
       food_id = food.id,
       food_pos = food.pos
      })
     end
     if ant.phrmn_following !=
       nil then
      if debug then
       log("ant added waypoint",
         {
          reason = "detected " ..
            "food while " ..
            "following " ..
            "pheromone trail",
          id = ant.id,
          waypoint = ant.pos,
          phrmmn_id =
            ant.phrmn_following
         })
      end
      ant.phrmn_following = nil
      add(ant.waypoints, {
       x = ant.pos.x,
       y = ant.pos.y
      })
     end
    end
   end
   if food != nil then
    ant.food_detected = food
    set_ant_food_dir(ant, food)
    ant.sense_area = nil
   else
    set_ant_explr_dir(ant,
      phrmns)
   end
  end
 end
end

function set_ant_home_dir(ant,
  phrmns)
 local waypoints_left =
   count(ant.waypoints)
 local waypoint = ant.waypoints[
  waypoints_left
 ]

 if waypoints_left > 1 and
   abs(waypoint.x - ant.pos.x) <
   1 and
   abs(waypoint.y - ant.pos.y) <
   1 then
  local old_waypoint =
    deli(ant.waypoints)
  waypoint = ant.waypoints[
   waypoints_left - 1
  ]
  if debug then
   log("ant reached waypoint", {
    id = ant.id,
    pos = ant.pos,
    dir = ant.dir,
    waypoint = old_waypoint,
    new_waypoint = waypoint
   })
  end
 end

 optimize_waypoints(ant)
 waypoint = ant.waypoints[
   count(ant.waypoints)]

 local angle = atan2(
  waypoint.x - ant.pos.x,
  waypoint.y - ant.pos.y
 )
 ant.dir = {
  x = cos(angle),
  y = sin(angle)
 }
 ant.dir_change_time = time()
end

function optimize_waypoints(ant)
 local waypoints_left
 local wp_discarded
 repeat
  waypoints_left =
    count(ant.waypoints)
  wp_discarded = false
  wp = ant.waypoints[
    waypoints_left]
  home = ant.waypoints[1]
  if waypoints_left > 1 and
    distance(wp, home) >
    distance(ant.pos, home) then
   if debug then
    local new_wp = nil
    if waypoints_left > 2 then
     new_wp = ant.waypoints[
       waypoints_left - 1]
    end
    log("ant discarded " ..
      "waypoint that would " ..
      "take it further from " ..
      "home", {
     id = ant.id,
     pos = ant.pos,
     dir = ant.dir,
     old_waypoint = wp,
     new_waypoint = new_wp
    })
   end
   deli(ant.waypoints)
   waypoints_left =
     count(ant.waypoints)
   wp_discarded = true
  end
 until waypoints_left == 1 or
   not wp_discarded
end

function set_ant_food_dir(ant,
  food)
 local angle = atan2(
  food.pos.x - ant.pos.x,
  food.pos.y - ant.pos.y
 )
 ant.dir = {
  x = cos(angle),
  y = sin(angle)
 }
 ant.dir_change_time = time()
end

function set_ant_explr_dir(ant,
  phrmns)
 local ant_angle
 local phrmn_angle
 if ant.dir == nil then
  local phrmn_angles =
    get_angle_to_phrmn(phrmns,
    ant)
  if count_pairs(phrmn_angles) >
    0 then
   local food_id = rnd_key(
     phrmn_angles)
   phrmn_angle =
     phrmn_angles[food_id]
   ant.phrmn_following = food_id
   if debug then
    log("ant started " ..
      "following pheromones " ..
      "while spawning", {
       id = ant.id,
       pos = ant.pos,
       dir = ant.dir,
       phrmn_id = food_id
      })
   end
  end
  if phrmn_angle != nil then
   ant_angle = phrmn_angle
  else
   ant_angle = rnd()
  end
 else
  set_ant_sense_area(ant)
  local phrmn_angles =
    get_angle_to_phrmn(phrmns,
    ant)
  if count_pairs(phrmn_angles) >
    0 then
   local food_id = rnd_key(
     phrmn_angles)
   phrmn_angle =
     phrmn_angles[food_id]
   if food_id !=
     ant.phrmn_following then
    if debug then
     log("ant started " ..
       "following pheromones", {
        id = ant.id,
        pos = ant.pos,
        dir = ant.dir,
        phrmn_id = food_id
       })
    end
    if ant.phrmn_following !=
      nil then
     if debug then
      log("ant added waypoint", {
       reason = "switched to " ..
         "different " ..
         "pheromone trail",
       id = ant.id,
       waypoint = ant.pos,
       old_phrmn_id =
         ant.phrmn_following,
       new_phrmn_id = food_id
      })
     end
     add(ant.waypoints, {
      x = ant.pos.x,
      y = ant.pos.y
     })
    end
    ant.phrmn_following =
      food_id
   end
  end
  if phrmn_angle != nil then
   ant_angle = phrmn_angle
  else
   if ant.phrmn_following != nil
     then
    if debug then
     log("ant added waypoint", {
      reason = "pheromone " ..
        "trail lost",
      id = ant.id,
      waypoint = ant.pos,
      phrmn_id =
        ant.phrmn_following
     })
    end
    ant.phrmn_following = nil
    add(ant.waypoints, {
     x = ant.pos.x,
     y = ant.pos.y
    })
   end
   ant_angle = atan2(ant.dir.x,
     ant.dir.y)
   ant_angle -=
     rnd(ant_max_angle_change *
     2) - ant_max_angle_change
  end
 end
 
 ant.dir = {
  x = cos(ant_angle),
  y = sin(ant_angle)
 }
 ant.dir_change_time = time()
end

function move_ant(ant)
 if ant_ready_to_exit(ant) then
  return
 end
 
 local dist = ant_speed *
   delta_t

 local pos = {}
 pos.x = ant.pos.x +
   ant.dir.x * dist
 pos.y = ant.pos.y +
   ant.dir.y * dist
 
 local colliding =
   is_collision(pos)
 if colliding then
  pos.x -= ant.dir.x * dist
  colliding = is_collision(pos)
  if colliding then
   pos.x += ant.dir.x * dist
   pos.y -= ant.dir.y * dist
   colliding = is_collision(pos)
   if colliding then
    pos.x -= ant.dir.x * dist
   end
  end
 end
 
 ant.pos.x = pos.x
 ant.pos.y = pos.y
end

function ant_detect_food(ant,
  foods)
 local nearest
 local nearest_dist =
   ant_food_detect_dist
 for i, food in ipairs(foods) do
  local diff = {
   x = food.pos.x - ant.pos.x,
   y = food.pos.y - ant.pos.y
  }
  local dist = sqrt(
   diff.x * diff.x +
   diff.y * diff.y
  )
  if dist < nearest_dist then
   nearest = food
   nearest_dist = dist
  end
 end
 return nearest
end

function ant_try_eating(ant)
 if ant.food_detected != nil
   then
  local food = ant.food_detected
  local diff = {
   x = food.pos.x - ant.pos.x,
   y = food.pos.y - ant.pos.y
  }
  if abs(diff.x) < 1 and
    abs(diff.y) < 1 then
   if debug then
    log("ant obtained food", {
     id = ant.id,
     pos = ant.pos,
     dir = ant.dir,
     food_id =
       ant.food_detected.id,
     food_pos =
       ant.food_detected.pos
    })
   end
   bite_food(ant.food_detected)
   ant.food_held =
     ant.food_detected.id
   ant.food_detected = nil
  end
 end
end

function ant_excrete_phrmn(ant,
  phrmns)
 if ant.food_held != nil then
  add_phrmn(phrmns, ant.pos,
    ant.food_held)
 end
end

function ant_returning(ant)
 return ant.food_held != nil or
    time() - ant.entry_time >
    ant_time_limit
end

function ant_ready_to_exit(ant)
 if ant_returning(ant) then
  local home =
    get_ant_hole_pos()
  local diff = {
   x = home.x - ant.pos.x,
   y = home.y - ant.pos.y
  }
  local is_home =
    abs(diff.x) < 1 and
    abs(diff.y) < 1
  if is_home and
    ant.home_arrival_time == nil
    then
   ant.home_arrival_time =
     time()
   ant.pos = {
    x = home.x,
    y = home.y
   }
   if debug then
    log("ant arrived home", {
     id = ant.id,
     pos = ant.pos,
     dir = ant.dir,
     home = home
    })
   end
  end
  return is_home
 end
 return false
end

function draw_ant(ant)
 local color = 0
 local draw_sense_area = false
 
 if debug then
  if ant_returning(ant) then
   if ant.food_held != nil then
    color = 9
   else
    color = 5
   end
  elseif ant.food_detected !=
    nil then
   color = 8 
  end
  
  draw_sense_area =
    ant.sense_area != nil and
    ant.food_detected == nil and
    not ant_returning(ant)
 end

 if draw_sense_area then
  for i = 2,
    ant_sense_area_vrtcs do
   line(
    ant.sense_area[i - 1].x,
    ant.sense_area[i - 1].y,
    ant.sense_area[i].x,
    ant.sense_area[i].y,
    color
   )
  end
  line(
   ant.sense_area[
     ant_sense_area_vrtcs].x,
   ant.sense_area[
     ant_sense_area_vrtcs].y,
   ant.sense_area[1].x,
   ant.sense_area[1].y,
   color
  )
 else
  pset(
  	ant.pos.x,
  	ant.pos.y,
   color
  )
 end
end
-->8
-- utils

function distance(pos1, pos2)
 local diff = {
  x = pos2.x - pos1.x,
  y = pos2.y - pos1.y
 }
 return sqrt(
  diff.x * diff.x +
  diff.y * diff.y
 )
end

function is_collision(pos)
 local clsn_sprt = mget(
  flr(pos.x / 8),
  flr((pos.y / 8) + 16)
 )
 local sprt_col = clsn_sprt % 16
 local sprt_row =
   flr(clsn_sprt / 16)
 local pos_in_sprt = {
  x = pos.x % 8,
  y = pos.y % 8
 }
 local clsn_color = sget(
   sprt_col * 8 + pos_in_sprt.x,
   sprt_row * 8 + pos_in_sprt.y
 )
 return clsn_color == 0
end

function is_collision_sprt(pos)
 local clsn_sprt = mget(
  flr(pos.x / 8),
  flr((pos.y / 8) + 16)
 )
 local sprt_col = clsn_sprt % 16
 local sprt_row =
   flr(clsn_sprt / 16)
 for i = 0, 7 do
  for j = 0, 7 do
   local clsn_color = sget(
    sprt_col * 8 + i,
    sprt_row * 8 + j
   )
   if clsn_color == 0 then
    return true
   end
  end
 end
 return false
end

function count_pairs(tbl)
 local n = 0
 for k, v in pairs(tbl) do
  n += 1
 end
 return n
end

function rnd_key(tbl)
 local len = count_pairs(tbl)
 if len == 0 then
  return nil
 end
 
 local chosen = flr(rnd(len))
 local i = 0
 for k, v in pairs(tbl) do
  if i == chosen then
   return k
  end
  i += 1
 end
end

function log(msg, data)
 local total_msg = 'msg:"' ..
   msg .. '"'
 for k, v in pairs(data) do
  if type(v) == "table" then
   local tmp_v = ''
   if v.x != nil and v.y != nil
     then
    tmp_v = 'x=' .. tostr(v.x)
      .. ',y=' .. tostr(v.y)
   end
   for vk, vv in pairs(v) do
    if vk != "x" and vk != "y"
      then
     if tmp_v != '' then
      tmp_v ..= ','
     end
     tmp_v ..= vk .. '=' ..
       tostr(vv)
    end
   end
   v = tmp_v
  end
  total_msg ..= ', ' .. k ..
    ':"' .. tostr(v) .. '"'
 end
 printh(total_msg, "log")
end
-->8
-- mouse

mouse_speed = 45
mouse_anim_time = .1
mouse_idle_sprt = 240

function init_mouse()
 mouse = {
  pos = get_mouse_start_pos(),
  dir = {
   x = 0,
   y = 1
  },
  flipped = false,
  start_pos = nil,
  end_pos = nil,
  move_prgrss = false,
  food_dropped = nil,
  anim = nil,
  anim_pos = 0
 }
end

function get_mouse_start_pos()
 return {
  x = 8 * 8,
  y = 2 * 8
 }
end

function check_mouse_eating()
 if btnp(❎) then
  local pos = {
   x = mouse.pos.x + 4,
   y = mouse.pos.y + 4
  }
  if is_valid_food_pos(pos) then
   mouse.anim = "nibble"
   mouse.anim_pos = 0
   mouse.food_dropped =
     spawn_food(pos,
     mouse.flipped)
  end
 end
end

function set_mouse_dir()
 if (mouse.end_pos != nil and
    not mouse.move_prgrss) or
    mouse.anim == "nibble" then
  return
 end

 local dir
 local anim
 if btn(⬅️) then
  dir = {
   x = -1,
   y = 0
  }
  anim = "run_horiz"
 end
 if btn(➡️) then
  dir = {
   x = 1,
   y = 0
  }
  anim = "run_horiz"
 end
 if btn(⬆️) then
  dir = {
   x = 0,
   y = -1
  }
  anim = "run_up"
 end
 if btn(⬇️) then
  dir = {
   x = 0,
   y = 1
  }
  anim = "run_down"
 end
 
 if dir == nil then
  return
 end

 local end_pos
 if mouse.end_pos != nil then
  if dir.x != mouse.dir.x or
    dir.y != mouse.dir.y then
   return
  end
  end_pos = {
   x = mouse.end_pos.x +
     dir.x * 8,
   y = mouse.end_pos.y +
     dir.y * 8
  }
 else
  end_pos = {
   x = mouse.pos.x + dir.x * 8,
   y = mouse.pos.y + dir.y * 8
  }
 end
 if is_collision_sprt(end_pos)
   then
  return
 end
 
 mouse.anim = anim
 mouse.dir = dir
 if mouse.dir.x == -1 then
  mouse.flipped = true
 elseif mouse.dir.x == 1 then
  mouse.flipped = false
 end
 if mouse.start_pos == nil then
  mouse.start_pos = {
   x = mouse.pos.x,
   y = mouse.pos.y
  }
 end
 mouse.end_pos = end_pos
 mouse.move_prgrss = false
end

function move_mouse()
 if mouse.end_pos == nil then
  return
 end
 
 local axis
 if mouse.dir.x != 0 then
  axis = "x"
 else
  axis = "y"
 end
 
 mouse.pos[axis] +=
   mouse.dir[axis] * mouse_speed
   * delta_t
 local d1 = mouse.pos[axis]
   - mouse.start_pos[axis]
 local d2 = mouse.end_pos[axis]
   - mouse.start_pos[axis]
 if abs(d1) >= abs(d2) then
  mouse.pos[axis] =
    mouse.end_pos[axis]
  mouse.start_pos = nil
  mouse.end_pos = nil
  mouse.anim = nil
  mouse.anim_pos = 0
  mouse.move_prgrss = false
 elseif abs(
    mouse.end_pos[axis] -
    mouse.pos[axis]
   ) < 4
   then
  mouse.move_prgrss = true
 end
end

function draw_mouse()
 if mouse.anim == "run_horiz"
   then
  local frame = flr(
    mouse.anim_pos /
    mouse_anim_time)
  spr(224 + frame, mouse.pos.x,
    mouse.pos.y, 1, 1,
    mouse.flipped)
  mouse.anim_pos += delta_t
  if mouse.anim_pos >= 4 *
    mouse_anim_time then
   mouse.anim_pos -= 4 *
     mouse_anim_time
  end
 elseif mouse.anim == "run_down"
   then
  local frame = flr(
    mouse.anim_pos /
    mouse_anim_time)
  spr(228 + frame, mouse.pos.x,
    mouse.pos.y, 1, 1)
  mouse.anim_pos += delta_t
  if mouse.anim_pos >= 4 *
    mouse_anim_time then
   mouse.anim_pos -= 4 *
     mouse_anim_time
  end
 elseif mouse.anim == "run_up"
   then
  local frame = flr(
    mouse.anim_pos /
    mouse_anim_time)
  spr(232 + frame, mouse.pos.x,
    mouse.pos.y, 1, 1)
  mouse.anim_pos += delta_t
  if mouse.anim_pos >= 4 *
    mouse_anim_time then
   mouse.anim_pos -= 4 *
     mouse_anim_time
  end
 elseif mouse.anim == "nibble"
   then
  local frame = flr(
    mouse.anim_pos /
    mouse_anim_time)
  local offset
  if frame <= 3 then
   offset = 1 + flr(frame / 2)
  elseif frame <= 15 then
   local loop_frame =
     (frame - 4) % 3
   if loop_frame == 1 then
    offset = 3
   else
    offset = 2
   end
  else
   offset = 2
  end
  spr(mouse_idle_sprt + offset,
    mouse.pos.x, mouse.pos.y, 1,
    1, mouse.flipped)
  if frame == 6 then
   mouse.food_dropped
     .anim_frame = 1
  elseif frame == 9 then
   mouse.food_dropped
     .anim_frame = 2
  elseif frame == 12 then
   mouse.food_dropped
     .anim_frame = 3
  elseif frame == 15 then
   mouse.food_dropped
     .anim_frame = 4
  end
  mouse.anim_pos += delta_t
  if mouse.anim_pos >= 18 *
    mouse_anim_time then
   mouse.anim = nil
   mouse.anim_pos = 0
   mouse.food_dropped = nil
  end
 else
  spr(mouse_idle_sprt,
    mouse.pos.x,
    mouse.pos.y, 1, 1,
    mouse.flipped)
 end
end
-->8
-- food

food_current_id = 0
food_bite_size = .05

function get_food_pos_options()
 local pos_options = {}
 for x = 0, 15 do
  for y = 0, 15 do
   local sprite =
     mget(x, y + 16)
   local sprt_col = sprite % 16
   local sprt_row =
     flr(sprite / 16)
   local sprt_clr = sget(
    sprt_col * 8,
    sprt_row * 8
   )
   if sprt_clr == 7 then
    local spot_taken = false
    for food in all(foods) do
     if food.pos.x == x * 8 + 4
       and food.pos.y ==
       y * 8 + 4 then
      spot_taken = true
     end
    end
    if not spot_taken then
     add(pos_options, {
      x = x * 8 + 4,
      y = y * 8 + 4
     })
    end
   end
  end
 end
 return pos_options
end

function is_valid_food_pos(pos)
 for option in
   all(get_food_pos_options())
   do
  if pos.x == option.x and
    pos.y == option.y then
   return true
  end
 end
 return false
end

function spawn_food(pos,
  flipped)
 if not is_valid_food_pos(pos)
   then
  if debug then
   log("tried to spawn food " ..
     "at invalid position", {
      pos = pos
     })
  end
  return
 end

 local food = {
  id = get_food_id(),
  pos = pos,
  amount = 1,
  anim_frame = 0,
  flipped = flipped
 }
 add(foods, food)
 if debug then
  log("food spawned", {
   id = food.id,
   pos = food.pos,
   amount = food.amount
  })
 end
 return food
end

function get_food_id()
 if food_current_id == 32767
   then
  food_current_id = 1
 else
  food_current_id += 1
 end
 return food_current_id
end

function bite_food(food)
 local new_amount = food.amount
   - food_bite_size
 if new_amount < 0 then
  new_amount = 0
 end
 if debug then
  log("food bitten", {
   id = food.id,
   pos = food.pos,
   old_amount = food.amount,
   new_amount = new_amount
  })
 end
 food.amount = new_amount
end

function draw_food(food)
 local frame = ceil(
   food.anim_frame *
   food.amount)
 spr(244 + frame,
   food.pos.x - 4,
   food.pos.y - 4, 1, 1,
   food.flipped)
end
-->8
-- pheromones

phrmn_add_rate = .15
phrmn_evap_rate = .003

function add_phrmn(phrmns, pos,
   food_id)
 local col = phrmns[flr(pos.x)]
 if col == nil then
  col = {}
  phrmns[flr(pos.x)] = col
 end
 
 local cell = col[flr(pos.y)]
 if cell == nil then
  cell = {}
  col[flr(pos.y)] = cell
 end

 local phrmn = cell[food_id]
 if phrmn == nil then
  phrmn = 0
 end
 
 phrmn += phrmn_add_rate *
   delta_t
 phrmn = min(phrmn, 1)
 cell[food_id] = phrmn
end

function phrmns_evap(phrms)
 for x, col in pairs(phrmns) do
  for y, cell in pairs(col) do
   for food_id, phrmn in
     pairs(cell) do
    phrmn -= phrmn_evap_rate *
      delta_t
    cell[food_id] = phrmn
    if phrmn <= 0 then
     cell[food_id] = nil
     if count_pairs(cell) == 0
       then
      col[y] = nil
      if count_pairs(col) == 0
        then
       phrmns[x] = nil
      end
     end
    end
   end
  end
 end
end

function get_angle_to_phrmn(
  phrmns, ant)
 local bounds
 local look_angle
 if ant.dir != nil then
  bounds =
    get_phrmn_dtct_bnds(ant)
  look_angle =
    atan2(ant.dir.x, ant.dir.y)
 else
  bounds =
    get_spawn_phrmn_dtct_bnds(
    ant)
 end

 local phrmn_dirs = {}
 for i=bounds.x1, bounds.x2 do
  for j=bounds.y1, bounds.y2 do
   local phrmn_col = phrmns[i]
   local phrmn_cell
   if phrmn_col != nil then
    phrmn_cell = phrmn_col[j]
   end
   if phrmn_cell != nil then
    for food_id, phrmn in
      pairs(phrmn_cell) do
     local dir = {
      x = i + .5 - ant.pos.x,
      y = j + .5 - ant.pos.y
     }
     local angle = atan2(
       dir.x, dir.y)
     local dist = sqrt(
      dir.x * dir.x +
      dir.y * dir.y
     )

     local in_sense_area
     if look_angle != nil then
      in_sense_area = dist <
        ant_phrmn_detect_dist and
        angle > (look_angle -
        ant_phrmn_detect_angle)
        and angle < (look_angle +
        ant_phrmn_detect_angle)
     else
      in_sense_area = dist <
        ant_phrmn_detect_dist
     end

     if in_sense_area then
      local phrmn_dir =
        phrmn_dirs[food_id]
      if phrmn_dir == nil then
       phrmn_dir = {
        x = 0,
        y = 0
       }
       phrmn_dirs[food_id] =
         phrmn_dir
      end

      local infl = {
       x = dir.x * phrmn,
       y = dir.y * phrmn
      }
      phrmn_dir.x += infl.x
      phrmn_dir.y += infl.y
     end
    end
   end
  end
 end

 local phrmn_angles = {}
 for food_id, phrmn_dir in
   pairs(phrmn_dirs) do
  phrmn_angles[food_id] = atan2(
   phrmn_dir.x,
   phrmn_dir.y
  )
 end
 return phrmn_angles
end

function get_phrmn_dtct_bnds(
  ant)
 local bounds = {
  x1 = flr(ant.sense_area[1].x),
  x2 = flr(ant.sense_area[1].x),
  y1 = flr(ant.sense_area[1].y),
  y2 = flr(ant.sense_area[1].y)
 }
 for i = 2, ant_sense_area_vrtcs
   do
  bounds.x1 = min(
   bounds.x1,
   flr(ant.sense_area[i].x)
  )
  bounds.x2 = max(
   bounds.x2,
   flr(ant.sense_area[i].x)
  )
  bounds.y1 = min(
   bounds.y1,
   flr(ant.sense_area[i].y)
  )
  bounds.y2 = max(
   bounds.y2,
   flr(ant.sense_area[i].y)
  )
 end
 return bounds
end

function
  get_spawn_phrmn_dtct_bnds(ant)
 local diag_side = sqrt(2) *
  ant_phrmn_detect_dist
  
 local sense_area = {}
 sense_area[1] = {
  x = ant.pos.x +
    ant_phrmn_detect_dist,
  y = ant.pos.y
 }
 sense_area[2] = {
  x = ant.pos.x + diag_side,
  y = ant.pos.y + diag_side
 }
 sense_area[3] = {
  x = ant.pos.x,
  y = ant.pos.y +
    ant_phrmn_detect_dist
 }
 sense_area[4] = {
  x = ant.pos.x - diag_side,
  y = ant.pos.y + diag_side
 }
 sense_area[5] = {
  x = ant.pos.x -
    ant_phrmn_detect_dist,
  y = ant.pos.y
 }
 sense_area[6] = {
  x = ant.pos.x - diag_side,
  y = ant.pos.y - diag_side
 }
 sense_area[7] = {
  x = ant.pos.x,
  y = ant.pos.y -
    ant_phrmn_detect_dist
 }
 sense_area[8] = {
  x = ant.pos.x + diag_side,
  y = ant.pos.y - diag_side
 }

 local bounds = {
  x1 = flr(sense_area[1].x),
  x2 = flr(sense_area[1].x),
  y1 = flr(sense_area[1].y),
  y2 = flr(sense_area[1].y)
 }
 for i = 2, 8 do
  bounds.x1 = min(
   bounds.x1,
   flr(sense_area[i].x)
  )
  bounds.x2 = max(
   bounds.x2,
   flr(sense_area[i].x)
  )
  bounds.y1 = min(
   bounds.y1,
   flr(sense_area[i].y)
  )
  bounds.y2 = max(
   bounds.y2,
   flr(sense_area[i].y)
  )
 end
 return bounds
end

function draw_phrmns(phrmns)
 for x, col in pairs(phrmns) do
  for y, cell in pairs(col) do
   for food_id, phrmn in
     pairs(cell) do
    if phrmn > 0 and
      phrmn <= .33 then
     pset(x, y, 4)
    elseif phrmn > .33 and
      phrmn <= .66 then
     pset(x, y, 8)
    elseif phrmn > .66 then
     pset(x, y, 10)
    end
   end
  end
 end
end

function log_phrmns(phrmns)
 printh("pheromones: {", "log")
 for x, col in pairs(phrmns) do
  printh(" x = " .. x .. ": {",
    "log")
  for y, cell in pairs(col) do
   printh("  y = " .. y ..
     ": {", "log")
   for food_id, phrmn in
     pairs(cell) do
    printh("   food_id = " ..
      food_id .. ": " .. phrmn,
      "log")
   end
   printh("  }", "log")
  end
  printh(" }", "log")
 end
 printh("}", "log")
end
-->8
-- tv

tv_px_colors = {0, 5, 6}

function init_tv()
 tv.pixels = {}
 add(tv.pixels, {
  x = 20,
  y = 19
 })
 add(tv.pixels, {
  x = 19,
  y = 20
 })
 add(tv.pixels, {
  x = 20,
  y = 20
 })
 add(tv.pixels, {
  x = 18,
  y = 21,
  alt_color = 8
 })
 add(tv.pixels, {
  x = 19,
  y = 21
 })
 add(tv.pixels, {
  x = 20,
  y = 21
 })
 add(tv.pixels, {
  x = 17,
  y = 22
 })
 add(tv.pixels, {
  x = 18,
  y = 22,
  alt_color = 7
 })
 add(tv.pixels, {
  x = 19,
  y = 22,
  alt_color = 14
 })
 add(tv.pixels, {
  x = 16,
  y = 23
 })
 add(tv.pixels, {
  x = 17,
  y = 23,
  alt_color = 10
 })
 add(tv.pixels, {
  x = 18,
  y = 23,
  alt_color = 7
 })
 add(tv.pixels, {
  x = 19,
  y = 23
 })
 add(tv.pixels, {
  x = 16,
  y = 24
 })
 add(tv.pixels, {
  x = 17,
  y = 24
 })
 add(tv.pixels, {
  x = 18,
  y = 24,
  alt_color = 12
 })
 add(tv.pixels, {
  x = 16,
  y = 25
 })
 add(tv.pixels, {
  x = 17,
  y = 25
 })
 add(tv.pixels, {
  x = 16,
  y = 26
 })
 
 for px in all(tv.pixels) do
  if px.alt_color == nil then
   px.alt_color = 5
  end
  px.color = get_tv_px_color(px)
  px.elapsed_time = 0
  px.time_limit =
    get_tv_px_time_limit()
 end
end

function update_tv()
 for px in all(tv.pixels) do
  px.elapsed_time += delta_t
  if px.elapsed_time >=
    px.time_limit then
   px.elapsed_time = 0
   px.time_limit =
     get_tv_px_time_limit()
   px.color =
     get_tv_px_color(px)
  end
 end
end

function get_tv_px_color(px)
 local total =
   count(tv_px_colors)
 if px.alt_color != nil then
  total += 5
 end
 
 local i = flr(rnd(total)) + 1
 if i <= count(tv_px_colors)
   then
  return tv_px_colors[i]
 else
  return px.alt_color
 end
end

function get_tv_px_time_limit()
 return .05 + .05 * rnd()
end

function draw_tv()
 for px in all(tv.pixels) do
  pset(px.x, px.y, px.color)
 end
end
-->8
-- faucet

faucet_drip_interval = 4
faucet_drip_max_hangtime = 1
faucet_drip_accel = 300
faucet_start_pos = {
 x = 120,
 y = 48
}
faucet_end_pos = {
 x = 120,
 y = 50
}

function init_faucet()
 faucet = {
  last_drip_time = 0,
  drip = nil
 }
end

function update_faucet()
 if faucet.drip != nil then
  if time() -
    faucet.last_drip_time <
    faucet_drip_max_hangtime
    then
   return
  end
  faucet.drip.speed +=
    faucet_drip_accel * delta_t
  faucet.drip.pos.y +=
    faucet.drip.speed * delta_t
  if flr(faucet.drip.pos.y) >
    faucet_end_pos.y then
   faucet.drip = nil
  end
 elseif faucet.last_drip_time
   == nil or time() -
   faucet.last_drip_time >=
   faucet_drip_interval then
  faucet.drip = {
   pos = {
    x = faucet_start_pos.x,
    y = faucet_start_pos.y
   },
   hangtime = 0,
   speed = 0
  }
  faucet.last_drip_time = time()
 end
end

function draw_faucet_drip()
 if faucet.drip != nil and
  flr(faucet.drip.pos.y) <=
  faucet_end_pos.y then
  pset(faucet.drip.pos.x,
    faucet.drip.pos.y, 12)
 end
end
__gfx__
ffffffff5555555555555555555555555555555555555555ffffffffffffffff67776777ffff6777ffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff5577777777777755777777777777777777777777ffffffffffffffff67776777ffff6777fffffffffffffffffffffffff66fffffffffffffffffffff
ff7ff7ff5577777777777755777777777010101010101077ffffff5fffffffff67776777ffff6777fffffffffffffffffffffff66fffffffffffffffffffffff
fff77fff575777777777757577777777111011d4d1101117fff5ff5fffffffff66666666ffff6666ffffffffffffffffffffff6fffffffffffffffffffffffff
fff77fff57577777777775757777777711011d646d110117fff5f5ffffffffff67776777ffff6777fffffffffffffffffffff6ffffffffffffffffffffffffff
ff7ff7ff577577777777577577777777011dd67467dd1107fff5f501ffffffff67776777ffff6777fffffffffffffffffffff6ffffffffffffffffffffffffff
ffffffff5775777777775775777777770116676476761107fff5151010ffffff67776777ffff6777fffffffffffffffffffff6ffffffffffff00000000000fff
ffffffff5775777777775775777777770104444444440107fff15101010fffff66666666ffff6666ffffffffffffffff6fff6fffffffffffff05555555550fff
ffffffff5777577777757775777777770104767467640107ff10501010101ffffffffffffffffffffffffffffffffff6f666fffffffffffff005555555550fff
ffff99ff5777577777757775777777770104666466640107f1010101010104fffffffffffffffffffffffffffffffff6fffffffffffffffff005555555550fff
fff99aaf577757777775777577777777010466646664010710101010101044fffffffffffffffffffffffffffffffff6fff66ffffffffffff005555555550fff
ff99aa9f577775777757777577777777017744444447010701010101010454fffffffffffffffffffffffffffffffff6ff6ffffffffffffff005555555550fff
f9aa9aaf577775777757777577777777777777777777777700101010104554ffffffffffff1111ffffffffffffffff6ff6ffffffffffffff0505555555550fff
fa9aaa9f577777577577777577777777777777777777777700010101048554fffffffffff12222111fffffffffff66fff6ffffffffffffff0505555555550fff
ffffffff577777577577777577777777777777777777777700000010457e4ffffffffffff11222222111fffffff6fffff6ffffffffffffff0505555555550fff
ffffffff5777777447777775444444444444444444444444000000045a754ffffffffffff11111222222111ffff6ffff6fffffffffffffff0500000000000fff
f5f6ffff5777777447777775ffffffff57777774ffffffff5000000455c4fffffffffffff111111112221221ffff6666ffffffffffffffff0505555555550fff
556e6ffe5777777447777775ffffffff57222774ffffffff5ff00004554ffffffff5dffff111111111112221ffffffffffffffffffffffff0505555555550fff
f66fffef5777777447777775ffffffff57288224fffffffff5ff000454fffffffffdffffff11121111112211ffffffffffffffffffffffff050555555550ffff
e66fffef577777744777777544444444572888820000000ff5ffff044fffffffffffffffff12212121112211ffffffffffffffffffffffff005555555550ffff
f566fffe57777774477777757777777757288a820505050fff55f846ffffffffffffffffff12221212122111ffffffffffffffffffffffff005555555000ffff
56666ffe577777744777777577777777572888820050500fffff516d6ffffffffffffffff111122121122111ffffffffffffffffffffffff000000000050ffff
e5666eef577777744777777577777777572822820505050fffff66d65ffffffffffffffff122211211222111ffffffffffffffffffffffff000555555050ffff
556fffff577777744777777555555555572822820050500fffff5665ffffffffffffffff122222211122111fffffffffffffffffffffffff050500500050ffff
ffffffff5777777447777775ffffffff572822820505050ffffff55fffffffffffffffff122222212122111fffffffffffffffffffffffff000500500050ffff
ffffffff5777777447777775ffffffff572822820050500fffffffffffffff6fffffffff11122212122111ffffffffffffffffffffffffff000555555050ffff
ffffffff5777777447777775ffffffff572822820505050ffffffffffffff5dffffffff122111221122111ffffffffffffffffffffffffff000500500000ffff
ffffffff5777777447777775ffffffff572828820050500ffffffffffffff5fffffffff122222111222111ffffffffffffffffffffffffff000500500050ffff
ffffffff5777755775577775ffffffff572888820505050fffffffffffffffffffff11112222212122111fffffffffffffffffffffffffff000555555050ffff
ffffffff5775577777755775ffffffff572888220000000fffffffffffffffffffff12221122121122111fffffffffffffffffffffffffff050000000000ffff
ffffffff5557777777777555ffffffff57282274fffffffffffffffffffffffffff12222221111122111ffffffffffffffffffffffffffff00ddddddddddffff
ffffffff5555555555555555ffffffff57227774fffffffffffffffffffffffffff11112222221122111ffffffffffffffffffffffffffff05ddddddddddffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff11211122221222111ffffffffffffffffffffffffffff54ddddddddddffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1212121112222111fffffffffffffffffffffffffffff54ddddddddddffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1111212121122111fffffffffffffffffffffffffffff44ddddddddddffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111121211111ffffffffffffffffffffffffffffff44ddddddddddffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff112121111ffffffffffffffffffffffffffffff45ddddddddddffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111211fffffffffffffffffffffffffffffff54ddddddddddffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111fffffffffffffffffffffffffffffff54ddddddddddffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44ddddddddddffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d77777777dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff45d76666667dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54d76666667dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54d76666667dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d76666667dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d77777755dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff45d77777575dffff
ffffffffffffffffffff111111fffffffff111111fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54d76666567dffff
ffffffffffffffffffff111111fffffffff111111fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54d76666667dffff
ffffffffffff4444444444444444444444444444444444444fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d76666667dffff
fffffffffff54455555555555555555555555555555555544fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d76666667dffff
fffffffffff54544444444444444444444444444444444454fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d77777777dffff
fffffffffff54544444444444444444444444444444444454ffffffffffffffffffffffffffffffffffffdddddddddddddddddddddddddddddddddddddddffff
fffffffffff54544444444444444344744444444444444454fffffffffffffffffffffffffffffffffff5dddddddddddddddddddddddddddddddddddddddffff
fffffffffff54544444444444444437974444444444444454fffffffffffffffffffffffffffffffffff5dddddddddddddddddddddddddddddddddddddddffff
fffffffffff5454444444444444473b744444444444444454fffffffffffffffffffffffffffffffffff4dddddddddddddddddddddddddddddddddddddddffff
fffffffffff5454444444444444797b374444444444444454fffffffffffffffffffffffffffffffffff4dddddddddddddddddddddddddddddddddddddddffff
ffffffff11f54544444444444444733797444444444444454f11ffffffffffffffffffffffffffffffff4dddddddddddddddddddddddddddddddddddddddffff
ffffffff111545444444444444443b3b74444444444444454111ffffffffffffffffffffffffffffffff4dddddddddddddddddddddddddddddddddddddddffff
ffffffff11d54544444444444444447344444444444444454d11ffffffffffffffffffffffffffffffff4dddddddddddddddddddddddddddddddddddddddffff
ffffffff11d54544444444444444477644444444444444454d11ffffffffffffffffffffffffffffffff4dddddddddddddddddddddddddddddddddddddddffff
ffffffff11d54544444444444444444444444444444444454d11ffffffffffffffffffffffffffffffff454444444444444444444444444444444444445fffff
ffffffff11d54544444444444444444444444444444444454d11ffffffffffffffffffffffffffffffff54444444444444444444444444444444444445ffffff
fffffffff115454444444444444444444444444444444445411fffffffffffffffffffffffffffffffff5444444444444444444444444444444444445fffffff
fffffffff1f54544444444444444444444444444444444454f1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffff54544444444444444444444444444444444454fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffff54544444444444444444444444444444444454fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffff54544444444444444444444444444444444454fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffff54455555511111155555555555551155555544fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffff54444444414444144444444411114144444444fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffff555555551111115555555551555115555555ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff00ff1dddd1fffffff1d1111d1ff00fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffff00ff111111fffffff1f1ddd11ff00fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffff1ffff1fffffffff1111f1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffff1ffff1fffffffff1ffff1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffff1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff00000000fffffffffffff00fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff0000000000000000ffff00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff0000000000000000fff0000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff0000000000000000ff000000000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff0000000000000000f00000000000ffffffffffffffff000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff00000000000000000000000000000fffffffffffffff000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffff00000000000ffffffffffffffff0000fffffffff0ffffffffffffffffffffffffffffffffffffffff0fffffffffffffffffffff
fffffffffffffffffffffffffff00000000ffffffff00fffffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffff000000fffffffff0ffffffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffff000fffffffffffffffffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffff00ffffffffffffffffffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffff0000fffffffffffffffffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffff00000fffffffffffffffffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffff0000ffffffffffffffffffff0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffff00fffffffffffffffffffffffffffffffffffffffff00fffffffffffffff0fffffffff00fffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffff0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffff00fffffffffffffffffffffffffffffffffffff0ffff0ffffffffffffff0fffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffff0fffffffffffffffffffffffffffffffffffffffffffffffffffff0ffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffefffffffffffffffffffffffeffffffffffffff5f5fffff5f5fffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffefffffffeffffffffffffefffffffeffffff5e5ffffffeffffff5f5fffff555fffff555fffff555fffffffffffffffffffffffffffffffffff
efffffefffff5550ffe55550fee555effffefffffffeffffff555fffff555fffff555fffff555fffff555fffff555fffffffffffffffffffffffffffffffffff
fee55550ffe5555ffef5555feff55550ff555fffff555fffff555fffff555fffff555fffff555fffff555fffff555fffffffffffffffffffffffffffffffffff
fff555ffeef5ffffef5fffffffffff5fff555fffffe5efffffe5efffff555fffff555fffff555fffff5e5fffff5e5fffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffe5efffff505fffff505fffffe5efffff5e5fffff5e5fffff5e5fffff5e5fffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffff505fffffffffffffffffffff505ffffffefffffffeffffff5e5ffffffeffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5f5ffffffffffffffefffffffeffffffffffffffffffffffffffffffffffffffffffff
fffefefffffefefffffefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffff50ffffff50ffffff0ffffffefeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fff55ffffff559fffff59ffffff59fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
eff55fffeff55fffeff55fffeff55fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fee55ffffee55ffffee55ffffee55fffffffffffffffffffffffffffffffffffffff9fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffff9ffffff99ffffff999fffff999ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
__label__
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555
55777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777755
55777777777777777777777770101010101010777777777777777777777777777777777777777777777777777010101010101077777777777777777777777755
575777777777777777777777111011d4d1101117777777777777777777777777777777777777777777777777111011d4d1101117777777777777777777777575
57577777777777777777777711011d646d11011777777777777777777777777777777777777777777777777711011d646d110117777777777777777777777575
577577777777777777777777011dd67467dd1107777777777777777777777777777777777777777777777777011dd67467dd1107777777777777777777775775
57757777777777777777777701166764767611077777777777777777777777777777777777777777777777770116676476761107777777777700000000000775
57757777777777777777777701044444444401077777777777777777777777777777777777777777777777770104444444440107777777777705555555550775
57775777777777777777777701047674676401077777777777777777777777777777777777777777777777770104767467640107777777777005555555550775
57775777777777777777777701046664666401077777777777777777777777777777777777777777777777770104666466640107777777777005555555550775
57775777777777577777777701046664666401077777777777777777777777777777777777777777777777770104666466640107777777777005555555550775
57777577777577577777777701774444444701077777777777777777777777777777777777777777777777770177444444470107777777777005555555550775
57777577777575777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770505555555550775
57777757777575017777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770505555555550775
57777757777515101077777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777770505555555550775
57777774444151010104444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444440500000000000775
57777774ff10501010101fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff67776777677767776777677767770505555555550775
57777774f1010101010104ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff67776777677767776777677767770505555555550775
5777777410101010101044ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff67776777677767776777677767770505555555507775
5777777401010101010454ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff66666666666666666666666666660055555555507775
5777777400101010104554ffffffffffff1111ffffffffffffffffffffffffffffffffffffffffffffff67776777677767776777677767770055555550007775
5777777400010101048554fffffffffff12222111fffffffffffffffffffffffffffffffffffffffffff67776777677767776777677767770000000000507775
5777777400000010457e4ffffffffffff11222222111ffffffffffffffffffffffffffffffffffffffff67776777677767776777677767770005555550507775
57777774000000045a754ffffffffffff11111222222111fffffffffffffffffffffffffffffffffffff66666666666666666666666666660505005000507775
577777745000000455c4fffffffffffff111111112221221ffffffffffffffffffffffffffffffffffff67776777677767776777677767770005005000507775
577777745ff00004554ffffff665dffff111111111112221ffffffffffffffffffffffffffffffffffff67776777677767776777677767770005555550507775
57777774f5ff000454fffff66ffdffffff11121111112211ffffffffffffffffffffffffffffffffffff67776777677767776777677767770005005000007775
57777774f5ffff044fffff6fffffffffff12212121112211ffffffffffffffffffffffffffffffffffff66666666666666666666666666660005005000507775
57777774ff55f846fffff6ffffffffffff12221212122111ffffffffffffffffffffffffffffffffffff67776777677767776777677767770005555550507775
57777774ffff516d6ffff6fffffffffff111122121122111ffffffffffffffffffffffffffffffffffff67776777677767776777677767770500000000007775
57777774ffff66d65ffff6fffffffffff122211211222111ffffffffffffffffffffffffffffffffffff677767776777677767776777677700dddddddddd7775
57777774ffff56656fff6fffffffffff122222211122111fffffffffffffffffffffffffffffffffffff666666666666666666666666666605dddddddddd7775
57777774fffff556f666ffffffffffff122222212122111fffffffffffffffffffffffffffffffffffff677767776777677767776777677754dddddddddd7775
57777774fffffff6ffffff6fffffffff11122212122111ffffffffffffffffffffffffffffffffffffff677767776777677767776777677754dddddddddd7775
57777774fffffff6fff665dffffffff122111221122111ffffffffffffffffffffffffffffffffffffff677767776777677767776777677744dddddddddd7775
57777774fffffff6ff6ff5fffffffff122222111222111ffffffffffffffffffffffffffffffffffffff666666666666666666666666666644dddddddddd7775
57777774ffffff6ff6ffffffffff11112222212122111fffffffffffffffffffffffffffffffffffffff677767776777677767776777677745dddddddddd7775
57777774ffff66fff6ffffffffff12221122121122111fffffffffffffffffffffffffffffffffffffff677767776777677767776777677754dddddddddd7775
57777774fff6fffff6fffffffff12222221111122111ffffffffffffffffffffffffffffffffffffffff677767776777677767776777677754dddddddddd7775
57777774fff6ffff6ffffffffff11112222221122111ffffffffffffffffffffffffffffffffffffffff666666666666666666666666666644dddddddddd7775
57777774ffff6666fffffffffff11211122221222111ffffffffffffffffffffffffffffffffffffffff677767776777677767776777677744d77777777d7775
57777774fffffffffffffffffff1212121112222111fffffffffffffffffffffffffffffffffffffffff677767776777677767776777677745d76666657d7775
57777774fffffffffffffffffff1111212121122111fffffffffffffffffffffffffffffffffffffffff677767776777677767776777677754d76666665d7775
57777774ffffffffffffffffffffff111121211111ffffffffffffffffffffffffffffffffffffffffff666666666666666666666666666654d76611161d7775
57777774fffffffffffffffffffffffff112121111ffffffffffffffffffffffffffffffffffffffffff677767776777677767776777677744d76655611d7775
57777774fffffffffffffffffffffffffff111211fffffffffffffffffffffffffffffffffffffffffff677767776777677767776777677744d77777711d7775
57777774ffffffffffffffffffffffffffffff111fffffffffffffffffffffffffffffffffffffffffff677767776777677767776777677745d77777777d7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff666666666666666666666666666654d76666667d7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff677767776777677767776777677754d76666667d7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff677767776777677767776777677744d76666667d7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff677767776777677767776777677744d76666667d7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff666666666666666666666666666644d77777777d7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6ddddddddddddddddddddddddddddddddddddddd7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5ddddddddddddddddddddddddddddddddddddddd7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5ddddddddddddddddddddddddddddddddddddddd7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff45444444444444444444444444444444444444577775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54444444444444444444444444444444444445777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54444444444444444444444444444444444457777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0ffffffffffffffffffffffffffff0f47777775
57777774fffffffffffffffffffffffffff5fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff047777775
57777774ffffffffffffffffffffffffff545fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774fffffffffffffffffffffffffe55ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffd55ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0ffffffffffff47777775
57777774ffffffffffffffffffffffffffd55ffeffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffdd5eefffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0f47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff047777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0fff47777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0ffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0ffffffffffffffff047777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffff0fffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111111fffffffff111111fffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111111fffffffff111111fffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff4444444444444444444444444444444444444fffffff47777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54455555555555555555555555555555555544fffffff47777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54544444444444444444444444444444444454fffffff47777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54544444444444444444444444444444444454fffffff47777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54544444444444444344744444444444444454fffffff47777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54544444444444444437974444444444444454fffffff47777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5454444444444444473b744444444444444454fffffff47777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff5454444444444444797b374444444444444454fffffff47777775
57222774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff11f54544444444444444733797444444444444454f11ffff47777775
57288224ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111545444444444444443b3b74444444444444454111ffff47777775
572888820000000fffffffffffffffffffffffffffffffffffffffffffffffffffffffff11d54544444444444444447344444444444444454d11ffff47777775
57288a820505050fffffffffffffffffffffffffffffffffffffffffffffffffffffffff11d54544444444444444477644444444444444454d11ffff47777775
572888820050500fffffffffffffffffffffffffffffffffffffffffffffffffffffffff11d54544444444444444444444444444444444454d11ffff47777775
572822820505050fffffffffffffffffffffffffffffffffffffffffffffffffffffffff11d54544444444444444444444444444444444454d11ffff47777775
572822820050500ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff115454444444444444444444444444444444445411fffff47777775
572822820505050ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1f54544444444444444444444444444444444454f1fffff47777775
572822820050500ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54544444444444444444444444444444444454fffffff47777775
572822820505050ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54544444444444444444444444444444444454fffffff47777775
572828820050500ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54544444444444444444444444444444444454fffffff47777775
572888820505050ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54455555511111155555555555551155555544fffffff47777775
572888220000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54444444414444144444444411114144444444fffffff47777775
57282274ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff555555551111115555555551555115555555ffffffff47777775
57227774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff1dddd1fffffff1d1111d1ff00fffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff00ff111111fffffff1f1ddd11ff00fffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1ffff1fffffffff1111f1fffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1ffff1fffffffff1ffff1fffffffffffffff47777775
57777774fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1ffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff47777775
57777774444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444447777775
57777557777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777775577775
57755777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777755775
55577777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555

__gff__
0000000000000000000001000000010000000000000000000000010000010100000000000000000000000000010000000000000000000000000002010102020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0103030405030303030303040503030201030304050303030303030405030e0fff01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
1113131415131313131313141513131211060714151313131313131415131e1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffff18ffffffffffff09080808082221161718191affffffffffffffff2e2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ff0c0dffffffffffff09080808082221262728292affffffffffffffff3e3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
211b1cffffffffffffff09080808082221363738393affffffffffffffff4e4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
212bffffffffffffffff0908080808222146ff48494affffffffffffffff5e5fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffffffffffffffffff09080808082221ffffffffffffffffff6a6b6c6d6e6fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffffffffffffffffff09080808082221ffffffffffffffffff7a7b7c7d7e7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffffffffffffffffffffffffffff2221ffffffffffffffffffffffffffff22ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffffffffffffffffffffffffffff2221ffffffffffffffffffffffffffff22ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffffffffffffffff51ffffffff562221ffffffffffffffff51525354555622ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffffffffffffffffffffffffffff2221ffffffffffffffff61626364656622ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
2425ffffffffffffffffffffffffff2224ffffffffffffffff71727374757622ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
3435ffffffffffffffffffffffffff2234ffffffffffffffff81828384858622ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffffffffffffffffffffffffffff2221ffffffffffffffff91929394959622ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
3123232323232323232323232323233231232323232323232323232323232332ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1a3a4d0ffd0d0d0d0d0d0d0d0d0a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1b3b4b5ffffd0d0d0d0d0d0d0d0a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1c3c4ffffffd0d0d0d0d0d0d0d0a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1d0d0ffffd0d0d0d0d0d0d0d0d0a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1d0d0d0d0d0d0d0d0d0a6a7a7a7a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1d0d0d0d0d0d0d0d0d0b6a1a1a1a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1d0d0d0d0d0d0d0d0d0d0d0d0d0d0a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1d0d0d0d0d0d0d0d0d0d0d0d0d0d0a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1d0d0d0d0d0d0d0d0d0d0d0d0d0d0a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1d0d0d0d0d0d0d0d0ffffffffffd0a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1d0d0d0d0d0d0d0d0ffffffffffffa1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1d0d0d0d0d0d0d0d0b8b9babbbcbda1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1d0d0d0d0d0d0d0d0d0c9cacbcc96a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1a2a2a2a2a2a2a2a2a2a2a2a2a2a2a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
