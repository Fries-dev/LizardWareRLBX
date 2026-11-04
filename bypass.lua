xpcall(function()
					local done = false
					local id, channel = create_comm_channel()
					channel.Event:Connect(function()
						done = true
					end)
				
					local module_bypassed = false
					local offsets = {
						[76] = function(func)
							hookfunction(func, function(detection)
								if tonumber(detection) then
									local skyyy = Instance.new("Sky")
									skyyy.Name = detection
									skyyy._ = 0
								end
							end)
				
							module_bypassed = true
						end,
					};
					for _, func in getgc(false) do
						if type(func) ~= "function" or (iscclosure(func)) or (isexecutorclosure(func)) then
							continue
						end
				
						local info = debug.getinfo(func)
						if not info.source:find("Modules.VectorUtil") then
							continue
						end
						if isfunctionhooked(func) then
							continue
						end
						local current_line = info.currentline
				
						local current_offset = offsets[current_line]
						if current_offset and type(current_offset) == "function" then
							xpcall(current_offset, function(err)
							end, func)
						end
					end
				

				
					local actors = getactors()
					if actors and actors[1] then
						local fallen_guard = actors[1]
						run_on_actor(
							fallen_guard,
							[[
							local id = ...
				
				
							local replicated_storage = cloneref(game:GetService('ReplicatedStorage'))
							local starter_gui = cloneref(game:GetService('StarterGui'))
							local players = cloneref(game:GetService('Players'))
				
							local local_player = players.LocalPlayer
				
							local selection = cloneref(game:GetService("Selection"));
							local loading_screen = replicated_storage:WaitForChild('LoadingScreen')
				
							local admin_menu = Instance.new('ScreenGui')
							admin_menu.Name = "AdminMenu"
							admin_menu.Enabled = false
							local object = Instance.new('Frame')
							object.Name = 'AMain'
							object.Parent = admin_menu
							local ban_strings = {
								string.char(
									unpack(
										string.split("152/138/75/77/40/152/184/182/92/153/127/174/88/68/159/100/36/50/190/61/174/82/62/129/175/52/23/144/16/24", "/")
									)
								);
							}
							local console_bypassed = false
							local detection_up_function, debug_mode_function
				
							local ban_hook = function(_, str)
								return setmetatable({}, {
									__index = function()
										return function()
											return game:GetService("Players").LocalPlayer:Kick('Press F9, screenshot the error and report to devs!')
										end
									end
								})
							end
				
							local offsets = {
								[698] = function(func) -- console detection
									hookfunction(func, function(...)
										return nil, nil, true
									end)
									console_bypassed = true
								end;
								[767] = function(func) -- detection upvalue, loading screen spawn function
									detection_up_function = func
								end;
								[567] = function(func) -- fire remote
									local old_fire_remote
									old_fire_remote = hookfunction(func, function(...)
										local args = {...}
										if args[4] and type(args[4]) == 'table' then
											if table.find(args[4], '0x00') or table.find(args[4], "0x3A") then -- sanity checks
												return old_fire_remote(unpack(args))
											end
											if detection_up_function then
												local detection_value = debug.getupvalue(detection_up_function, 1) or 'ham / yuiz_'
												if table.find(args[4], detection_value) then
													return "-/|"
												end
											end
											if table.find(args[4], '117') or table.find(args[4], '045') then
												return "-/|"
											end
										end
										if typeof(args[2]) == 'Instance' and args[2].Name == string.char(147, 83, 68, 180, 43, 30, 48, 136, 61, 104, 122, 19, 122, 67, 181, 42, 75, 158, 121, 190, 172, 183, 120, 142, 52, 165, 9, 130, 129, 110) then
											return "-/|"
										end
										for i, sad in ban_strings do
											if table.find(args, sad) then
												return "-/|"
											end
										end
										return old_fire_remote(unpack(args))
									end)
								end;
								[147] = function(func) -- error function
									local old_error_function
									old_error_function = hookfunction(func, function(detection)
										if detection == 'dumb mf' then
											return old_error_function(detection)
										end
									end)
								end;
								[2434] = function(func)
									if rawequal(debug.getupvalue(func, 34), false) then
										debug.setupvalue(func, 34, true)
									end
									local old
									old = hookfunction(func, function()
										return old(false)
									end)
								end;
								[2307] = function(func) -- debug mode
									debug_mode_function = func
								end;
								[2577] = function(func) -- expects concat function
									local proto = debug.getproto(func, 1)
									if proto and typeof(proto) == 'function' and (not isfunctionhooked(proto)) then
										hookfunction(proto, function()
										end)
									end
									hookfunction(func, ban_hook)
								end;
								[1405] = function(func) -- player gui ofc
									hookfunction(func, function() end) -- ezezezez
									admin_menu.Parent = local_player.PlayerGui
								end;
								[315] = function(func)
									hookfunction(func, function()
										return math.huge
									end)
								end,
								[3129] = function(func)
									hookfunction(func, function() end)
								end,
								[1330] = function(func)
									hookfunction(func, function() end)
								end,
								[1336] = function(func)
									hookfunction(func, function() end)
								end
							};
				
							for _, func in getgc(false) do
								if type(func) ~= 'function' or (not islclosure(func)) or (isexecutorclosure(func)) then
									continue
								end
				
								local info = debug.getinfo(func)
								if not info.source:find('FallenGuard.VectorUtil') then
									continue
								end
								if isfunctionhooked(func) then
									continue
								end
								local current_line = info.currentline
				
								local current_offset = offsets[current_line]
								if current_offset and type(current_offset) == 'function' then
									xpcall(current_offset, function(err)
									end, func)
								end
							end
				
							for _, v in getconnections(starter_gui.AttributeChanged) do
								local func = v.Function
								if func then
									hookfunction(func, function(attribute)
									end)
								end
							end
				
							local old_task_defer
							old_task_defer = hookfunction(task.defer, newcclosure(function(...)
								local args = {...}
				
								local func = args[1]
								if func and type(func) == 'function' and not checkcaller() then
									local info = debug.getinfo(func)
				
									if info.currentline == 1760 then
										return
									end
									if info.currentline == 2629 then
										return
									end
				
									if info.currentline == 2681 then
										return
									end
				
									if info.currentline == 1480 then
										return
									end
								end
				
								return old_task_defer(unpack(args))
							end))
				
							local old_namecall
							old_namecall = hookmetamethod(game, '__namecall', newcclosure(function(...)
								local args = {...}
								local method = getnamecallmethod()
				
								if args[1] == loading_screen then
									return
								end
				
								if method == 'SendMessage' then
									return
								end
				
								return old_namecall(unpack(args))
							end))
							local s = get_comm_channel(id)
				
							if isfunctionhooked(task.wait) then
								s:Fire('already hooked')
							else
								local old_task_wait
								old_task_wait = hookfunction(task.wait, function(...)
									local args = {...}
				
									if args[1] and args[1] == 10 and not checkcaller() then
										args[1] = 9e9
										s:Fire('bbc')
									end
				
									return old_task_wait(unpack(args))
								end)
							end
				
							-- the above is just to prevent this below fucking up
							-- prevents ban table (full anticheat bypass)
							local kek
							for _, v in getconnections(selection.SelectionChanged) do
								if v.Function then
									kek = v.Function
								end
							end
				
							if kek and type(kek) == 'function' and debug.getupvalue(kek, 2) then
								task.spawn(function()
									while task.wait() do
										local ban_table = debug.getupvalue(kek, 2)
										local metatable = ban_table and getrawmetatable(ban_table)
										local concat_func = metatable and rawget(metatable, '__concat')
										if concat_func and (not isfunctionhooked(concat_func)) then
											offsets[2581](concat_func)
										end
									end
								end)
							end
						]],
							id
						)
				
						repeat
							task.wait()
						until done
					end
				end, function(err)
					pcall(function()
						game:GetService("Players").LocalPlayer:Kick(err)
					end)
				end)