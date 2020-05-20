-- MIT License
--
-- Copyright (c) 2020 nalquas
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

font = text.loadfont("Victoria.8b.gif")
Screen = require("screen")

-- BEGIN MAIN FUNCTIONS
	function _init(args)
		sys.stepinterval(1000/60.0)
		scrn = Screen:new("Artillery for Homegirl 1.5.5", 31, 8) --Mode31=640x480; 8 color bits
		scrn:colors(1, 0)
		
		scrn:palette(0,0,0,0) -- black
		scrn:palette(1,15,15,15) -- white
		scrn:palette(2,15,0,0) -- red
		scrn:palette(3,0,15,0) -- green
		scrn:palette(4,0,0,15) -- blue
		
		-- Setup game
		TERRAIN_SIZE_X, TERRAIN_SIZE_Y = scrn:size()
		TERRAIN_HEIGHT_BASE = round((TERRAIN_SIZE_Y / 3) * 2)
		TERRAIN_HEIGHT_DEVIATION_MAX = round(TERRAIN_SIZE_Y / 5)
		
		PLAYER_COUNT = 2
		AIM_MAX_LENGTH = 96
		
		-- Init game
		init_game()
	end

	function init_game()
		-- Generate terrain
		terrain = {}
		terrain_generate()
		terrain_smooth(64)
		
		-- Generate players
		players = {}
		players_generate()
	end

	function _step(t)
		-- BEGIN INPUT SECTION
			for i=1,PLAYER_COUNT do
				-- BEGIN MOVEMENT
					local direction = 0
					local speed = 1.0
					if i==1 then
						local btn = input.gamepad(0)
						-- Player
						if (btn & 2) > 0 then
							-- Left
							direction = direction - 1
						end
						if (btn & 1) > 0 then
							-- Right
							direction = direction + 1
						end
					else
						-- AI
						-- TODO Implement AI
					end
					-- Calculate speed based on height difference
					local height_diff = math.abs((terrain[round(players[i].x)] or 0) - (terrain[round(players[i].x + direction)] or 0))
					if not (height_diff == 0) then
						speed = speed - clip(height_diff/2.5, 0.0, speed)
					end
					-- Commit movement
					players[i].x = clip(players[i].x + (direction * speed), 0, TERRAIN_SIZE_X-1)
				-- END MOVEMENT
				-- BEGIN AIMING
					if i==1 then
						-- Player
						-- Get relative position of mouse
						local mx, my, mbtn = input.mouse()
						players[1].target_x = mx - players[1].x
						players[1].target_y = my - terrain[round(players[1].x)]
					else
						-- AI
						-- TODO Implement AI
					end
					-- Restrict aiming to allowed vector length
					-- If the vector is longer than AIM_MAX_LENGTH, normalize the vector (length 1), then scale to AIM_MAX_LENGTH
					local length = math.sqrt(players[i].target_x^2 + players[i].target_y^2)
					if length > AIM_MAX_LENGTH then
						players[i].target_x = (players[i].target_x / length) * AIM_MAX_LENGTH
						players[i].target_y = (players[i].target_y / length) * AIM_MAX_LENGTH
					end
				-- END AIMING
			end
		-- END INPUT SECTION
		
		-- BEGIN LOGIC SECTION
			-- Player position sanity checks
			for i=1,PLAYER_COUNT do
				players[i].x = clip(players[i].x, 0, TERRAIN_SIZE_X-1)
			end
		-- END LOGIC SECTION
		
		-- BEGIN RENDER SECTION
			gfx.bgcolor(0)
			gfx.cls()
			
			-- Render terrain
			gfx.fgcolor(3)
			for x=1,TERRAIN_SIZE_X-1 do
				gfx.line(x-1, terrain[x-1], x, terrain[x])
			end
			
			-- Render players
			gfx.fgcolor(1)
			for i=1,PLAYER_COUNT do
				circb(players[i].x, terrain[round(players[i].x)], 4)
			end
			
			-- Render overlay
			gfx.fgcolor(1)
			circb(players[1].x, terrain[round(players[1].x)], AIM_MAX_LENGTH) -- Aiming circle
			gfx.line(players[1].x, terrain[round(players[1].x)], players[1].x+players[1].target_x, terrain[round(players[1].x)]+players[1].target_y) -- Aiming line
			
			scrn:step()
		-- END RENDER SECTION
		
		-- BEGIN HOTKEY SECTION
			-- Check if we have to exit
			if input.hotkey() == "\x1b" or input.hotkey() == "q" then
				print("Thank you for playing Artillery by Nalquas.")
				sys.exit(0)
			end
		-- END HOTKEY SECTION
	end
-- END MAIN FUNCTIONS

-- BEGIN PLAYER FUNCTIONS
	function players_generate()
		local step_x = round((TERRAIN_SIZE_X-1) / PLAYER_COUNT)
		for i=1,PLAYER_COUNT do
			local x = i * step_x - (step_x / 2)
			players[i] = player_new(x)
		end
	end
	
	function player_new(x)
		x = clip(x or 0, 0, TERRAIN_SIZE_X-1)
		local player = {
			x = x,
			hp = 100,
			target_x = 0,
			target_y = 0
			}
		return player
	end
-- END PLAYER FUNCTIONS

-- BEGIN TERRAIN FUNCTIONS
	-- Fill terrain with random heights
	function terrain_generate()
		for x=0,TERRAIN_SIZE_X-1 do
			terrain[x] = TERRAIN_HEIGHT_BASE + math.random(-TERRAIN_HEIGHT_DEVIATION_MAX, TERRAIN_HEIGHT_DEVIATION_MAX)
		end
	end

	-- Smooth terrain, averaging between every SMOOTHNESS points
	function terrain_smooth(smoothness)
		smoothness = smoothness or 1
		if smoothness > 1 then
			local prev_x = 0
			local prev_height = 0
			local next_height = 0
			for x=0,TERRAIN_SIZE_X-1 do
				if x % smoothness == 0 or x==TERRAIN_SIZE_X-1 then
					if x > 0 then prev_height = next_height end
					next_height = terrain[x]
					if x > 0 then
						for i=prev_x+1,x-1 do
							local distance_now = i-prev_x
							local distance_max = x-1-prev_x
							local factor_next = (distance_now*1.0) / distance_max
							local factor_prev = 1.0 - factor_next
							terrain[i] = round((prev_height * factor_prev) + (next_height * factor_next))
						end
					end
					prev_x = x
				end
			end
		end
	end
-- END TERRAIN FUNCTIONS

-- BEGIN HELPER FUNCTIONS
	function clip(x, min, max)
		if x<min then
			x=min
		elseif x>max then
			x=max
		end
		return x
	end

	function round(x)
		if x<0 then return math.ceil(x-0.5) end
		return math.floor(x+0.5)
	end
-- END HELPER FUNCTIONS

-- BEGIN GRAPHICS FUNCTIONS
	function circ(x, y, radius)
		-- Use triangles to approximate a circle
		local x_now = x+radius*math.cos(math.rad(350))
		local y_now = y+radius*math.sin(math.rad(350))
		for i=0,350,10 do --Only check every tenth degree to improve performance
			x_last = x_now
			y_last = y_now
			x_now = x+radius*math.cos(math.rad(i))
			y_now = y+radius*math.sin(math.rad(i))
			gfx.tri(x, y, x_last, y_last, x_now, y_now)
		end
	end

	function circb(x, y, radius)
		local x_last = x
		local y_last = y
		for i=0,360,10 do --Only check every tenth degree to improve performance
			x_now = x+radius*math.cos(math.rad(i))
			y_now = y+radius*math.sin(math.rad(i))
			if i>0 then gfx.line(x_last,y_last,x_now,y_now) end
			x_last = x_now
			y_last = y_now
		end
	end
-- END GRAPHICS FUNCTIONS
