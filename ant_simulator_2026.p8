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
 printh("", "log", true)

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
end
-->8
-- ants

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

function get_ant_hole_pos()
 return {x=31.5, y=16.5}
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
 
 local home = get_ant_hole_pos()
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
ffffffff5555555555555555555555555555555555555555777777777777777767776777ffff6777ffffffffffffffffffffffffffffffff5555555555555555
ffffffff5577777777777755777777777777777777777777777777777777777767776777ffff6777ffffffffffffffffffffffffffffffff7777777777777755
ff7ff7ff5577777777777755777777777010101010101077777777577777777767776777ffff6777ffffffffffffffffffffffffffffffff7777777777777755
fff77fff575777777777757577777777111011d4d1101117777577577777777766666666ffff6666ffffffffffffffffffffffffffffffff7777777777777575
fff77fff57577777777775757777777711011d646d110117777575777777777767776777ffff6777ffffffffffffffffffffffffffffffff7777777777777575
ff7ff7ff577577777777577577777777011dd67467dd1107777575017777777767776777ffff6777ffffffffffffffffffffffffffffffff7777777777775775
ffffffff5775777777775775777777770116676476761107777515101077777767776777ffff6777ffffffffffffffffffffffffffffffff7700000000000775
ffffffff5775777777775775777777770104444444440107444151010104444466666666ffff6666ffffffffffffffffffffffffffffffff7705555555550775
ffffffff5777577777757775777777770104767467640107ff10501010101fffffffffffffffffffffffffffffffffffffffffffffffffff7005555555550775
ffff99ff5777577777757775777777770104666466640107f1010101010104ffffffffffffffffffffffffffffffffffffffffffffffffff7005555555550775
fff99aaf577757777775777577777777010466646664010710101010101044ffffffffffffffffffffffffffffffffffffffffffffffffff7005555555550775
ff99aa9f577775777757777577777777017744444447010701010101010454ffffffffffffffffffffffffffffffffffffffffffffffffff7005555555550775
f9aa9aaf577775777757777577777777777777777777777700101010104554ffffffffffff1111ffffffffffffffffffffffffffffffffff0505555555550775
fa9aaa9f577777577577777577777777777777777777777700010101048554fffffffffff12222111fffffffffffffffffffffffffffffff0505555555550775
ffffffff577777577577777577777777777777777777777700000010457e4ffffffffffff11222222111ffffffffffffffffffffffffffff0505555555550775
ffffffff5777777447777775444444444444444444444444000000045a754ffffffffffff11111222222111fffffffffffffffffffffffff0500000000000775
f5f6ffff5777777447777775ffffffff57777774ffffffff5000000455c4fffffffffffff111111112221221ffffffffffffffffffffffff0505555555550775
556e6ffe5777777447777775ffffffff57222774ffffffff5ff00004554ffffff665dffff111111111112221ffffffffffffffffffffffff0505555555550775
f66fffef5777777447777775ffffffff57288224fffffffff5ff000454fffff66ffdffffff11121111112211ffffffffffffffffffffffff0505555555507775
e66fffef577777744777777544444444572888820000000ff5ffff044fffff6fffffffffff12212121112211ffffffffffffffffffffffff0055555555507775
f566fffe57777774477777757777777757288a820505050fff55f846fffff6ffffffffffff12221212122111ffffffffffffffffffffffff0055555550007775
56666ffe577777744777777577777777572888820050500fffff516d6ffff6fffffffffff111122121122111ffffffffffffffffffffffff0000000000507775
e5666eef577777744777777577777777572822820505050fffff66d65ffff6fffffffffff122211211222111ffffffffffffffffffffffff0005555550507775
556fffff577777744777777555555555572822820050500fffff56656fff6fffffffffff122222211122111fffffffffffffffffffffffff0505005000507775
ffffffff5777777447777775ffffffff572822820505050ffffff556f666ffffffffffff122222212122111fffffffffffffffffffffffff0005005000507775
ffffffff5777777447777775ffffffff572822820050500ffffffff6ffffff6fffffffff11122212122111ffffffffffffffffffffffffff0005555550507775
ffffffff5777777447777775ffffffff572822820505050ffffffff6fff665dffffffff122111221122111ffffffffffffffffffffffffff0005005000007775
ffffffff5777777447777775ffffffff572828820050500ffffffff6ff6ff5fffffffff122222111222111ffffffffffffffffffffffffff0005005000507775
ffffffff5777755775577775ffffffff572888820505050fffffff6ff6ffffffffff11112222212122111fffffffffffffffffffffffffff0005555550507775
ffffffff5775577777755775ffffffff572888220000000fffff66fff6ffffffffff12221122121122111fffffffffffffffffffffffffff0500000000007775
ffffffff5557777777777555ffffffff57282274fffffffffff6fffff6fffffffff12222221111122111ffffffffffffffffffffffffffff00dddddddddd7775
ffffffff5555555555555555ffffffff57227774fffffffffff6ffff6ffffffffff11112222221122111ffffffffffffffffffffffffffff05dddddddddd7775
ffffffffffffffffffffffffffffffffffffffffffffffffffff6666fffffffffff11211122221222111ffffffffffffffffffffffffffff54dddddddddd7775
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1212121112222111fffffffffffffffffffffffffffff54dddddddddd7775
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff1111212121122111fffffffffffffffffffffffffffff44dddddddddd7775
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111121211111ffffffffffffffffffffffffffffff44dddddddddd7775
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff112121111ffffffffffffffffffffffffffffff45dddddddddd7775
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111211fffffffffffffffffffffffffffffff54dddddddddd7775
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff111fffffffffffffffffffffffffffffff54dddddddddd7775
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44dddddddddd7775
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d77777777d7775
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff45d76666657d7775
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54d76666665d7775
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54d76611161d7775
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d76655611d7775
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff44d77777711d7775
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff45d77777777d7775
ffffffffffffffffffff111111fffffffff111111fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff54d76666667d7775
ffffffffffffffffffff111111fffffffff111111fffffffffffffffffffffffffffffffffffffffffff677767776777677767776777677754d76666667d7775
ffffffffffff4444444444444444444444444444444444444fffffffffffffffffffffffffffffffffff677767776777677767776777677744d76666667d7775
fffffffffff54455555555555555555555555555555555544fffffffffffffffffffffffffffffffffff677767776777677767776777677744d76666667d7775
fffffffffff54544444444444444444444444444444444454fffffffffffffffffffffffffffffffffff666666666666666666666666666644d77777777d7775
fffffffffff54544444444444444444444444444444444454fffffffffffffffffffffffffffffffffff6ddddddddddddddddddddddddddddddddddddddd7775
fffffffffff54544444444444444344744444444444444454fffffffffffffffffffffffffffffffffff5ddddddddddddddddddddddddddddddddddddddd7775
fffffffffff54544444444444444437974444444444444454fffffffffffffffffffffffffffffffffff5ddddddddddddddddddddddddddddddddddddddd7775
fffffffffff5454444444444444473b744444444444444454fffffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
fffffffffff5454444444444444797b374444444444444454fffffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
ffffffff11f54544444444444444733797444444444444454f11ffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
ffffffff111545444444444444443b3b74444444444444454111ffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
ffffffff11d54544444444444444447344444444444444454d11ffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
ffffffff11d54544444444444444477644444444444444454d11ffffffffffffffffffffffffffffffff4ddddddddddddddddddddddddddddddddddddddd7775
ffffffff11d54544444444444444444444444444444444454d11ffffffffffffffffffffffffffffffff45444444444444444444444444444444444444577775
ffffffff11d54544444444444444444444444444444444454d11ffffffffffffffffffffffffffffffff54444444444444444444444444444444444445777775
fffffffff115454444444444444444444444444444444445411fffffffffffffffffffffffffffffffff54444444444444444444444444444444444457777775
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
ffffffff00000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffff0000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
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
01030304050303030303030405030e0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
11060714151313131313131415131e1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21161718191a00000000090808082e2fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21262728292a00000000090808083e3fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21363738393a00000000090808084e4fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21460048494a00000000090808085e5fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
210000000000000000006a6b6c6d6e6fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
210000000000000000007a7b7c7d7e7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21000000000000000000000000000022ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21000000000000000000000000000022ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21000000000000000051525354555622ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21000000000000000061626364656622ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
24250000000000000071727374757622ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
34350000000000000081828384858622ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
21000000000000000091929394959622ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
31232323232323232323232323232332ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1161718191affffffff09080808a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1262728292affffffff09080808a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1363738393affffffff09080808a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a146ff48494affffffff09080808a1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffff6a6b6c6da1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffff7a7b7c7da1a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffffffffffffffa1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffffffffffffffffa1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffff515253545556a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffff616263646566a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a125ffffffffffffff717273747576a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a135ffffffffffffff818283848586a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1ffffffffffffffff919293949596a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
a1a2a2a2a2a2a2a2a2a2a2a2a2a2a2a1ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
