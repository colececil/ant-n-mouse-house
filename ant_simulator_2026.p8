pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- ant & mouse house
-- by cole cecil

debug = false
debug_cmd_prgrss = 0
debug_was_on = false
debug_msg_on = false
debug_msg_time_left = 0
is_menu = true
last_frame_time = 0
delta_t = 0

selected_mode = "active"
menu_cursor = {}
menu_cursor_visible_time = .4
menu_cursor_cycle_time = .8

mouse = nil
ants = {}
ant_reactns = {}
foods = {}
phrmns = {}
tv = {}
faucet = {}
last_ant_entry = nil
ant_entry_interval = 7
ant_entry_variation = 2
ant_gather_rate = 0
ant_gather_rate_inc = .08
ant_gather_rate_dec = .008
ant_last_gather_rate = time()
ant_max_gather_rate_wait = 90
collision_tiles = {}
blacklight = false
max_insffcnt_food_time = 5
insffcnt_food_time = time()

function _init()
 init_menu()
end

function init_menu()
 poke(0x5f36, 64)
 menu_cursor.active = true
 menu_cursor.elapsed_time = 0
end

function init_game()
 init_collision_tiles()
 init_ant_hole_pos()
 init_mouse()
 init_tv()
 init_faucet()
end

function _update60()
 delta_t = time() -
   last_frame_time
 last_frame_time = time()

 check_debug_cmd()
 
 if debug_cmd_prgrss == 4 then
  debug_cmd_prgrss = 0
  debug = not debug
  debug_msg_on = true
  debug_msg_time_left = 1
  if debug then
   printh("", "log",
     not debug_was_on)
   debug_was_on = true
  end
 end
 
 if debug_msg_time_left > 0 then
  debug_msg_time_left -= delta_t
  if debug_msg_time_left <= 0
    then
   debug_msg_time_left = 0
   debug_msg_on = false
  end
 end
 
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
 if debug_msg_on then
  local state = "off"
  if debug then
   state = "on"
  end
  local msg = "debug mode " ..
    state
  local x = (128 - #msg * 4) / 2
  local clr = 8
  if is_menu then
   clr = 7
  end
  print(msg, x, 112, clr)
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
   if selected_mode == "active"
     then
    sfx(10)
   else
    selected_mode = "active"
    menu_cursor.elapsed_time = 0
    sfx(7)
   end
  end
  if btnp(⬇️) then
   if selected_mode == "passive"
     then
    sfx(10)
   else
    selected_mode = "passive"
    menu_cursor.elapsed_time = 0
    sfx(7)
   end
  end
 
  if btnp(❎) then
   log("mode selected", {
    selected_mode =
      selected_mode,
   })
   menu_cursor.active = false
   menu_cursor.elapsed_time = 0
   menu_cursor.submit_time = 0
   sfx(2)
   
   init_game()
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
  blacklight = not blacklight
  if blacklight then
   sfx(3)
  else
   sfx(4)
  end
 end

 for i, food in ipairs(foods) do
  if food.amount <= 0 then
   log("food completely eaten",
     {
      id = food.id,
      pos = food.pos,
      amount = food.amount
     })
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
   if count_pairs(foods) < 3
     then
    insffcnt_food_time = time()
   end
  end
 end

 local current_interval =
   ant_entry_interval -
   ant_entry_variation *
   ant_gather_rate
 if count(ants) == 0 or
   time() - last_ant_entry >
   current_interval then
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
   if ant.food_held != nil then
    ant_gather_rate +=
      ant_gather_rate_inc
    if ant_gather_rate > 1 then
     ant_gather_rate = 1
    end
    ant_last_gather_rate =
      time()
   end
   deli(ants, i)
  elseif ant_dead(ant) then
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
 ant_gather_rate -=
   ant_gather_rate_dec * delta_t
 if ant_gather_rate < 0 then
  ant_gather_rate = 0
 end
 
 for i, reactn in
   ipairs(ant_reactns) do
  if ant_reactn_done(reactn)
    then
   deli(ant_reactns, i)
  end
 end

 check_mouse_eating()
 if selected_mode == "active"
   then
  set_mouse_dir()
 else
  set_auto_mouse_dir()
 end
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
	pal()
	palt(0, false)
	palt(15, true)
	
	draw_map_base()
	
 if blacklight then
  draw_phrmns(phrmns)
 end
 
 if debug then
  local hole =
    get_ant_hole_pos()
  pset(hole.x - .5, hole.y - .5,
    14)
 end
 
 for ant in all(ants) do
  draw_ant(ant)
 end

 if mouse_couch_check() then
  draw_map_top()
 end
 
 if mouse.anim != "run_up" and
   mouse.anim != "run_down" then
  if blacklight then
   pal(5, 2)
  end
  draw_mouse()
  if blacklight then
   pal(5, 5)
  end
 end

 for food in all(foods) do
  if blacklight then
   pal(9, 10)
  end
  draw_food(food)
  if blacklight then
   pal(9, 9)
  end
 end
 
 if mouse.anim == "run_up" or
   mouse.anim == "run_down" then
  if blacklight then
   pal(5, 2)
  end
  draw_mouse()
  if blacklight then
   pal(5, 5)
  end
 end

 if not mouse_couch_check() then
  draw_map_top()
 end
 
 for reactn in all(ant_reactns)
   do
  draw_ant_reactn(reactn)
 end
 
 draw_faucet_drip()
 pal()
 pal(5, 13)
 pal(0, 1)
 draw_tv()
 
 if debug then
  print("rate: " ..
    ant_gather_rate, 6, 5, 3)
  print("interval: " ..
   ant_entry_interval -
   ant_entry_variation *
   ant_gather_rate, 60, 5, 3)

  for ant in all(ants) do
   local offset =
     #tostr(ant.id) * 2 - 1
   print(ant.id, ant.pos.x -
     offset, ant.pos.y - 2, 3)
  end

  for food in all(foods) do
   local offset =
     #tostr(food.id) * 2 - 1
   print(food.id, food.pos.x -
     offset, food.pos.y - 7, 9)
  end
 end
end

function draw_map_base()
 if blacklight then
	 cls(1)
	 blcklght_clr()
	end
	
	map(0, 0, 0, 0, 16, 16)
	
	pal()
 palt(0, false)
	palt(15, true)
end

function draw_map_top()
 if blacklight then
  blcklght_clr()
 end
 
 map(16, 0, 0, 0, 16, 16)
 
 if blacklight then
  pal(2, 8)
  pal(5, 1)
  pal(6, 5)
  map(16, 0, 0, 0, 16, 16, 0x1)
  
  pal(5, 0)
  pal(6, 2)
  pal(13, 0)
  map(16, 0, 0, 0, 16, 16, 0x2)
  
  pal(13, 1)
  pal(6, 6)
  map(16, 0, 0, 0, 16, 16, 0x4)
 end
end

function blcklght_clr()
 pal(7, 14)
 pal(5, 0)
 pal(4, 2)
 pal(1, 0)
 pal(6, 2)
 pal(12, 13)
 pal(13, 1)
 pal(3, 0)
 pal(11, 1)
 pal(9, 10)
end
-->8
-- ants

ant_hole_pos = nil
ant_current_id = 0

ant_speed = 1.5
ant_time_limit = 120
ant_lifespan = 360
ant_dir_change_time = 1
ant_max_angle_change = .15
ant_food_detect_dist = 10
ant_sense_area_vrtcs = 6
ant_phrmn_detect_angle = .2
ant_phrmn_detect_dist = 5
ant_phrmn_focus_time = 5

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
		phrmn_following = nil,
		phrmn_change_time = nil
 }
 set_ant_dir(ant, foods, phrmns)

 log("ant spawned", {
  id = ant.id,
  pos = ant.pos,
  dir = ant.dir
 })

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
 local look_angle
 if not ant_returning(ant) then
  look_angle =
    atan2(ant.dir.x, ant.dir.y)
 else
  local hole_pos =
    get_ant_hole_pos()
  look_angle = atan2(
   hole_pos.x - ant.pos.x,
   hole_pos.y - ant.pos.y
  )
 end
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
     log("ant detected food", {
      id = ant.id,
      pos = ant.pos,
      dir = ant.dir,
      food_id = food.id,
      food_pos = food.pos
     })
     if ant.phrmn_following !=
       nil then
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
      ant.phrmn_following = nil
      ant.phrmn_change_time =
        nil
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
 set_ant_sense_area(ant)
 local phrmn_angles =
    get_angle_to_phrmn(phrmns,
    ant)
 local phrmn_angle
 if count_pairs(phrmn_angles) >
   0 then
  if ant.phrmn_following == nil
    and ant.food_held != nil
    and phrmn_angles[
    ant.food_held] != nil then
   ant.phrmn_following =
     ant.food_held
   log("ant started following "
     .. "pheromones of held "
     .. "food type while going "
     .. "home", {
      id = ant.id,
      pos = ant.pos,
      dir = ant.dir,
      food_id = ant.food_held,
      phrmn_id =
        ant.phrmn_following
     })
  end
  if ant.phrmn_following == nil
    then
   ant.phrmn_following =
     rnd_key(phrmn_angles)
   log("ant started following "
     .. "pheromones while "
     .. "going home", {
      id = ant.id,
      pos = ant.pos,
      dir = ant.dir,
      food_id = ant.food_held,
      phrmn_id =
        ant.phrmn_following
     })
  end
  phrmn_angle = phrmn_angles[
    ant.phrmn_following]
  if phrmn_angle == nil then
   ant.phrmn_following =
     rnd_key(phrmn_angles)
   phrmn_angle = phrmn_angles[
     ant.phrmn_following]
   log("ant switched to "
     .. "different pheromone "
     .. "trail while "
     .. "going home", {
      id = ant.id,
      pos = ant.pos,
      dir = ant.dir,
      food_id = ant.food_held,
      phrmn_id =
        ant.phrmn_following
     })
  end
 elseif ant.phrmn_following !=
   nil then
  ant.phrmn_following = nil
  log("ant lost pheromone "
    .. "trail while going "
    .. "home", {
     id = ant.id,
     pos = ant.pos,
     dir = ant.dir,
     food_id = ant.food_held
    })
 end
 
 if phrmn_angle != nil then
  ant.dir = {
   x = cos(phrmn_angle),
   y = sin(phrmn_angle)
  }
 else
  local waypoints_left =
    count(ant.waypoints)
  local waypoint =
   ant.waypoints[waypoints_left]

  if waypoints_left > 1 and
    abs(waypoint.x - ant.pos.x)
    < 1 and
    abs(waypoint.y - ant.pos.y)
    < 1 then
   local old_waypoint =
     deli(ant.waypoints)
   waypoint = ant.waypoints[
    waypoints_left - 1
   ]
   log("ant reached waypoint", {
    id = ant.id,
    pos = ant.pos,
    dir = ant.dir,
    waypoint = old_waypoint,
    new_waypoint = waypoint
   })
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
 end

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
   if debug_was_on then
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
   ant.phrmn_change_time =
     time()
   log("ant started " ..
     "following pheromones " ..
     "while spawning", {
      id = ant.id,
      pos = ant.pos,
      dir = ant.dir,
      phrmn_id = food_id
     })
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
   local food_id
   if ant.phrmn_following != nil
     and phrmn_angles[
     ant.phrmn_following] != nil
     and time() -
     ant.phrmn_change_time <
     ant_phrmn_focus_time
     then
    food_id =
      ant.phrmn_following
   else
    food_id = rnd_key(
      phrmn_angles)
   end
   phrmn_angle =
     phrmn_angles[food_id]
   if food_id !=
     ant.phrmn_following then
    log("ant started " ..
      "following pheromones", {
       id = ant.id,
       pos = ant.pos,
       dir = ant.dir,
       phrmn_id = food_id
      })
    if ant.phrmn_following !=
      nil then
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
     add(ant.waypoints, {
      x = ant.pos.x,
      y = ant.pos.y
     })
    end
    ant.phrmn_following =
      food_id
    ant.phrmn_change_time =
      time()
   end
  end
  if phrmn_angle != nil then
   ant_angle = phrmn_angle
  else
   if ant.phrmn_following != nil
     then
    log("ant added waypoint", {
     reason = "pheromone " ..
       "trail lost",
     id = ant.id,
     waypoint = ant.pos,
     phrmn_id =
       ant.phrmn_following
    })
    ant.phrmn_following = nil
    ant.phrmn_change_time = nil
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
 if nearest != nil and
   ant.phrmn_following == nil
   then
  sfx(9)
  add(ant_reactns,
    spawn_ant_reactn(ant))
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
   log("ant obtained food", {
    id = ant.id,
    pos = ant.pos,
    dir = ant.dir,
    food_id =
      ant.food_detected.id,
    food_pos =
      ant.food_detected.pos
   })
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
  add_phrmn(phrmns,
    phrmn_add_rate * delta_t,
    ant.pos, ant.food_held)
 end
end

function ant_returning(ant)
 return ant.food_held != nil or
    (ant.food_detected == nil
    and time() - ant.entry_time
    > ant_time_limit)
end

function ant_dead(ant)
 local dead = time() -
   ant.entry_time > ant_lifespan
 if dead then
  log("ant died", {
   id = ant.id,
   pos = ant.pos
  })
 end
 return dead
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
   log("ant arrived home", {
    id = ant.id,
    pos = ant.pos,
    dir = ant.dir,
    home = home
   })
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
    ant.food_detected == nil
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
  end
 end
 
 if not draw_sense_area then
  pset(
  	ant.pos.x,
  	ant.pos.y,
   color
  )
 end
end

function spawn_ant_reactn(ant)
 return {
  ant = ant,
  start_time = time()
 }
end

function ant_reactn_done(reactn)
 return time() -
   reactn.start_time > 1
end

function draw_ant_reactn(reactn)
 spr(210, reactn.ant.pos.x,
   reactn.ant.pos.y - 10)
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

function check_if_clsn_tile(x,
  y)
 local clsn_sprt = mget(
  x,
  y + 16
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

function init_collision_tiles()
 for x = 0, 15 do
  for y = 0, 15 do
   if check_if_clsn_tile(x, y)
     then
    set_tile_val(
     collision_tiles,
     x,
     y,
     true
    )
   end
  end
 end
end

function is_touching(ref_pos,
  tst_pos)
 local ref_x = flr(ref_pos.x)
 local ref_y = flr(ref_pos.y)
 local tst_x = flr(tst_pos.x)
 local tst_y = flr(tst_pos.y)
 return abs(tst_x - ref_x) < 2
   and abs(tst_y - ref_y) < 2
end

function set_tile_val(tbl, x, y,
  val)
 local col = tbl[x]
 if col == nil then
  col = {}
  tbl[x] = col
 end
 col[y] = val
end

function get_tile_val(tbl, x, y)
 local col = tbl[x]
 if col == nil then
  return nil
 end
 return col[y]
end

function get_tile_with_min_val(
  tbl, field)
 local min_val = nil
 local tile = nil
 for x, col in pairs(tbl) do
  for y, val in pairs(col) do
   if min_val == nil or
     val[field] < min_val then
    min_val = val[field]
    tile = {
     x = x,
     y = y
    }
   end
  end
 end
 return tile
end

function is_clsn_tile(x, y)
 return get_tile_val(
   collision_tiles, x, y) != nil
end

function is_in_clsn_tile(pos)
 return is_clsn_tile(
  flr(pos.x / 8),
  flr(pos.y / 8)
 )
end

function is_tile_in_bounds(x, y)
 return x >= 0 and x <= 15 and
   y >= 0 and y <= 15
end

function mnhtn_dist(x1, y1, x2,
  y2)
 return abs(x2 - x1) +
   abs(y2 - y1)
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

function check_debug_cmd()
 if not btn(🅾️) then
  debug_cmd_prgrss = 0
  return
 end
 
 if debug_cmd_prgrss == 0 and
   btnp(⬆️) then
  debug_cmd_prgrss = 1
 elseif debug_cmd_prgrss == 1
   and btnp(⬇️) then
  debug_cmd_prgrss = 2
 elseif debug_cmd_prgrss == 2
   and btnp(⬅️) then
  debug_cmd_prgrss = 3
 elseif debug_cmd_prgrss == 3
   and btnp(➡️) then
  debug_cmd_prgrss = 4
 end
end

function log(msg, data)
 if not debug_was_on then
  return
 end

 local total_msg = '{"msg": "'
   .. msg .. '"'
 for k, v in pairs(data) do
  if type(v) == "table" then
   local tmp_v = '{'
   if v.x != nil and v.y != nil
     then
    tmp_v ..= '"x": ' ..
      tostr(v.x) .. ', "y": '
      .. tostr(v.y)
   end
   for vk, vv in pairs(v) do
    if vk != "x" and vk != "y"
      then
     if tmp_v != '' then
      tmp_v ..= ', '
     end
     tmp_v ..= '"' .. vk ..
       '": "' .. tostr(vv) ..
       '"'
    end
   end
   v = tmp_v .. '}'
  elseif type(v) != "number"
    then
   v = '"' .. v .. '"'
  end
  total_msg ..= ', "' .. k ..
    '": ' .. tostr(v)
 end
 total_msg ..= '}'
 printh(total_msg, "log")
end
-->8
-- mouse

mouse_speed = 45
mouse_hide_time = 4
mouse_squeak_time = 1
mouse_anim_time = .1
mouse_idle_sprt = 240
mouse_hiding_spots = {
 {
  x = 4 * 8,
  y = 4 * 8
 },
 {
  x = 11 * 8,
  y = 12 * 8
 }
}
mouse_awkwrd_spots = {
 {
  x = 3 * 8,
  y = 5 * 8
 },
 {
  x = 5 * 8,
  y = 5 * 8
 }
}
mouse_squeaks = {
 0,
 11,
 12,
 13
}

function init_mouse()
 mouse = {
  pos = get_mouse_start_pos(),
  dir = {
   x = 0,
   y = 1
  },
  next_action = "squeak",
  time_until_action =
    mouse_hide_time,
  path = nil,
  flipped = false,
  start_pos = nil,
  end_pos = nil,
  move_prgrss = false,
  food_dropped = nil,
  anim = nil,
  anim_pos = 0,
  anim_prev_offset = 0
 }
 log("mouse spawned", {
  pos = mouse.pos,
  selected_mode = selected_mode
 })
end

function get_mouse_start_pos()
 local pos
 if selected_mode == "active"
   then
  pos = {
   x = 8 * 8,
   y = 2 * 8
  }
 else
  pos = rnd(mouse_hiding_spots)
 end
 return {
  x = pos.x,
  y = pos.y
 }
end

function check_mouse_eating()
 if btnp(❎) and selected_mode
   == "active" then
  start_mouse_nibble()
 end
end

function start_mouse_nibble()
 local pos = {
  x = mouse.pos.x / 8,
  y = mouse.pos.y / 8
 }
 if is_valid_food_pos(pos) then
  mouse.anim = "nibble"
  mouse.anim_pos = 0
  mouse.food_dropped =
    spawn_food(pos,
    mouse.flipped)
 else
  log("not valid food position",
    {
     pos = pos
    })
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
 if is_in_clsn_tile(end_pos)
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

function set_auto_mouse_dir()
 if mouse.end_pos == nil and
   mouse.anim != "nibble" then
  mouse.time_until_action -=
    delta_t
  if mouse.time_until_action >
    0 then
   return
  end
  if mouse.path == nil then
   if mouse.next_action ==
     "squeak" and
     ((count_foods() < 3 and
     time() -
     insffcnt_food_time >
     max_insffcnt_food_time) or
     (time() -
     ant_last_gather_rate >
     ant_max_gather_rate_wait))
     then
    mouse_squeak()
    ant_last_gather_rate =
      time()
    mouse.next_action = "enter"
    mouse.time_until_action =
      mouse_squeak_time
   elseif mouse.next_action ==
     "enter" then
    gen_mouse_food_path()
   elseif mouse.next_action ==
     "nibble" then
    start_mouse_nibble()
   elseif mouse.next_action ==
     "hide" then
    gen_mouse_hide_path()
   end
   return
  end

  mouse.start_pos = {
   x = mouse.pos.x,
   y = mouse.pos.y
  }
  
  local end_tile =
    deli(mouse.path, 1)
  mouse.end_pos = {
   x = end_tile.x * 8,
   y = end_tile.y * 8
  }
  
  local x = mouse.end_pos.x -
    mouse.start_pos.x
  local y = mouse.end_pos.y -
    mouse.start_pos.y
  mouse.dir = {
   x = mid(-1, x, 1),
   y = mid(-1, y, 1)
  }
  
  if mouse.dir.x != 0 then
   mouse.anim = "run_horiz"
   if mouse.dir.x == -1 then
    mouse.flipped = true
   else
    mouse.flipped = false
   end
  else
   if mouse.dir.y == -1 then
    mouse.anim = "run_up"
   else
    mouse.anim = "run_down"
   end
  end
  
  if count(mouse.path) == 0 then
   mouse.path = nil
   if mouse.next_action ==
     "enter" then
    mouse.next_action = "nibble"
    mouse.time_until_action = 0
   elseif mouse.next_action ==
     "hide" then
    mouse.next_action = "squeak"
    mouse.time_until_action =
      mouse_hide_time
   end
  end
 end
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

function gen_mouse_food_path()
 local options =
   get_food_pos_options()
 local food_pos = rnd(options)
 local dest = {
  x = food_pos.x,
  y = food_pos.y
 } 
 log("generating path for " ..
   "mouse to eat food", {
  dest = dest
 })
 mouse.path = calc_path(dest)
end

function gen_mouse_hide_path()
 local hiding_spot =
   rnd(mouse_hiding_spots)
 local dest = {
   x = flr(hiding_spot.x / 8),
   y = flr(hiding_spot.y / 8)
 }
 log("generating path for " ..
   "mouse to hide", {
  dest = dest
 })
 mouse.path = calc_path(dest)
end

function calc_path(dest)
 local open = {}
 local closed = {}
 local current = nil
 
 local start = {
  x = flr(mouse.pos.x / 8),
  y = flr(mouse.pos.y / 8)
 }
	 log("calculating mouse path", {
  start = start,
  dest = dest
 })
 set_tile_val(
  open,
  start.x,
  start.y,
  {
   parent = nil,
   dist = 0,
   estmt = mnhtn_dist(
    start.x,
    start.y,
    dest.x,
    dest.y
   )
  }
 )

 while current == nil or
   current.x != dest.x or
   current.y != dest.y do
  current =
    get_tile_with_min_val(open,
    "estmt")
  current_vals =
    open[current.x][current.y]
  
  set_tile_val(
   closed,
   current.x,
   current.y,
   current_vals
  )
  set_tile_val(
   open,
   current.x,
   current.y,
   nil
  )
  
  local adj_list = {
   {
    x = current.x - 1,
    y = current.y
   },
   {
    x = current.x + 1,
    y = current.y
   },
   {
    x = current.x,
    y = current.y - 1
   },
   {
    x = current.x,
    y = current.y + 1
   }
  }
  for tile in all(adj_list) do
   if is_tile_in_bounds(tile.x,
     tile.y) and
     not is_clsn_tile(tile.x,
     tile.y) and
     get_tile_val(closed,
     tile.x, tile.y) == nil then
    local dist =
      current_vals.dist + 1
    local estmt = dist +
      mnhtn_dist(
       tile.x,
       tile.y,
       dest.x,
       dest.y
      )
    local open_tile_val =
      get_tile_val(open, tile.x,
      tile.y)
    if open_tile_val == nil or
      open_tile_val.dist > dist
      then
     set_tile_val(
      open,
      tile.x,
      tile.y,
      {
       parent = current,
       dist = dist,
       estmt = estmt
      }
     )
    end
   end
  end
 end
 
 local path = {}
 local current_dir = {
  x = 0,
  y = 0
 }
 while current != nil do
  val = get_tile_val(closed,
    current.x, current.y)
  local parent = val.parent
  if parent != nil then
   local dir = {
    x = parent.x - current.x,
    y = parent.y - current.y
   }
   if dir.x != current_dir.x or
     dir.y != current_dir.y then
    add(path, current, 1)
    current_dir = dir
   end
  end
  current = parent
 end
 return path
end

function mouse_couch_check()
 if mouse.anim == "run_horiz" or
   mouse.anim == "run_up" or
   mouse.anim == "run_down" then
  return false
 end
 
 for spot in
   all(mouse_awkwrd_spots) do
  if flr(mouse.pos.x) == spot.x
    and flr(mouse.pos.y) ==
    spot.y then
   return true
  end
 end
 
 return false
end

function mouse_squeak()
 local squeak =
   rnd(mouse_squeaks)
 sfx(squeak)
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
    if mouse.anim_prev_offset !=
      3 then
     sfx(1)
    end
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
  mouse.anim_prev_offset =
    offset
  if mouse.anim_pos >= 18 *
    mouse_anim_time then
   mouse.anim = nil
   mouse.anim_pos = 0
   mouse.anim_prev_offset = 0
   mouse.food_dropped = nil
   mouse.next_action = "hide"
   mouse.time_until_action = 0
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
food_bite_size = .07

function get_food_tile_pos(
  pixel_pos, flipped)
 local x = 4
 if flipped then
  x -= 1
 end
 return {
  x = (pixel_pos.x - x) / 8,
  y = (pixel_pos.y - 5) / 8
 }
end

function get_food_pixel_pos(
  tile_pos, flipped)
 local x = 4
 if flipped then
  x -= 1
 end
 return {
  x = tile_pos.x * 8 + x,
  y = tile_pos.y * 8 + 5
 }
end

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
     if food.tile_pos.x == x
       and food.tile_pos.y ==
       y then
      spot_taken = true
     end
    end
    if not spot_taken then
     add(pos_options, {
      x = x,
      y = y
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

function spawn_food(tile_pos,
  flipped)
 if not is_valid_food_pos(
   tile_pos) then
  log("tried to spawn food " ..
    "at invalid position", {
     tile_pos = tile_pos
    })
  return
 end

 local food = {
  id = get_food_id(),
  pos = get_food_pixel_pos(
    tile_pos, flipped),
  tile_pos = tile_pos,
  amount = 1,
  anim_frame = 0,
  flipped = flipped
 }
 add(foods, food)
 log("food spawned", {
  id = food.id,
  pos = food.pos,
  tile_pos = food.tile_pos,
  amount = food.amount
 })
 if count_pairs(foods) >2 then
  insffcnt_food_time = nil
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

function count_foods()
 local count = 0
 for k, v in pairs(foods) do
  count += 1
 end
 return count
end

function bite_food(food)
 local new_amount = food.amount
   - food_bite_size
 if new_amount < 0 then
  new_amount = 0
 end
 log("food bitten", {
  id = food.id,
  pos = food.pos,
  tile_pos = food.tile_pos,
  old_amount = food.amount,
  new_amount = new_amount
 })
 food.amount = new_amount
end

function draw_food(food)
 local frame = ceil(
   food.anim_frame *
   food.amount)
 spr(244 + frame,
   food.tile_pos.x * 8,
   food.tile_pos.y * 8, 1, 1,
   food.flipped)
end
-->8
-- pheromones

phrmn_add_rate = .3
phrmn_evap_rate = .005
phrmn_evap_mult = 5

function add_phrmn(phrmns,
   amount, pos, food_id)
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
 
 phrmn += amount
 phrmn = min(phrmn, 1)
 cell[food_id] = phrmn
end

function phrmns_evap(phrms)
 for x, col in pairs(phrmns) do
  for y, cell in pairs(col) do
   for food_id, phrmn in
     pairs(cell) do
    local rate = phrmn_evap_rate
      * phrmn * phrmn_evap_mult
    rate = max(rate,
      phrmn_evap_rate)
    phrmn -= rate * delta_t
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
 if ant_returning(ant) then
  bounds =
    get_phrmn_dtct_bnds(ant)
  local hole_pos =
    get_ant_hole_pos()
  look_angle = atan2(
   hole_pos.x - ant.pos.x,
   hole_pos.y - ant.pos.y
  )
 elseif ant.dir != nil then
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
        ant_phrmn_detect_dist
        and
        angle > (look_angle -
        ant_phrmn_detect_angle)
        and
        angle < (look_angle +
        ant_phrmn_detect_angle)
        and
        not is_touching(ant.pos,
        {x = i, y = j})
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
   local total = 0
   for food_id, phrmn in
     pairs(cell) do
    total += phrmn
   end
   local flr_clr = pget(x, y)
   if total > 0 and
     total <= .5 then
    local clr = 2
    if flr_clr == 14 or flr_clr
      == 2 then
     clr = 5
    end
    pset(x, y, clr)
   elseif total > .5 then
    local clr = 14
    if flr_clr == 14 or flr_clr
      == 2 then
     clr = 15
    end
    pset(x, y, clr)
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

function add_test_phrmns(phrmns)
 local y = 6 * 8
 local min_x = 1 * 8
 local max_x = 15 * 8 - 1
 local delta = 1 / (max_x -
   min_x + 1)
 local amount = 0
 for x = min_x, max_x do
  amount += delta
  local pos = {
   x = x,
   y = y
  }
  add_phrmn(phrmns, amount, pos,
    0)
 end
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
77777777ffffffff88ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffff88ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffff8fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
77777777ffffffff8fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00
00eeeeeeeeeeeeeeeeeeeeeee0000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0000000000000eeeeeeeeeeeeeeeeeeeeeeee00
0e0eeeeeeeeeeeeeeeeeeeee000000121000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000121000000eeeeeeeeeeeeeeeeeeeeee0e0
0e0eeeeeeeeeeeeeeeeeeeee000001626100000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000001626100000eeeeeeeeeeeeeeeeeeeeee0e0
0ee0eeeeeeeeeeeeeeeeeeee000116e26e11000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000116e26e11000eeeeeeeeeeeeeeeeeeeee0ee0
0ee0eeeeeeeeeeeeeeeeeeee00066e62e6e6000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00066e62e6e6000eeeeeeeeeee00000000000ee0
0ee0eeeeeeeeeeeeeeeeeeee000222222222000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000222222222000eeeeeeeeeee01111111110ee0
0eee0eeeeeeeeeeeeeeeeeee0002e6e26e62000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0002e6e26e62000eeeeeeeeee001111111110ee0
0eee0eeeeeeeeeeeeeeeeeee000266626662000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000266626662000eeeeeeeeee001111111110ee0
0eee0eeeeeeeee0eeeeeeeee000266626662000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000266626662000eeeeeeeeee001111111110ee0
0eeee0eeeee0ee0eeeeeeeee00ee2222222e000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00ee2222222e000eeeeeeeeee001111111110ee0
0eeee0eeeee0e0eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0101111111110ee0
0eeeee0eeee0e000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0101111111110ee0
0eeeee0eeee0000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee0101111111110ee0
0eeeeee2222000000002222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222220100000000000ee0
0eeeeee2110000000000011111111111111111111111111111111111111111111111111111111111e1112eee2eee2eee2eee2eee2eee2eee0101111111110ee0
0eeeeee210000000000002111111111111111111111111111111111111111111111111111111112211112eee2eee2eee2eee2eee2eee2eee0101111111110ee0
0eeeeee200000000000022111111111111111111111111111111111111111111111111111111120111112eee2eee2eee2eee2eee2eee2eee010111111110eee0
0eeeeee2000000000002d21111111111111111111111111111111111111111111111111111110e1111112222222222222222222222222222001111111110eee0
0eeeeee200000000002dd2111111111111000011111111111111111111111111111111111112e11111112eee2eee2eee2eee2eee2eee2eee001111111000eee0
0eeeeee200000000028d621111111111108888000111111111111111111111111111111111e2111111112eee2eee2eee2eee2eee2eee2eee000000000010eee0
0eeeeee2000000002d7d21111111111110088888800011111111111111111111111111112021111111112eee2eee2eee2eee2eee2eee2eee000111111010eee0
0eeeeee200000002dd762111111111111000008888880001111111111111111111111112e111111111112222222222222222222222222222010100100010eee0
0eeeeee200000002ddc2111111111111100000000888088011111111111111111111120e1111111111112eee2eee2eee2eee2eee2eee2eee000100100010eee0
0eeeeee201000002dd2111111220011110000000000088801111111111111111111220211111111111112eee2eee2eee2eee2eee2eee2eee000111111010eee0
0eeeeee210110002d21111122110111111000800000088001111111111111111112222111111111111102eee2eee2eee2eee2eee2eee2eee000100100000eee0
0eeeeee210111102211111211111111111088080800088001111111111111111222221111111111111112222222222222222222222222222000100100010eee0
0eeeeee211001822111112111111111111088808080880001111111111111110212011111111111111112eee2eee2eee2eee2eee2eee2eee000111111010eee0
0eeeeee21111002121111211111111111000088080088000111111111111122212e211111111111111112eee2eee2eee2eee2eee2eee2eee010000000000eee0
0eeeeee211112212011112111111111110888008008880001111111111112211122111111111111111112eee2eee2eee2eee2eee2eee2eee001111111111eee0
0eeeeee2111102202111211111111111088888800088000111111111111221111e1111111111111111112222222222222222222222222222011111111111eee0
0eeeeee211111002122211111111111108888880808800011111111112211111101111111111111111112eee2eee2eee2eee2eee2eee2eee021111111111eee0
0eeeeee211111112111111211111111100088808088000111111111122111111201111111111111111112eee2eee2eee2eee2eee2eee2eee021111111111eee0
0eeeeee211111112111220011111111088000880088000111111112211111111221111111111111111112eee2eee2eee2eee2eee2eee2eee221111111111eee0
0eeeeee211111112112110111111111088888000888000111111120111111112222111111111111111112222222222222222222222222222221111111111eee0
0eeeeee211111121121111111111000088888080880001111111221111111122112111111111111111112eee2eee2eee2eee2eee2eee2eee201111111111eee0
0eeeeee211112211121111111111088800880800880001111122111111111221112111111111111111112eee2eee2eee2eee2eee2eee2eee021111111111eee0
0eeeeee211121111121111111110888888000008800011111221111111112211112111111111111111112eee2eee2eee2eee2eee2eee2eee021111111111eee0
0eeeeee211121111211111111110000888888008800011112111111111122111112111111111111111112222222222222222222222222222221111111111eee0
0eeeeee211112222111111111110080008888088800011221111111111221111112111111111111111112eee2eee2eee2eee2eee2eee2eee221eeeeeeee1eee0
0eeeeee211111111111111111110808080008888000112211111111112211111112111111111111111112eee2eee2eee2eee2eee2eee2eee201e222222e1eee0
0eeeeee211111111111111111110000808080088000121111111111122211111112111111111111111112eee2eee2eee2eee2eee2eee2eee021e222222e1eee0
0eeeeee211111111111111111111110000808000002211111111111222111111112111111111111111112222222222222222222222222222021e222222e1eee0
0eeeeee211111111111111111111111110080800001111111112222121111111112111111111111111112eee2eee2eee2eee2eee2eee2eee221e222222e1eee0
0eeeeee211111111111111111111111111100080011111111121111121111111112111111111111111112eee2eee2eee2eee2eee2eee2eee221eeeeee001eee0
0eeeeee211111111111111111111111111111100011111111221111221111111112111111111111111112eee2eee2eee2eee2eee2eee2eee201eeeee0e01eee0
0eeeeee211111111111111111111111111111211111111111211111011111111112111111111111111112222222222222222222222222222021e222202e1eee0
0eeeeee211111111111111111111111111122111111111112111111211111111112111111111111111112eee2eee2eee2eee2eee2eee2eee021e222222e1eee0
0eeeeee211111111111111111111111111211111111111121111111221111111112111111111111111112eee2eee2eee2eee2eee2eee2eee221e222222e1eee0
0eeeeee211111111111111111111111112111111111111211111111211111111112111111111111111112eee2eee2eee2eee2eee2eee2eee221e222222e1eee0
0eeeeee211111111111111111111111201111111111111211111111211111111110211111111111111112222222222222222222222222222221eeeeeeee1eee0
0eeeeee211111111111111111111112111111111111112111111112111111111111e11111111111111112111111111111111111111111111111111111111eee0
0eeeeee211111111111111111111121111111111111121111111112111111111111e11111111111111110111111111111111111111111111111111111111eee0
0eeeeee211111111111111111112111111111111111211111111121111111111111e11111111111111110111111111111111111111111111111111111111eee0
0eeeeee211111111111111111121111111111111111111111111121111111111111e11111111111111112111111111111111111111111111111111111111eee0
0eeeeee211111111111111111211111111111111112111111111211111111111111e11111111111111112111111111111111111111111111111111111111eee0
0eeeeee211111111111111111111111111111111121111111111211111111111111e11111111111111112111111111111111111111111111111111111111eee0
0eeeeee211111111111111121111111111111111211111111112211111111111111e11111111111111112111111111111111111111111111111111111111eee0
0eeeeee211111111111111211111111111111112111111111112111111111111111211111111111111112111111111111111111111111111111111111111eee0
0eeeeee211111111111111211111111111111111111111111112111111111111111011111111111111112111111111111111111111111111111111111111eee0
0eeeeee21111111111111121111111111111112111111111112111111111111111121111111111111111202222222222222222222222222222222222220eeee0
0eeeeee2111111111111112111111111111112111111111111211111111111111112111111111111111102222222222222222222222222222222222220eeeee0
0eeeeee211111111111111211111111111112111111111111211111111111111111211111111111111110222222222222222222222222222222222220eeeeee0
0eeeeee211111111111111211111111111111111111111111211111111111111111211111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111121111111111101111111111112111111111111111111211111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111211111111111112111111111111111111211111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111112111111112111111111111121111111111111111111211111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211101111111111111211111121111111111111121111111111111111111e11111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111211111111111111111111aaa111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111110111121111111111111111111211111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111112111111111111112111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111021111111111111112111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111221111111111111121111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111121111111111111121111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111112111111111111121111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee2111111111111111111111121111111111111a1111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111211111111111aaa111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111211111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111121111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111112111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111112111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111011111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111121111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111112111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111112111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111111211111111111111111111111111111111111111111111110000001111111110000001111111111111112eeeeee0
0eeeeee211111111111111111111111111111121111111111111111111111111111111111111111111110000001111111110000001111111111111112eeeeee0
0eeeeee211111111111111111111111111111121111111111111111111111111111111111111222222222222222222222222222222222222211111112eeeeee0
0eeeeee211111111111111111111111111111112111111111111111111111111111111111110220000000000000000000000000000000002211111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111110202222222222222222222222222222222220211111112eeeeee0
0eeeeee211111111111111111111111111111111211111111111111111111111111111111110202222222222222222222222222222222220211111112eeeeee0
0eeeeee2111111111111111111111111111111111211111111111111111111111111111111102022222222222222022e2222222222222220211111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111110202222222222222220eae222222222222220211111112eeeeee0
0eeeeee2111111111111111111111111111111111121111111111111111111111111111111102022222222222222e01e2222222222222220211111112eeeeee0
0eeeeee211111111111111111111111111111111111211111111111111111111111111111110202222222222222eae10e222222222222220211111112eeeeee0
0e222ee2111111111111111111111111111111111111111111111111111111111111111100102022222222222222e00eae22222222222220210011112eeeeee0
0e2882221111111111111111111111111111111111112111111111111111111111111111000020222222222222220101e222222222222220200011112eeeeee0
0e28888200000001111111111111111111111111111112111111111111111111111111110000202222222222222222e02222222222222220200011112eeeeee0
0e288a820000000111111111111111111111111111111111111111111111111111111111000020222222222222222ee52222222222222220200011112eeeeee0
0e28888200000001111111111111111111111111111111211111111111111111111111110000202222222222222222222222222222222220200011112eeeeee0
0e28228200000001111111111111111111111111111111101111111111111111111111110000202222222222222222222222222222222220200011112eeeeee0
0e28228200000001111111111111111111111111111111122111111111111111111111111000202222222222222222222222222222222220200111112eeeeee0
0e28228200000001111111111111111111111111111111112211111111111111111111111010202222222222222222222222222222222220210111112eeeeee0
0e28228200000001111111111111111111111111111111111211111111111111111111111110202222222222222222222222222222222220211111112eeeeee0
0e28228200000001111111111111111111111111111111111221111111111111111111111110202222222222222222222222222222222220211111112eeeeee0
0e28288200000001111111111111111111111111111111111122111111111111111111111110202222222222222222222222222222222220211111112eeeeee0
0e28888200000001111111111111111111111111111111111112111111111111111111111110220000000000000000000000000000000002211111112eeeeee0
0e2888220000000111111111111111111111111111111111111aaa1111111111111111111110222222220222202222222220000202222222211111112eeeeee0
0e2822e211111111111111111111111111111111111111111111111111111111111111111111000000000000000000000000000000000000111111112eeeeee0
0e22eee211111111111111111111111111111111111111111111111111111111111111111111111100110000001111111000000001100111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111100110000001111111010000001100111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111110111101111111110000101111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111110111101111111110111101111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111110111111111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111112eeeeee0
0eeeeee222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222222eeeeee0
0eeee00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00eeee0
0ee00eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee00ee0
000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000004040000000001000000010100000000040400000001010000000101000000000000000002010100010001010000000000000002010101000000010100000000000000000101010000000000000000000000000000000000000000000000000000000000000000000000000000020001000002000000000000000000
0000020202000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
a1d0d0d0ffd0d0d0d0d0d0d0d0d0a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
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
__sfx__
140100002c55032550395503d5503f5503e5503d5503955035550305502c55027550005000050000500005000050000500005000050000500285502f55032550355503755036550355503255032550365501a500
900000000b1501115013150131500f15009150081500b1500d1500b15007150001500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300001b770150700f0701277015770187701c7701f0502303026720297202c7402e06030070320703407035040360103700037000380003800038000390003900039000390003900039000390003900039000
0001000022650226502e3500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002265022650273501630018300153000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
900d00002602322002210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
900d00002902122000210000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100002c7602c0702c0702c0202c0002b0002b0002b0002b7002b3002a4002a6002a6002a6002a4002930029700290002900029000290002800028000280002870028300285002750027500275002750027500
000300003571035010347103472034020357203673036030367303674036040357403474034050347503475035060367603876038070387703877038070387703877038030387103870038000387003870038000
00010000291002951029510297202973029730290302f030330303503036040370403804038030380203802038010380103801038010380003800038000380003800038000380003800038000380003800038000
000300000907009070090000900009700097000970009500095000950009500095000950009500095000950009500095000950009500095000950009500095000950009500095000a5000a5000a5000a5000b500
1401000038550395503a5503a550365502c5502e5503055032550325502c55027550005000050000500005000050000500005000050000500285502f55034550345503455035550345503255030550365501a500
140100002755029550395502b5502e55031550325503355035550355503555027550005000050000500005000050000500005000050000500365503655036550355503655037550375503655032550315501a500
140100002c5502f550315502d5502d5502e5502f5502f5502e5502f5503955027550005000050000500005000050000500005000050000500315503155031550355503755036550355503255034550295501a500
