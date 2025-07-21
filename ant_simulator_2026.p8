pico-8 cartridge // http://www.pico-8.com
version 42
__lua__
-- ant simulator 2026
-- by cole cecil

debug = false
ants = {}
foods = {}
phrmns = {}
last_ant_entry = nil
ant_entry_interval = 5

function _init()
 if debug then
  printh("", "log", true)
 end
 
 init_ant_hole_pos()
 add(foods, spawn_food(1))
 add(foods, spawn_food(2))
end

function _update()
 for i, food in ipairs(foods) do
  if food.amount <= 0 then
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
  if ant_ready_to_exit(ant) then
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
 
 phrmns_evap(phrms)
end

function _draw()
	cls(15)
	palt(0, false)
	palt(15, true)
	
	map(0, 0, 0, 0, 16, 16)

 if debug then
  local hole =
    get_ant_hole_pos()
  pset(hole.x - .5, hole.y - .5,
    14)
  draw_phrmns(phrmns)
 end

 for food in all(foods) do
  draw_food(food)
 end
 
 for ant in all(ants) do
  draw_ant(ant)
 end
 
 draw_mouse()
 
 map(16, 0, 0, 0, 16, 16)
end
-->8
-- ants

ant_hole_pos = nil

ant_speed = .05
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
  pos = get_ant_hole_pos(),
		entry_time = time(),
		dir = nil,
		dir_change_time = nil,
		food_detected = nil,
		food_held = nil,
		sense_area = nil
 }
 set_ant_dir(ant, foods, phrmns)
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
 for y = 112, 128 do
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
end

function get_ant_hole_pos()
 return {
  x = ant_hole_pos.x,
  y = ant_hole_pos.y
 }
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
  local food_id = rnd_key(
     phrmn_angles)
  phrmn_angle =
    phrmn_angles[food_id]
 end
 
 local home =
   get_ant_hole_pos()
 local home_angle = atan2(
  home.x - ant.pos.x,
  home.y - ant.pos.y
 )
 
 local angle = home_angle
 if phrmn_angle != nil then
  angle = (phrmn_angle +
    home_angle) / 2
 end
 ant.dir = {
  x = cos(angle),
  y = sin(angle)
 }
 ant.dir_change_time = time()
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
   printh("spawning with " ..
     "pheromone detected:",
     "log")
   local food_id = rnd_key(
     phrmn_angles)
   phrmn_angle =
     phrmn_angles[food_id]
   printh(" food id = " ..
     food_id, "log")
   printh(" angle = " ..
     phrmn_angle, "log")
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
  end
  if phrmn_angle != nil then
   ant_angle = phrmn_angle
  else
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
 local pos = {}
 pos.x = ant.pos.x +
   ant.dir.x * ant_speed
 pos.y = ant.pos.y +
   ant.dir.y * ant_speed
 
 local colliding =
   is_collision(pos)
 if colliding then
  pos.x -= ant.dir.x * ant_speed
  colliding = is_collision(pos)
  if colliding then
   pos.x += ant.dir.x *
     ant_speed
   pos.y -= ant.dir.y *
     ant_speed
   colliding = is_collision(pos)
   if colliding then
    pos.x -= ant.dir.x *
      ant_speed
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
  return abs(diff.x) < 1 and
    abs(diff.y) < 1
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
-->8
-- mouse

function draw_mouse()
 //spr(32, 14 * 8, 2 * 8)
end
-->8
-- food

food_bite_size = .05

function spawn_food(num)
 if num == 1 then
  return {
   id = num,
   pos = {
    x = 8 * 8 + 4,
    y = 2 * 8 + 4
   },
   amount = 1
  }
 elseif num == 2 then
  return {
   id = num,
   pos = {
    x = 2 * 8 + 4,
    y = 4 * 8 + 4
   },
   amount = 1
  }
 end
end

function bite_food(food)
 food.amount -= food_bite_size
end

function draw_food(food)
 spr(16, food.pos.x - 4,
   food.pos.y - 4)
end
-->8
-- pheromones

phrmn_add_rate = .005
phrmn_evap_rate = .0001

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
 
 phrmn += phrmn_add_rate
 phrmn = min(phrmn, 1)
 cell[food_id] = phrmn
end

function phrmns_evap(phrms)
 for x, col in pairs(phrmns) do
  for y, cell in pairs(col) do
   for food_id, phrmn in
     pairs(cell) do
    phrmn -= phrmn_evap_rate
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
__gfx__
ffffffff5555555555555555555555555555555555555555ffffffffffffffff67776777ffff6777ffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff5577777777777755777777777777777777777777ffffffffffffffff67776777ffff6777ffffffffffffffffffffffffffffffffffffffffffffffff
ff7ff7ff5577777777777755777777777010101010101077ffffff5fffffffff67776777ffff6777ffffffffffffffffffffffffffffffffffffffffffffffff
fff77fff575777777777757577777777111011d4d1101117fff5ff5fffffffff66666666ffff6666ffffffffffffffffffffffffffffffffffffffffffffffff
fff77fff57577777777775757777777711011d646d110117fff5f5ffffffffff67776777ffff6777ffffffffffffffffffffffffffffffffffffffffffffffff
ff7ff7ff577577777777577577777777011dd67467dd1107fff5f501ffffffff67776777ffff6777ffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff5775777777775775777777770116676476761107fff5151010ffffff67776777ffff6777ffffffffffffffffffffffffffffffffff00000000000fff
ffffffff5775777777775775777777770104444444440107fff15101010fffff66666666ffff6666ffffffffffffffffffffffffffffffffff05555555550fff
ffffffff5777577777757775777777770104767467640107ff10501010101ffffffffffffffffffffffffffffffffffffffffffffffffffff005555555550fff
ffff99ff5777577777757775777777770104666466640107f1010101010104fffffffffffffffffffffffffffffffffffffffffffffffffff005555555550fff
fff99aaf577757777775777577777777010466646664010710101010101044fffffffffffffffffffffffffffffffffffffffffffffffffff005555555550fff
ff99aa9f577775777757777577777777017744444447010701010101010454fffffffffffffffffffffffffffffffffffffffffffffffffff005555555550fff
f9aa9aaf577775777757777577777777777777777777777700101010104554ffffffffffff1111ffffffffffffffffffffffffffffffffff0505555555550fff
fa9aaa9f577777577577777577777777777777777777777700010101048554fffffffffff12222111fffffffffffffffffffffffffffffff0505555555550fff
ffffffff577777577577777577777777777777777777777700000010457e4ffffffffffff11222222111ffffffffffffffffffffffffffff0505555555550fff
ffffffff5777777447777775444444444444444444444444000000045a754ffffffffffff11111222222111fffffffffffffffffffffffff0500000000000fff
f5f6ffff5777777447777775ffffffff57777774ffffffff5000000455c4fffffffffffff111111112221221ffffffffffffffffffffffff0505555555550fff
556e6ffe5777777447777775ffffffff57222774ffffffff5ff00004554ffffff665dffff111111111112221ffffffffffffffffffffffff0505555555550fff
f66fffef5777777447777775ffffffff57288224fffffffff5ff000454fffff66ffdffffff11121111112211ffffffffffffffffffffffff050555555550ffff
e66fffef577777744777777544444444572888820000000ff5ffff044fffff6fffffffffff12212121112211ffffffffffffffffffffffff005555555550ffff
f566fffe57777774477777757777777757288a820505050fff55f846fffff6ffffffffffff12221212122111ffffffffffffffffffffffff005555555000ffff
56666ffe577777744777777577777777572888820050500fffff516d6ffff6fffffffffff111122121122111ffffffffffffffffffffffff000000000050ffff
e5666eef577777744777777577777777572822820505050fffff66d65ffff6fffffffffff122211211222111ffffffffffffffffffffffff000555555050ffff
556fffff577777744777777555555555572822820050500fffff56656fff6fffffffffff122222211122111fffffffffffffffffffffffff050500500050ffff
ffffffff5777777447777775ffffffff572822820505050ffffff556f666ffffffffffff122222212122111fffffffffffffffffffffffff000500500050ffff
ffffffff5777777447777775ffffffff572822820050500ffffffff6ffffff6fffffffff11122212122111ffffffffffffffffffffffffff000555555050ffff
ffffffff5777777447777775ffffffff572822820505050ffffffff6fff665dffffffff122111221122111ffffffffffffffffffffffffff000500500000ffff
ffffffff5777777447777775ffffffff572828820050500ffffffff6ff6ff5fffffffff122222111222111ffffffffffffffffffffffffff000500500050ffff
ffffffff5777755775577775ffffffff572888820505050fffffff6ff6ffffffffff11112222212122111fffffffffffffffffffffffffff000555555050ffff
ffffffff5775577777755775ffffffff572888220000000fffff66fff6ffffffffff12221122121122111fffffffffffffffffffffffffff050000000000ffff
ffffffff5557777777777555ffffffff57282274fffffffffff6fffff6fffffffff12222221111122111ffffffffffffffffffffffffffff00ddddddddddffff
ffffffff5555555555555555ffffffff57227774fffffffffff6ffff6ffffffffff11112222221122111ffffffffffffffffffffffffffff05ddddddddddffff
ffffffffffffffffffffffffffffffffffffffffffffffffffff6666fffffffffff11211122221222111ffffffffffffffffffffffffffff54ddddddddddffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1212121112222111fffffffffffffffffffffffffffff54ddddddddddffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1111212121122111fffffffffffffffffffffffffffff44ddddddddddffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111121211111ffffffffffffffffffffffffffffff44ddddddddddffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff112121111ffffffffffffffffffffffffffffff45ddddddddddffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111211fffffffffffffffffffffffffffffff54ddddddddddffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111fffffffffffffffffffffffffffffff54ddddddddddffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44ddddddddddffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d77777777dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff45d76666657dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54d76666665dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54d76611161dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d76655611dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d77777711dffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff45d77777777dffff
ffffffffffffffffffff111111fffffffff111111fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54d76666667dffff
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
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
__label__
01111110011111100111111001111110011111100111111001111110011111100111111001111110011111100111111001111110011111100111111001111110
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
01111114411111144111111441111114411111144111111441111114411111144111111441111114411111144111111441111114411111144111111441111110
01111114444444444444444444444444444044440444444444444444444444444444444444444444444444444444444444444444444444444445464441111110
155555514444444444444444444444444444444444444444444444444444444444449944444444444444444444444444444444444444444444556e6415e55551
1555555144444444444444444444444444444444444444444444444444444444444999a44444444444444444444444444444444444444444444664441e555551
15555551444444444444444444444444444444444444444444444444444444444499aa94444444444444444444444444444444444444444444e664441e555551
155555514444444444444444444444444444444444444444444444444444444449aa9aa444444444444444444444444444444444444444444444564415e55551
15555551444444444444444444444444444444444444444444444444444444444a9aaa9444444444444444444444444444444444444444444445666415e55551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444566eee555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444445564441111110
01111114444444444444444444444444444444044444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
15555551444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444415555551
01111114444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444444441111110
01111114411111144111111441111114411111144111111441111114411111144111111441111114411111144111111441111114411111144111111441111110
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
15555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551155555511555555115555551
01111110011111100111111001111110011111100111111001111110011111100111111001111110011111100111111001111110011111100111111001111110

__gff__
0000000000000000000001010101010000000000000000000000010101010100000000000000000000000001010000000000000000000000000002010102020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0103030405030303030303040503030201030304050303030303030405030e0fff01ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
1113131415131313131313141513131211060714151313131313131415131e1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffff18ffffffffffff09080808082221161718191affffffffffffffff2e2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffffffffffffffffff09080808082221262728292affffffffffffffff3e3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffffffffffffffffff09080808082221363738393affffffffffffffff4e4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21ffffffffffffffffff0908080808222146ff48494affffffffffffffff5e5fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
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
a1a3a4a5ffffffffffffffffffffa1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1b3b4b5ffffffffffffffffffffa1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1c3c4ffffffffffffffffffffffa1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffffffffffffa1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffffa6a7a7a7a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffffb6a1a1a1a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffffffffffffffa1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffffffffffffffa1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffff51ffffffff56a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffffffffffffffa1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffffffffffffffa1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffb8b9babbbcbda1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffff91c9cacbcc96a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1a2a2a2a2a2a2a2a2a2a2a2a2a2a2a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
