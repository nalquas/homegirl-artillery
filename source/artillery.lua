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

DEBUG = true
TARGET_FPS = 60.0

font = text.loadfont("Victoria.8b.gif")
Screen = require("screen")

-- BEGIN MAIN FUNCTIONS
	function _init(args)
		sys.stepinterval(1000/TARGET_FPS)
		scrn = Screen:new("Artillery for Homegirl 1.5.5", 15, 8) --Mode15=640x360 or 640x480; 8 color bits
		scrn:colors(33, 32)
		
		t_last = 0
		
		if DEBUG then
			homegirl_lastFPSflush = 0
			homegirlfps_accum = 0
			homegirlfps = 0
		end
		
		-- Load assets
		spritesheet = image.load("spritesheet.gif")[1]
		image.usepalette(spritesheet)
		
		-- Set palette
		-- Indexes 0 to 31 are reserved for the spritesheet (which uses 32 colors)
		scrn:palette(32,0,0,0) -- black
		scrn:palette(33,15,15,15) -- white
		scrn:palette(34,15,0,0) -- red
		scrn:palette(35,0,15,0) -- green
		scrn:palette(36,0,0,15) -- blue
		scrn:palette(37,0,0,2) -- blue (very dark)
		
		-- Setup game
		SCREEN_SIZE_X, SCREEN_SIZE_Y = scrn:size()
		TERRAIN_SIZE_X = SCREEN_SIZE_X
		TERRAIN_SIZE_Y = SCREEN_SIZE_Y
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
		
		-- Remove all projectiles
		projectiles = {}
		projectiles[1] = projectile_new(players[1].x, terrain[round(players[1].x)], 0, 0)
		
		-- Game phases:
		-- setup - Players move their tanks and aim
		-- action - Shots are fired, projectiles move, players wait
		phase = "setup"
	end

	function _step(t)
		-- Calculate delta time
		if t_last == 0 then t_last = t-1 end
		dt_millis = t - t_last
		dt_seconds = dt_millis * 0.001
		t_last = t
		
		-- BEGIN GAMEPLAY SECTION
		if phase == "setup" then
			-- BEGIN INPUT SECTION
				for i=1,PLAYER_COUNT do
					-- BEGIN MOVEMENT
						local direction = 0
						local speed = 1.5
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
						players[i].x = clip(players[i].x + (direction * speed * (30 * dt_seconds)), 0, TERRAIN_SIZE_X-1)
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
		elseif phase == "action" then
			
		end
		-- END GAMEPLAY SECTION
		
		-- BEGIN RENDER SECTION
			if phase == "setup" then
				-- Clear screen
				gfx.bgcolor(37)
				gfx.cls()
				
				-- Render terrain
				--gfx.fgcolor(35)
				--for x=1,TERRAIN_SIZE_X-1 do
				--	gfx.line(x-1, terrain[x-1], x, terrain[x])
				--end
				for x=0,TERRAIN_SIZE_X-1 do
					image.tri(spritesheet, x,terrain[x], x,terrain[x], x,TERRAIN_SIZE_Y-1, 32+(x%32),terrain[x], 32+(x%32),terrain[x], 32+(x%32),TERRAIN_SIZE_Y)
				end
				
				-- Render players
				for i=1,PLAYER_COUNT do
					local x = players[i].x
					local y = terrain[round(players[i].x)]
					-- Vehicle
					gfx.fgcolor(33)
					circb(x, y, 4)
					-- HP display
					gfx.fgcolor(34)
					gfx.bar(x-5, y-8, 11, 1)
					gfx.fgcolor(35)
					gfx.bar(x-5, y-8, 11*(players[i].hp/100), 1)
				end
			
				-- Render overlay
				gfx.fgcolor(33)
				circb(players[1].x, terrain[round(players[1].x)], AIM_MAX_LENGTH) -- Aiming circle
				gfx.line(players[1].x, terrain[round(players[1].x)], players[1].x+players[1].target_x, terrain[round(players[1].x)]+players[1].target_y) -- Aiming line
				if DEBUG then
					text.draw_shadowed(round(players[1].target_x) .. ", " .. round(players[1].target_y), font, players[1].x-32, terrain[round(players[1].x)]+64) -- Aiming vector text
				end
				
				-- Render phase status as it will be in the next loop
				text.draw_shadowed("Phase: " .. phase, font, (SCREEN_SIZE_X / 2) - 64, 2)
			elseif phase == "action" then
				-- Render projectiles
				if #projectiles > 0 then
					gfx.fgcolor(34)
					for i=1,#projectiles do
						circ(projectiles[i].x, projectiles[i].y, 1)
					end
				end
			else
				text.draw("UNKNOWN PHASE, GAME IS STUCK", font, 2, SCREEN_SIZE_Y / 2 - 4)
			end
			
			-- Debug renders
			if DEBUG then
				gfx.fgcolor(33)
				
				-- Palette
				text.draw("Current palette", font, 0, 2)
				show_palette()
				
				-- Performance
				homegirlfps_accum = homegirlfps_accum + 1
				if t-homegirl_lastFPSflush>=1000 then
					homegirlfps = homegirlfps_accum
					homegirlfps_accum = 0
					homegirl_lastFPSflush = t
				end
				text.draw("t = " .. t .. "\ndt = " .. dt_millis .. "\nFPS(dt): " .. round(1000.0/dt_millis) .."\nFPS: " .. homegirlfps, font, SCREEN_SIZE_X - 100, 2)
			end
			
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

-- BEGIN PROJECTILE FUNCTIONS
	function projectile_new(x, y, move_x, move_y)
		x = clip(x, 0, TERRAIN_SIZE_X-1)
		y = clip(y, 0, TERRAIN_SIZE_Y-1)
		local projectile = {
			x = x,
			y = y,
			move_x = move_x,
			move_y = move_y
			}
		return projectile
	end
-- END PROJECTILE FUNCTIONS

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
	
	-- Punch a hole into the terrain (Use negative depth to make bumps instead)
	function terrain_hole(x_center, width, depth)
		local width_half = round(width/2.0)
		for x=round(x_center-width_half),round(x_center+width_half),1 do
			if x >= 0 and x <= TERRAIN_SIZE_X-1 then
				--local depth_factor = (width_half - math.abs(x-x_center)) / width_half
				local depth_factor = (width_half - (((x-x_center)^2)/width_half)) / width_half
				terrain[x] = clip(round(terrain[x] + (depth * depth_factor)), 0, TERRAIN_SIZE_Y)
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
	function show_palette()
		for i=0,255 do
			local r, g, b = gfx.palette(i)
			gfx.pixel(i,0,i)
		end
	end
	
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
	
	function text.draw_shadowed(txt, font, x, y)
		gfx.fgcolor(32)
		text.draw(txt, font, x+1, y+1)
		gfx.fgcolor(33)
		text.draw(txt, font, x, y)
	end
-- END GRAPHICS FUNCTIONS
