-- BBC Radio applet - plays FlashAAC/MP3 and WMA versions of BBC Radio Live and Listen Again streams
--
-- Allows Squeezeplay players connected to MySqueezebox.com to play BBC Radio streams without requring
-- a local server and server plugin
--
-- Copyright (c) 2010 - 2012 Adrian Smith, (Triode) triode1@btinternet.com
--
-- Released under the BSD license for use with the Logitech Squeezeplay application

local next, pairs, ipairs, type, package, string, tostring, pcall, math, table = next, pairs, ipairs, type, package, string, tostring, pcall, math, table

local oo               = require("loop.simple")
local debug            = require("jive.utils.debug")

local mime             = require("mime")
local lxp              = require("lxp")
local lom              = require("lxp.lom")
local os               = require("os")

local Applet           = require("jive.Applet")

local RequestHttp      = require("jive.net.RequestHttp")
local SocketHttp       = require("jive.net.SocketHttp")
local SocketTcp        = require("jive.net.SocketTcp")

local Framework        = require("jive.ui.Framework")
local Window           = require("jive.ui.Window")
local Surface          = require("jive.ui.Surface")
local SimpleMenu       = require("jive.ui.SimpleMenu")
local Icon             = require("jive.ui.Icon")
local Choice           = require("jive.ui.Choice")
local Task             = require("jive.ui.Task")
local Timer            = require("jive.ui.Timer")
local Player           = require("jive.slim.Player")

local System           = require("jive.System")
local ArtworkCache     = require("jive.slim.ArtworkCache")

local socketurl        = require("socket.url")
local dns              = require("jive.net.DNS")

local hasDecode, decode= pcall(require, "squeezeplay.decode")

local appletManager    = appletManager
local jiveMain         = jiveMain
local jnt              = jnt

local FRAMERATE        = jive.ui.FRAME_RATE

local JIVE_VERSION     = jive.JIVE_VERSION

module(..., Framework.constants)
oo.class(_M, Applet)

local live_prefix   = "http://www.bbc.co.uk/mediaselector/4/mtis/stream/"
local livepls_templ = "http://www.bbc.co.uk/radio/listen/live/%s_aaclca.pls"
local la_prefix     = "http://www.bbc.co.uk/radio/aod/availability/"
local img1_prefix   = "http://www.bbc.co.uk/radio/imda/logos/"
local img2_prefix   = "http://www.bbc.co.uk/iplayer/img/"
local img_templ     = "http://node1.bbcimg.co.uk/iplayer/images/episode/%s_512_288.jpg"
local lt_prefix     = "pubsub.livetext."

local live = {
	{ text = "BBC Radio 1",       id = "bbc_radio_one",       pls = "r1",  img1 = "radio1_logomobile1-1.png",   
	  lt = "radio1", vis = "fm/ce1/c201/09880" },
	{ text = "BBC Radio 1 Xtra",  id = "bbc_1xtra",           pls = "r1x", img1 = "radio1x_logomobile1-1.png",  
	  lt = "1xtra",  vis = "dab/ce1/ce15/c22a/0"  },
	{ text = "BBC Radio 2",       id = "bbc_radio_two",       pls = "r2",  img1 = "radio2_logomobile1-1.png",   lt = "radio2" },
	{ text = "BBC Radio 3",       id = "bbc_radio_three",     pls = "r3",  img1 = "radio3_logomobile1-1.png",   lt = "radio3" },
	{ text = "BBC Radio 4 FM",    id = "bbc_radio_fourfm",    pls = "r4",  img1 = "radio4_logomobile1-1.png",   lt = "radio4" },
	{ text = "BBC Radio 4 LW",    id = "bbc_radio_fourlw",    pls = "r4lw",img1 = "radio4_logomobile1-1.png"                  },
	{ text = "BBC Radio 4 Extra", id = "bbc_radio_four_extra",pls = "r4x", img1 = "radio4x_logomobile1-1.png",  lt = "bbc7"   },
	{ text = "BBC Radio 5 Live",  id = "bbc_radio_five_live", pls = "r5l", img1 = "radio5l_logomobile1-1.png",  lt = "radio5live" },
	{ text = "BBC Radio 5 Sports",id = "bbc_radio_five_live_sports_extra", pls = "r5lsp", img1 = "radio5lspx_logomobile1-1.png", lt = "sportsextra" },
	{ text = "BBC Radio 6 Music", id = "bbc_6music",          pls = "r6",  img1 = "radio6_logomobile1-1.png",   lt = "6music" },
	{ text = "BBC Asian Network", id = "bbc_asian_network",   pls = "ran", img1 = "radioan_logomobile1-1.png",  lt = "asiannetwork" },
	{ text = "BBC World Service", id = "bbc_world_service",   img2 = "radio/bbc_world_service.gif",             lt = "worldservice" },
	{ text = "BBC Radio Scotland",id = "bbc_radio_scotland_fm",img2 = "radio/bbc_radio_scotland_1.gif",         lt = "radioscotland" },
	{ text = "BBC Radio nan Gaidheal", id = "bbc_radio_nan_gaidheal", img2 = "radio/bbc_radio_nan_gaidheal.gif"       },
	{ text = "BBC Radio Ulster",  id = "bbc_radio_ulster",    img2 = "radio/bbc_radio_ulster.gif"                     },
	{ text = "BBC Radio Foyle",   id = "bbc_radio_foyle",     img2 = "station_logos/bbc_radio_foyle.png"              },
	{ text = "BBC Radio Wales",   id = "bbc_radio_wales_fm",  img2 = "radio/bbc_radio_wales.gif"                      },
	{ text = "BBC Radio Cymru",   id = "bbc_radio_cymru",     img2 = "radio/bbc_radio_cymru.gif"                      },
}

local listenagain = {
	{ text = "BBC Radio 1",       id = "radio1.xml",          img1 = "radio1_logomobile1-1.png"    },
	{ text = "BBC Radio 1 Xtra",  id = "1xtra.xml",           img1 = "radio1x_logomobile1-1.png"   },
	{ text = "BBC Radio 2",       id = "radio2.xml",          img1 = "radio2_logomobile1-1.png"    },
	{ text = "BBC Radio 3",       id = "radio3.xml",          img1 = "radio3_logomobile1-1.png"    },
	{ text = "BBC Radio 4 FM",    id = "radio4.xml",          img1 = "radio4_logomobile1-1.png", service = "bbc_radio_fourfm" },
	{ text = "BBC Radio 4 LW",    id = "radio4.xml",          img1 = "radio4_logomobile1-1.png", service = "bbc_radio_fourlw" },
	{ text = "BBC Radio 4 Extra", id = "radio4extra.xml",     img1 = "radio4x_logomobile1-1.png"   },
	{ text = "BBC Radio 5 Live",  id = "fivelive.xml",        img1 = "radio5l_logomobile1-1.png"   },
	{ text = "BBC Radio 6 Music", id = "6music.xml",          img1 = "radio6_logomobile1-1.png"    },
	{ text = "BBC Asian Network", id = "asiannetwork.xml",    img1 = "radioan_logomobile1-1.png"   },
	{ text = "BBC World Service", id = "worldservice.xml",    img2 = "radio/bbc_world_service.gif" },
	{ text = "BBC Radio Scotland",id = "radioscotland.xml",   img2 = "radio/bbc_radio_scotland_1.gif" },
	{ text = "BBC Radio nan Gaidheal", id = "alba.xml",       img2 = "radio/bbc_radio_nan_gaidheal.gif" },
	{ text = "BBC Radio Ulster",  id = "radioulster.xml",     img2 = "radio/bbc_radio_ulster.gif"  },
	{ text = "BBC Radio Wales",   id = "radiowales.xml",      img2 = "radio/bbc_radio_wales.gif"   },
	{ text = "BBC Radio Cymru",   id = "radiocymru.xml",      img2 = "radio/bbc_radio_cymru.gif"   },
}

local localradio = {
	{ text = "BBC Berkshire",     id = "bbc_radio_berkshire" },
	{ text = "BBC Bristol",       id = "bbc_radio_bristol"   },
	{ text = "BBC Cambridgeshire",id = "bbc_radio_cambridge" },
	{ text = "BBC Cornwall",      id = "bbc_radio_cornwall"  },
	{ text = "BBC Coventry & Warwickshire", id = "bbc_radio_coventry_warwickshire" },
	{ text = "BBC Cumbria",       id = "bbc_radio_cumbria"   },
	{ text = "BBC Derby",         id = "bbc_radio_derby"     },
	{ text = "BBC Devon",         id = "bbc_radio_devon"     },
	{ text = "BBC Essex",         id = "bbc_radio_essex"     },
	{ text = "BBC Gloucestershire", id = "bbc_radio_gloucestershire" },
	{ text = "BBC Guernsey",      id = "bbc_radio_guernsey"  },
	{ text = "BBC Hereford & Worcester", id = "bbc_radio_hereford_worcester" },
	{ text = "BBC Humberside",    id = "bbc_radio_humberside" },
	{ text = "BBC Jersey",        id = "bbc_radio_jersey"    },
	{ text = "BBC Kent",          id = "bbc_radio_kent"      },
	{ text = "BBC Lancashire",    id = "bbc_radio_lancashire"},
	{ text = "BBC Leeds",         id = "bbc_radio_leeds"     },
	{ text = "BBC Leicester",     id = "bbc_radio_leicester" },
	{ text = "BBC Lincolnshire",  id = "bbc_radio_lincolnshire" },
	{ text = "BBC London",        id = "bbc_london"          },
	{ text = "BBC Manchester",    id = "bbc_radio_manchester"},
	{ text = "BBC Merseyside",    id = "bbc_radio_merseyside"},
	{ text = "BBC Newcastle",     id = "bbc_radio_newcastle" },
	{ text = "BBC Norfolk",       id = "bbc_radio_norfolk"   },
	{ text = "BBC Northampton",   id = "bbc_radio_northampton" },
	{ text = "BBC Nottingham",    id = "bbc_radio_nottingham"},
	{ text = "BBC Oxford",        id = "bbc_radio_oxford"    },
	{ text = "BBC Sheffield",     id = "bbc_radio_sheffield" },
	{ text = "BBC Shropshire",    id = "bbc_radio_shropshire"},
	{ text = "BBC Solent",        id = "bbc_radio_solent"    },
	{ text = "BBC Somerset",      id = "bbc_radio_somerset_sound" },
	{ text = "BBC Stoke",         id = "bbc_radio_stoke"     },
	{ text = "BBC Suffolk",       id = "bbc_radio_suffolk"   },
	{ text = "BBC Surrey",        id = "bbc_radio_surrey"    },
	{ text = "BBC Sussex",        id = "bbc_radio_sussex"    },
	{ text = "BBC Tees",          id = "bbc_tees"            },
	{ text = "BBC Three Counties",id = "bbc_three_counties_radio" },
	{ text = "BBC Wiltshire",     id = "bbc_radio_wiltshire" },
	{ text = "BBC WM",            id = "bbc_wm"              },
	{ text = "BBC York",          id = "bbc_radio_york"      },
}

local specialevents = { text = "Special Events", url = "http://xdevtriodeplugins.xpdev-hosted.com/specialevents.opml" }

local tzoffset

function setTzOffset()
	local t1 = os.date("*t")
	local t2 = os.date("!*t")
	t1.isdst = false
	tzoffset = os.time(t1) - os.time(t2)
	log:debug("tzoffset: ", tzoffset)
end

local function str2timeZ(timestr)
	-- return time since epoch for timestr, nb assumes constant tzoffset which is inaccurate across dst changes
	local year, mon, mday, hour, min, sec = string.match(timestr, "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z")
	return os.time({ hour = hour, min = min, sec = sec, year = year, month = mon, day = mday }) + tzoffset
end


local _menuAction

function menu(self, menuItem)
	local window = Window("text_list", menuItem.text)
	local menu   = SimpleMenu("menu")

	local player = Player:getLocalPlayer()
	self.server = player:getSlimServer()

	-- set the tzoffset on each use in case of dst changes
	setTzOffset()

	-- listen live menus
	menu:addItem({
		text = "Listen Live",
		sound = "WINDOWSHOW",
		callback = function(_, menuItem)
			local window = Window("text_list", menuItem.text)
			local menu   = SimpleMenu("menu")
			local usepls = self:getSettings()["streamtype"] == "mp3aac" or self:getSettings()["streamtype"] == "high"
			local sshow  = self:getSettings()["livedisp"] == "slideshow"
			local livet  = self:getSettings()["livedisp"] == "livetxt"
			for _, entry in pairs(live) do
				local img = entry.img1 and (img1_prefix .. entry.img1) or (entry.img2 and (img2_prefix .. entry.img2))
				local icon
				if self.server and img then
					icon = Icon("icon")
					self.server:fetchArtwork(img, icon, jiveMain:getSkinParam('THUMB_SIZE'), 'png')
				end
				local playable = { title = entry.text, img = img, 
								   livetxt = (entry.lt and not entry.vis and ( lt_prefix .. entry.lt )) or nil,
								   radiovis = entry.vis,
								   parser = entry.parser, self = self }
				if entry.pls and usepls then
					playable.pls = string.format(livepls_templ, entry.pls)
				else
					playable.url = entry.url or (live_prefix .. entry.id)
				end
				if sshow and entry.vis then
					playable.radiovis = entry.vis
				elseif (show or livet) and entry.lt then
					playable.livetxt = lt_previx .. entry.lt
				end
				menu:addItem({
					text = entry.text,
					icon = icon,
					isPlayableItem = playable,
					style = 'item_choice',
					callback = _menuAction,
					cmCallback = _menuAction,
				})
			end
			for _, entry in pairs(localradio) do
				menu:addItem({
					text = entry.text,
					isPlayableItem = { url = live_prefix .. entry.id, title = entry.text, self = self },
					style = 'item_choice',
					callback = _menuAction,
					cmCallback = _menuAction,
				})
			end
			window:addWidget(menu)
			self:tieAndShowWindow(window)
		end
	})

	-- listen again menus - fetch the xml and parse into a menu as it is received
	for _, entry in pairs(listenagain) do
		local img = entry.img1 and (img1_prefix .. entry.img1) or (entry.img2 and (img2_prefix .. entry.img2))
		local icon
		if self.server and img then
			icon = Icon("icon")
			self.server:fetchArtwork(img, icon, jiveMain:getSkinParam('THUMB_SIZE'), 'png')
		end
		menu:addItem({
			text = entry.text,
			icon = icon,
			sound = "WINDOWSHOW",
			callback = function(_, menuItem)
				local url = la_prefix .. entry.id
				log:info("fetching: ", url)
				local req = RequestHttp(self:_sinkXMLParser(menu, menuItem.text, entry.service), 'GET', url, { stream = true })
				local uri = req:getURI()
				local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
				http:fetch(req)
			end,
		})
	end
	for _, entry in pairs(localradio) do
		menu:addItem({
			text = entry.text,
			sound = "WINDOWSHOW",
			callback = function(_, menuItem)
				local url = la_prefix .. entry.id .. ".xml"
				log:info("fetching: ", url)
				local req = RequestHttp(self:_sinkXMLParser(menu, menuItem.text, entry.service), 'GET', url, { stream = true })
				local uri = req:getURI()
				local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
				http:fetch(req)
			end,
		})
	end

	-- special events menu from remote opml feed
	menu:addItem({
		text = specialevents.text,
		sound = "WINDOWSHOW",
		callback = function(_, menuItem)
			log:info("fetching: ", specialevents.url)
			local req = RequestHttp(self:_sinkOPMLParser(menu, menuItem.text), 'GET', specialevents.url, { stream = true })
			local uri = req:getURI()
			local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
			http:fetch(req)
		end
	})

	-- preference setting for streamtype
	local mapto   = { "high", "wma", "mp3aac" }
	local mapfrom = { high = 1, wma = 2, mp3aac = 3 }
	menu:addItem({
		text  = "Stream:",
		style = 'item_choice',
		check = Choice("choice", 
					   { "Highest Bitrate", "WMA", "AAC/MP3" },
					   function(object, isSelected)
						   self:getSettings()["streamtype"] = mapto[isSelected]
						   self:storeSettings()
					   end,
					   mapfrom[self:getSettings()["streamtype"]]
		)
	})

	-- preference setting for live display (live text or slide show)
	local mapto   = { "none", "livetxt", "slideshow" }
	local mapfrom = { none = 1, livetxt = 2, slideshow = 3 }
	menu:addItem({
		text  = "Live Display:",
		style = 'item_choice',
		check = Choice("choice", 
					   { "None", "Live Text", "Slide Show" },
					   function(object, isSelected)
						   self:getSettings()["livedisp"] = mapto[isSelected]
						   self:storeSettings()
					   end,
					   mapfrom[self:getSettings()["livedisp"]]
		)
	})

	window:addWidget(menu)
	self:tieAndShowWindow(window)
end


function _sinkXMLParser(self, prevmenu, title, service)
	local window = Window("text_list", title)
	local menu   = SimpleMenu("menu")
	menu:setComparator(SimpleMenu.itemComparatorWeightAlpha)
	window:addWidget(menu)
	prevmenu:lock()

	local daymenus = {}
	local brandmenus = {}
	local entry
	local capture
	local now = os.time()
	local today = os.date("*t").day
	local pos = 9

	local p = lxp.new({
		StartElement = function (parser, name, attr)
			capture = nil			   
			if name == "entry" then
				entry = {}
			elseif name == "title" or name == "pid" or name == "service" or name == "title" or name == "synopsis" or name == "link" then
				capture = name
			elseif name == "parent" then
				capture = string.lower(attr.type)
			elseif name == "broadcast" then
				entry.bcast = attr["start"]
				entry.dur   = attr["duration"]
			elseif name == "availability" then
				entry.astart = attr["start"]
				entry.aend   = attr["end"]
			end
		end,
		CharacterData = function (parser, string)
			if entry and capture and string.match(string, "%w") then
				entry[capture] = (entry[capture] or "") .. string
			end
		end,
		EndElement = function (parser, name)
			if name == "entry" then
				if service and service ~= entry.service then
					--log:debug("wrong service (", entry.service, " != ", service, ")")
					return
				end
				if  str2timeZ(entry.astart) > now or str2timeZ(entry.aend) < now then
					--log:debug("not available (", entry.astart, " - ", entry.aend, ")")
					return
				end

				local title   = string.match(entry.title, "(.-), %d+%/%d+%/%d") or entry.title
				local bcast   = str2timeZ(entry.bcast)
				local date    = os.date("*t", bcast)
				local daystr  = os.date("%A", bcast)
				local timestr = string.format("%02d:%02d ", date.hour, date.min)

				-- shared table for menus
				local playt = { url = entry.link, title = title, desc = entry.synopsis, 
								img = string.format(img_templ, entry.pid), dur = entry.dur, self = self }

				-- by day menus
				local daymenu
				if daymenus[date.day] then
					daymenu = daymenus[date.day]
				else
					daymenu = {}
					daymenus[date.day] = daymenu

					menu:addItem({
						text = date.day == today and "Today" or daystr,
						sound = "WINDOWSHOW",
						weight = pos,
						callback = function(_, menuItem)
							local window = Window("text_list", menuItem.text)
							local menu   = SimpleMenu("menu")
							for _, entry in ipairs(daymenu) do
								menu:addItem({
									text = entry.timestr .. entry.t.title,
									isPlayableItem = entry.t,
									style = 'item_choice',
									callback = _menuAction,
									cmCallback = _menuAction,
								})
							end
							window:addWidget(menu)
							self:tieAndShowWindow(window)
						end
					})
					pos = pos - 1
				end
				daymenu[#daymenu + 1] = { t = playt, timestr = timestr }

				-- by brand menus
				local brand = entry.brand or entry.series or entry.title
				local brandmenu
				if brand == nil then
					return
				elseif brandmenus[brand] then
					brandmenu = brandmenus[brand]
				else
					brandmenu = {}
					brandmenus[brand] = brandmenu

					menu:addItem({
						text = brand,
						sound = "WINDOWSHOW",
						weight = 10,
						callback = function(_, menuItem)
							local window = Window("text_list", menuItem.text)
							local menu   = SimpleMenu("menu")
							for _, entry in ipairs(brandmenu) do
								menu:addItem({
									text = entry.text,
									isPlayableItem = entry.t,
									style = 'item_choice',
									callback = _menuAction,
									cmCallback = _menuAction,
								})
							end
							window:addWidget(menu)
							self:tieAndShowWindow(window)
						end
					})
				end
				brandmenu[#brandmenu + 1] = { t = playt, text = timestr .. daystr }
			end
		end
	})

	return function(chunk)
		if chunk == nil then
			p:parse()
			p:close()
			prevmenu:unlock()
			self:tieAndShowWindow(window)
			return
		else
			p:parse(chunk)
		end
	end
end


function _sinkOPMLParser(self, prevmenu, title)
	local window = Window("text_list", title)
	local menu   = SimpleMenu("menu")
	window:addWidget(menu)
	prevmenu:lock()

	local menus = { menu }
	local leaf

	local p = lxp.new({
		StartElement = function (parser, name, attr)
			if name == 'outline' and attr.text then
				if attr.URL and attr.type and (attr.type == 'audio' or attr.type == 'playlist') then
					-- playable item, possibly with parser
					local playable
					if attr.URL and attr.parser == nil then
						playable = { rawurl = attr.URL, title = attr.text, self = self }
					else
						playable = { url = attr.URL, title = attr.text, self = self, parser = attr.parser }
					end
					menus[#menus]:addItem({
						text = attr.text,
						isPlayableItem = playable,
						style = 'item_choice',
						callback = _menuAction,
						cmCallback = _menuAction,									
					})
					leaf = true
				elseif attr.URL then
					log:warn("no support for opml links")
				else
					-- add a menu level for the outline
					local mywindow = Window("text_list", attr.text)
					local mymenu   = SimpleMenu("menu")
					mywindow:addWidget(mymenu)
					menus[#menus]:addItem({
						text = attr.text,
						sound = "WINDOWSHOW",
						weight = 10,
						callback = function(_, menuItem)
							self:tieAndShowWindow(mywindow)
						end
					})
					menus[#menus+1] = mymenu
					leaf = false
				end
			end
		end,
		EndElement = function (parser, name)
			if name == 'outline' then
				if not leaf then
					-- pop back menu level
					menus[#menus] = nil
				end
				leaf = false
			end
		end
	})

	return function(chunk)
		if chunk == nil then
			p:parse()
			p:close()
			prevmenu:unlock()
			self:tieAndShowWindow(window)
			return
		else
			p:parse(chunk)
		end
	end
end


function _playlistParse(url, event, stream)
	stream.parser = nil
	log:info("fetching: ", url)
	local req = RequestHttp(
		function(chunk)
			if chunk then
				local xml = lom.parse(chunk)
				local connection
				for _, entry in ipairs(xml) do
					if type(entry) == 'table' and entry.tag then
						if entry.tag == 'summary' then
							stream.desc = entry[1]
						elseif entry.tag == 'link' and entry.attr.type and string.match(entry.attr.type, "image") then
							stream.img = stream.img or entry.attr.href
						elseif entry.tag == 'item' then
							for _, m in ipairs(entry) do
								if type(m) == 'table' and m.tag == 'media' then
									for _, c in ipairs(m) do
										if type(c) == 'table' and c.tag == 'connection' then
											connection = c.attr
											break
										end
									end
								end
							end
						end
					end
				end
				if connection then
					stream.url = "http://www.bbc.co.uk/mediaselector/4/gtis/?server=" .. connection.server ..
						"&identifier=" .. connection.identifier
					if connection.application then
						stream.url = stream.url .. "&application=" .. connection.application
					end
					_menuAction(event, item, stream)
				end
			end
		end
		, 'GET', url)
	local uri = req:getURI()
	local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
	http:fetch(req)
end


_menuAction = function(event, item, stream)
	local action = event:getType() == ACTION and event:getAction() or event:getType() == EVENT_ACTION and "play"
	local stream = stream or item.isPlayableItem

	if not stream or not stream.self then
		log:warn("bad event - no stream info")
		return
	end
	if action ~= "play" and action ~= "add" then
		log:warn("bad action - ", action)
		return
	end

	if stream.parser and string.match(stream.parser, "BBCPlaylistParser") then
		_playlistParse(stream.url, event, stream)
		return
	end

	local self = stream.self
	local player = Player:getLocalPlayer()
	local server = player and player:getSlimServer()
	local url

	if stream.rawurl then
		url = stream.rawurl
	elseif stream.pls then
		url = "spdr://bbcplsparser?url=" .. mime.b64(stream.pls)
	else
		url = "spdr://bbcmsparser?url=" .. mime.b64(stream.url)
	end
	if stream.img then
		url = url .. "&icon=" .. mime.b64(stream.img)
	end
	if stream.desc then
		url = url .. "&artist=" .. mime.b64(stream.desc)
	end
	if stream.dur then
		url = url .. "&dur=" .. mime.b64(stream.dur)
	end
	if stream.livetxt then
		url = url .. "&livetxt=" .. mime.b64(stream.livetxt)
	end
	if stream.radiovis then
		url = url .. "&radiovis=" .. mime.b64(stream.radiovis)
	end

	log:info("sending ", action, " request to ", server, " player ", player, " url ", url)

	server:userRequest(nil,	player:getId(), { "playlist", action, url, stream.title })

	if action == "play" then
		appletManager:callService('goNowPlaying', Window.transitionPushLeft, false)
	end
end


------------------------------------------------------
-- code below is the protocol handler for playing streams via spdr:// urls

-- protocol handler registered in meta to play bbcmsparser and bbcplsparser
function bbcparser(self, type, playback, data, decode)
	local cmdstr = playback.header .. "&"			   
	local url = string.match(cmdstr, "url%=(.-)%&")
	url = mime.unb64("", url)
	log:info("url: ", url)

	data.start = string.match(cmdstr, "start%=(.-)%&")
	if data.start then
		data.start = mime.unb64("", data.start)
		log:info("start: ", data.start)
	end

	data.livetxt = string.match(cmdstr, "livetxt%=(.-)%&")
	if data.livetxt then
		data.livetxt = mime.unb64("", data.livetxt)
		log:info("livetxt: ", data.livetxt)
	end

	data.radiovis = string.match(cmdstr, "radiovis%=(.-)%&")
	if data.radiovis then
		data.radiovis = mime.unb64("", data.radiovis)
		log:info("radiovis: ", data.radiovis)
	end

	data.spdrver = string.match(cmdstr,"ver%=(.-)%&")
	if data.spdrver then
		log:info("spdrver: ", data.spdrver)
	end
	
	if type == 'ms' then
		local req = RequestHttp(_sinkMSParser(self, playback, data, decode), 'GET', url)
		local uri = req:getURI()
		local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
		http:fetch(req)
	elseif type == 'pls' then
		local req = RequestHttp(_sinkPLSParser(self, playback, data, decode), 'GET', url)
		local uri = req:getURI()
		local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
		http:fetch(req)
	else
		log:warn("bad parser type: ", type)
	end
end


-- sink to parse mediaselector xml
function _sinkMSParser(self, playback, data, decode)
	local streams = {}
	local media, streammode, streamtag
	local p = lxp.new({
		StartElement = function (parser, name, attr)
			if name == "media" and attr.type then
				local type = ((attr.type ==  "audio/wma" or attr.type == "audio/x-ms-asf") and "wma") or
				(attr.type == "audio/mp4" and "aac") or (attr.type == "audio/mpeg" and "mp3")
				media = { bitrate = attr.bitrate, encoding = attr.encoding, service = attr.service, type = type }
			elseif name == "connection" and media then
				local connection = {}
				for key, val in pairs(media) do
					connection[key] = val
				end
				for _, key in ipairs(attr) do
					connection[key] = attr[key]
				end
				streams[#streams+1] = connection
			elseif name == "stream" then
				streammode = true
				streams[1] = { service = "stream", protocol = "rtmp", type = "acc" }
			elseif streammode then
				streamtag = name
			end
		end,
		CharacterData = function (parser, text)
			streams[1][streamtag] = (streams[1][streamtag] or "") .. text
		end,
	})

	return function(content)
		if content == nil then
			p:parse()
			p:close()
			-- sort streams by bitrate and preference
			local type = self:getSettings()["streamtype"]
			table.sort(streams, 
				function(a, b)
					local bitrateA = a.bitrate or 0
					local bitrateB = b.bitrate or 0
					if type == "high" then
						-- highest bitrates with aac > wma > mp3 for tied bitrates
						if bitrateA != bitrateB then
							return bitrateA < bitrateB
						else
							return a.type == "aac" or (a.type == "wma" and b.type == "mp3")
						end
					elseif type == "wma" then
						-- wma first, otherwise by bitrate
						if a.type != b.type then
							return a.type == "wma"
						else
							return bitrateA < bitrateB
						end
					else
						-- aac > mp3 first, otherwise by bitrate
						if a.type != b.type then
							return a.type == "aac" or (a.type == "mp3" and b.type != "aac")
						else
							return bitrateA < bitrateB
						end
					end
				end
			)
			
			local found
			for _, entry in ipairs(streams) do
				if entry.protocol == "rtmp" then
					log:info("rtmp: ", entry["service"])
					self:_playstreamRTMP(playback, data, decode, entry)
					found = true
					break
				elseif entry.protocol == "http" and entry.type == "wma" and entry.href then
					log:info("asx: ", entry.href)
					local req = RequestHttp(_sinkASXParser(self, playback, data, decode, entry.bitrate), 'GET', entry.href, {})
					local uri = req:getURI()
					local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
					http:fetch(req)
					found = true
					break
				end
			end
			if not found then
				log:info("could not find playable stream")
			end
			return
		else
			p:parse(content)
		end
	end
end


-- sink to parse mediaselector xml
function _sinkPLSParser(self, playback, data, decode, bitrate)
	local streams = {}
	return function(content)
		if content == nil then
			if streams[1] then
				-- assume stream in pls file is aac for the moment
				self:_playstreamAAC(playback, data, decode, streams[1], bitrate)
			else
				log:warn("no stream found")
			end
			return
		else
			local stream = string.match(content, "File%d%=(.-)%c")
			streams[#streams+1] = stream
		end
	end
end


-- sink to parse asx - currently extracts first stream
function _sinkASXParser(self, playback, data, decode, bitrate)
	local streams = {}
	local capture
	local ver

	-- ASX 3 parser
	local p3 = lxp.new({
		StartElement = function (parser, name, attr)
			if name == "ref" and attr.href then
				streams[#streams+1] = attr.href
			end
		end,
	})

	-- ASX 2 parser
	local p2= function(chunk)
				  for line in string.gmatch(chunk, "(.-)%c") do
					  for id, url in string.gmatch(line, "Ref(%d+)=(.*)") do
						  streams[#streams+1] = url
					  end
				  end
			  end

	return function(content)
		if content == nil then
			if ver == 3 then
				p3:parse()
				p3:close()
			end
			if streams[1] then
				self:_playstreamWMA(playback, data, decode, streams[1], bitrate)
			else
				log:info("no media url found")
			end
			return
		else
			if ver == nil then
				if string.match(content:upper(), "^<ASX") then
					log:info("parsing asx ver 3")
					ver = 3
				elseif string.match(content:upper(), "^%[REFERENCE%]") then
					log:info("parsing asx ver 2")
					ver = 2
				end
			end
			if ver == 3 then
				p3:parse(content)
			elseif ver == 2 then
				p2(content)
			end
		end
	end
end


-- WMA GUID creation
function _makeGUID()
	local guid = ""
	for d = 0, 31 do
		if d == 8 or d == 12 or d == 16 or d == 20 then
			guid = guid .. "-"
		end
		guid = guid .. string.format("%x", math.random(0, 15))
	end
	return guid
end

local GUID = _makeGUID()


-- play a WMA stream
function _playstreamWMA(self, playback, data, decode, stream, bitrate)
	log:info("playing: ", stream)

	-- following is taken from SBS...
	local context, streamtime = 2, 0
	if data.start then
		context = 4
		streamtime = data.start * 1000
	end

	local url = socketurl.parse(stream)
	playback.header =
		"GET " .. url.path .. (url.query and ("?" .. url.query) or "") .. " HTTP/1.0\r\n" ..
		"Accept: */*\r\n" ..
		"User-Agent: NSPlayer/8.0.0.3802\r\n" ..
		"Host: " .. url.host .. "\r\n" ..
		"Pragma: xClientGUID={" .. GUID .. "}\r\n" ..
		"Pragma: no-cache,rate=1.0000000,stream-offset=0:0,max-duration=0\r\n" ..
		"Pragma: stream-time=" .. streamtime .. "\r\n" ..
		"Pragma: request-context=" .. context .. "\r\n" ..
		"Pragma: LinkBW=2147483647, AccelBW=1048576, AccelDuration=21000\r\n" ..
		"Pragma: Speed=5.000\r\n" ..
		"Pragma: xPlayStrm=1\r\n" ..
		"Pragma: stream-switch-count=1\r\n" ..
		"Pragma: stream-switch-entry=ffff:1:0\r\n" ..
		"\r\n"

	self:_playstream(playback, data, decode, url.host, url.port or 80, 'w', 10, string.byte(1), 1, bitrate)
end


-- play an AAC stream
function _playstreamAAC(self, playback, data, decode, stream, bitrate)
	log:info("playing: ", stream)

	local url = socketurl.parse(stream)
	playback.header =
		"GET " .. url.path .. (url.query and ("?" .. url.query) or "") .. " HTTP/1.0\r\n" ..
		"Accept: audio/aac,audio/aacp\r\n" ..
		"User-Agent: SqueezePlay/BBCRadioApplet\r\n" ..
		"Host: " .. url.host .. "\r\n" ..
		"\r\n"

	self:_playstream(playback, data, decode, url.host, url.port or 80, 'a', 0, string.byte(2), nil, bitrate)
end


-- play a flash RTMP stream
function _playstreamRTMP(self, playback, data, decode, entry)

	local streamname, tcurl, app, subscribe, codec

	if entry.kind == "akamai" and entry["service"] != "stream" then

		local live = entry["application"] and entry["application"] == "live"
		local appl = entry["application"] or "ondemand"
		
		streamname = entry["identifier"] .. "?" .. entry["authString"] .. (live and "&aifp=v001" or "")
		subscribe  = live and entry["identifier"] or nil
		tcurl      = "rtmp://" .. entry["server"] .. ":1935/" .. appl .. "?_fcs_vhost=" .. entry["server"] .. "&" .. entry["authString"]
		app        = appl .. "?_fcs_vhost=" .. entry["server"] .. "&" .. entry["authString"]
		codec      = entry.type == "acc" and "a" or "m"

	elseif entry.kind == "limelight" then

		streamname = entry["identifier"]
		tcurl      = "rtmp://" .. entry["server"] .. ":1935/" .. entry["application"] .. "?" .. entry["authString"]
		app        = entry["application"] .. "?" .. entry["authString"]
		codec      = "a"

	elseif entry.kind == "akamai" and entry["service"] == "stream" then
		
		streamname = entry["identifier"] .. "?" .. entry["token"]
		subscribe  = entry["application"] == 'live' and entry["identifier"] or nil
		tcurl      = "rtmp://" .. entry["server"] .. ":1935/" .. entry["application"] .. "?_fcs_vhost=" .. entry["server"] .. "&" .. entry["token"]
		app        = entry["application"] .. "?_fcs_vhost=" .. entry["server"] .. "&" .. entry["token"]
		codec      = "a"

	else
		log:warn("rtmp stream not playable")
	end

	playback.header = "streamname=" .. mime.b64(streamname) .. "&tcurl=" .. mime.b64(tcurl) .. "&app=" .. mime.b64(app) .. 
		"&meta=" .. mime.b64("none") .. "&"

	if subscribe then
		playback.header = playback.header .. "&subname=" .. mime.b64(subscribe) .. "&live=" .. mime.b64(1) .. "&"
	end
	if data.start then
		playback.header = playback.header .. "&start=" .. mime.b64(data.start) .. "&"
	end

	playback.flags = 0x20 -- force use of Rtmp handler
	self:_playstream(playback, data, decode, entry["server"], 1935,
					 codec,                                    -- codec id
					 codec == "a" and 0 or 1,                  -- outputthresh
					 codec == "a" and string.byte('2') or nil, -- samplesize
					 nil,                                      -- samplerate
					 entry["bitrate"])                         -- bitrate
end


-- find the ip address, setup the decoder and start playback - done in a task to allow dns to work
function _playstream(self, playback, data, decode, host, port, codec, outputthresh, samplesize, samplerate, bitrate)

	Task("playstream", self, function()
								 local ip = dns:toip(host)
								 if ip then
									 log:info("playing stream codec ", codec, " host: ", host, " ip: ", ip, " port: ", port)
									 local v1, v2, v3, v4 = string.match(JIVE_VERSION, "(%d+)%.(%d+)%.(%d+)%sr(%d+)")
									 if v1 == '7' and v2 == '5' then
										 -- 7.5
										 decode:start(string.byte(codec),
													  string.byte(data.transitionType),
													  data.transitionPeriod,
													  data.replayGain,
													  outputthresh or data.outputThreshold,
													  data.flags & 0x03,
													  samplesize or string.byte(data.pcmSampleSize),
													  samplerate or string.byte(data.pcmSampleRate),
													  string.byte(data.pcmChannels),
													  string.byte(data.pcmEndianness)
												  )
									 else
										 -- 7.6 and later - additional channels parameter
										 decode:start(string.byte(codec),
													  string.byte(data.transitionType),
													  data.transitionPeriod,
													  data.replayGain,
													  outputthresh or data.outputThreshold,
													  data.flags & 0x03,
													  data.flags & 0xC,
													  samplesize or string.byte(data.pcmSampleSize),
													  samplerate or string.byte(data.pcmSampleRate),
													  string.byte(data.pcmChannels),
													  string.byte(data.pcmEndianness)
												  )
									 end
									 playback:_streamConnect(ip, port)

									 local type
									 if     codec == 'a' then type = 'aac'
									 elseif codec == 'm' then type = 'mp3'
									 elseif codec == 'w' then type = 'wma'
									 end
									 
									 if bitrate then
										 log:info("bitrate: ", bitrate)
										 type = bitrate .. "k " .. type
									 end
									 
									 playback.slimproto:send({ opcode = "META", data = "type=" .. mime.b64(type) .. "&" })
									 
									 if data.livetxt then
										 self:_livetxt(data.livetxt, playback, bitrate, data.spdrver)
									 end

									 if data.radiovis then
										 self:_radioVis(data.radiovis, playback, bitrate, data.spdrver)
									 end

								 else
									 log:warn("bad dns lookup for ", entry["server"])
								 end
							 end
	 ):addTask()
end


local livetxtsock

function _livetxt(self, node, playback, bitrate, spdrver)
	log:info("opening live text connection for: ", node)

	-- make sure we only have one connection to the server open at one time
	if livetxtsock then
		livetxtsock:t_removeRead()
		livetxtsock:close()
		livetxtsock = nil
	end

	local ip = "push.bbc.co.uk"
	local port = 5222
	local username = ""
	for i = 0, 20 do
		username = username .. math.random(10)
	end

	local request =
		"<stream:stream to='push.bbc.co.uk' xml:lang='en' xmlns='jabber:client' xmlns:stream='http://etherx.jabber.org/streams'>" ..
		"<iq id='auth' type='set' xmlns='jabber:client'><query xmlns='jabber:iq:auth'><password />" .. "<username>" .. username .. "</username><resource>pubsub</resource></query></iq>" ..
		"<iq id='sub' to='pubsub.push.bbc.co.uk' type='set' xmlns='jabber:client' from='" .. username .. "@push.bbc.co.uk/pubsub'>" .. "<pubsub xmlns='http://jabber.org/protocol/pubsub'><subscribe jid='" .. username .. "@push.bbc.co.uk/pubsub' node='" .. node .. "' /></pubsub></iq>"

	log:info("livetxt connect to: ", ip, " port: ", port)

	local sock = SocketTcp(jnt, ip, port, "BBClivetxt")

	sock:t_connect()

	livetxtsock = sock

	sock:t_addWrite(function(err)
						log:debug("sending livetxt request: ", request)
						if (err) then
							log:warn(err)
							return
						end
						sock.t_sock:send(request)
						sock:t_removeWrite()
					end,
					10)

	local curstream = playback.stream

	local capture, captext = false, ""
	local p = lxp.new({
		StartElement = function (parser, name, attr)
			if name == "text" then
				capture = true
			end
		end,
		CharacterData = function (parser, text)
			if capture then
				captext = captext .. text
			end
		end,
		EndElement = function()
			if capture then
				local delay = self:_currentDelay(bitrate) 
				log:info("text: ", captext, ", delay ", delay)
				local track, artist = string.match(captext, "Now playing: (.-) by (.-)%.")
				if track == nil or artist == nil then
					track, artist = nil, captext
				end
				-- send the meta after delay to sync with audio - verify same stream is playing first
				Timer(1000 * delay,
					function()
						if playback.stream == curstream then
							if spdrver == nil then
								log:info("sending now artist: ", track, " album: ", artist)
								playback.slimproto:send({ opcode = "META", data = "artist=" .. mime.b64(track) .. "&album=" .. 
													  (mime.b64(artist) or "") .. "&" })
							else
								log:info("sending now title: ", track, " artist: ", artist)
								playback.slimproto:send({ opcode = "META", 
														  data = (track and ("title=" .. mime.b64(track)) or "") .. 
														  (artist and ("&artist=" .. mime.b64(artist)) or "") .. "&" })
							end
						end
					end,
					true
				):start()
				capture, captext = false, ""
			end
		end,
	})

	sock:t_addRead(function()
					   if playback.stream == nil or playback.stream ~= curstream then
						   log:info("stream changed killing livetxt")
						   if sock == livetxtsock then
							   livetxtsock = nil
						   end
						   sock:t_removeRead()
						   sock:close()
						   return
					   end
					   local chunk, err, partial = sock.t_sock:receive(4096)
					   local xml = chunk or partial
					   if err and err ~= "timeout" then
						   log:error(err)
						   sock:t_removeRead()
					   end
					   log:debug("read livetxt: ", xml)
					   p:parse(xml)
				   end, 
				   0)

	-- reset counters used to calculate bitrate
	self.streamBytesOffset = 0
	self.streamElapsedOffset = 0
end


local stompsock

function _radioVis(self, path, playback, bitrate, spdrver)
	log:info("opening radioVis stomp connection for: ", path)

	-- make sure we only have one connection to the server open at one time
	if stompsock then
		stompsock:t_removeRead()
		stompsock:close()
		stompsock = nil
	end

	local ip = "radiovis.external.bbc.co.uk"
	local port = 61613

	local connect = 
		"CONNECT\n" ..
		"accept-version: 1.0\n" ..
		"host: radiovis.external.bbc.co.uk\n" ..
		"\n" ..
		string.char(0x00)

	local subscribe =
		"SUBSCRIBE\n" ..
		"destination: /topic/" .. path .. "/image\n" ..
		"\n" ..
		string.char(0x00)

	log:info("radioVis stomp connect to: ", ip, " port: ", port, " path: ", path)

	local sock = SocketTcp(jnt, ip, port, "BBCradioVis")

	sock:t_connect()

	stompsock = sock

	sock:t_addWrite(function(err)
						if (err) then
							log:warn(err)
							return
						end
						log:debug("sending stomp connect")
						sock.t_sock:send(connect)
						sock:t_removeWrite()
					end,
					10)

	local curstream = playback.stream

	local state = "connect"
	local buf = ""

	sock:t_addRead(
		function()
			if playback.stream == nil or playback.stream ~= curstream then
				log:info("stream changed killing stomp connection")
				if sock == stompsock then
					stompsock = nil
				end
				sock:t_removeRead()
				sock:close()
				return
			end
			local chunk, err, partial = sock.t_sock:receive(4096)
			if err and err ~= "timeout" then
				log:error(err)
				if sock == stompsock then
					stompsock = nil
				end
				sock:t_removeRead()
				sock:close()
				return
			end
			buf = buf .. (chunk or partial)
			
			-- find frame
			-- FIXME - ignores content length and assumes no 0x00 characters in body
			local frame
			for i = 1, string.len(buf) do
				if string.byte(buf, i) == 0 and string.byte(buf, i+1) == 10 then
					frame = string.sub(buf, 1, i - 1)
					buf = string.sub(buf, i + 2)
					break
				end
			end

			if frame then
				if state == "connect" and string.match(frame, "^CONNECTED") then
					sock.t_sock:send(subscribe)
					state = "connected"
				elseif state == "connected" and string.match(frame, "^MESSAGE") then
					local show, text = string.match(frame, "SHOW (.*)"), string.match(frame, "TEXT (.*)")
					local trigger = string.match(frame, "trigger%-time:(.-)%c")
					local delay = string.match(trigger, "NOW") and 0 or nil
					if (text or show) and delay then
						-- send the meta after delay to sync with audio - verify same stream is playing first
						Timer(1000 * (self:_currentDelay(bitrate) - delay),
							  function()
								  if playback.stream == curstream then
									  if show then
										  log:info("show: ", show)
										  self:_slideshow(show)
									  end
									  if text then
										  log:info("text: ", text)
										  if spdrver == nil then
											  playback.slimproto:send({ opcode = "META",
																		data = (text and ("&album=" .. mime.b64(text)) or "") .. "&" })
										  else
											  playback.slimproto:send({ opcode = "META",
																		data = (text and ("&artist=" .. mime.b64(text)) or "") .. "&" })
										  end
									  end
								  end
							  end,
							  true
						  ):start()
					end
				else
					log:warn("ignoring: ", frame)
				end
			end
		end, 
		0)
	
	-- reset counters used to calculate bitrate
	self.streamBytesOffset = 0
	self.streamElapsedOffset = 0
end


function _currentDelay(self, bitrate)
	local status = decode:status()
	-- calulate the actual bit rate over time so we can determine delay for the decode buffer
	-- (there is an inital surge so ignore the measurement for 5 seconds)
	local bytes   = status.bytesReceivedL + (status.bytesReceivedH * 0xFFFFFFFF) - self.streamBytesOffset
	local elapsed = status.elapsed / 1000 - self.streamElapsedOffset
	local rate

	if bitrate then
		rate = bitrate * 1000
	elseif self.streamBytesOffset == 0 then
		if elapsed > 5 then
			self.streamBytesOffset = bytes
			self.streamElapsedOffset = elapsed
		end
		rate = 128000
	else
		rate = 8 * bytes / elapsed
	end

	local outputD = status.outputFull / (44100 * 8) -- output buffer delay in secs
	local decodeD = status.decodeFull / (rate  / 8) -- decode buffer delay in secs
	local delay   = outputD + decodeD

	log:info("delay: ", delay, " (decode: ", decodeD, " output: ", outputD, ") rate: ", rate)
	return delay
end


function _slideshow(self, slideurl)
	-- update existing slideshow window if already showing
	if Framework:isCurrentWindow(self.sswindow) then
		local cached = self.artworkCache:get(slideurl)
		if cached then
			log:info("image cached: ", slideurl)
			self:_showImage(Surface:loadImageData(cached, #cached))
		else
			log:info("fetch update: ", slideurl)
			local req = RequestHttp(_sinkScreensaver(self, slideurl), 'GET', slideurl, { headers = self.ssheaders})
			local uri = req:getURI()
			local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
			http:fetch(req)
		end
		return
	end

	-- check if now playing is showing, open slideshow on top of this if it is...
	local nowPlaying = appletManager:getAppletInstance("NowPlaying")
	if not Framework:isCurrentWindow(nowPlaying.window) then
 		return
	end

	log:info("open bbcradio slideshow")
	self.sswindow = Window("text_list")

	self.artworkCache = ArtworkCache()

	self.sw, self.sh = Framework:getScreenSize()
	-- FIXME - does the BBC support these headers?
	self.ssheaders = { ['Display-Width'] = self.sw, ['Display-Height'] = self.sh }
	
	log:info("fetch: ", slideurl)
	local req = RequestHttp(_sinkScreensaver(self, slideurl), 'GET', slideurl, { headers = self.ssheaders })
	local uri = req:getURI()
	local http = SocketHttp(jnt, uri.host, uri.port, uri.host)
	http:fetch(req)

	self.ssbg = Surface:newRGBA(self.sw, self.sh)
	self.ssbg:filledRectangle(0, 0, self.sw, self.sh, 0x000000FF)
	self.ssicon = Icon("icon", self.ssbg)
	
	self.sswindow:addWidget(self.ssicon)
	self.sswindow:setShowFrameworkWidgets(false)

	local manager = appletManager:getAppletInstance("ScreenSavers")
	manager:screensaverWindow(self.sswindow, _, _, _, "BBCRadioSlideShow")

	self.sswindow:show(Window.transitionFadeIn)
end


function _sinkScreensaver(self, url)
	return function(chunk, err)
			   if err then
				   log:warn(err)
			   end
			   if chunk then
				   self.artworkCache:set(url, chunk)
				   self:_showImage(Surface:loadImageData(chunk, #chunk))
			   end
		   end
end


function _showImage(self, image)
	local w, h = image:getSize()
	local offset = 0
	if w ~= self.sw and h ~= self.sh then
		local tmp = image:rotozoom(0, (self.sh+1) / h, 1)
		image:release()
		image = tmp
		local wnew, hnew = image:getSize()
		offset = (self.sw - wnew) / 2
	end
	local alpha = 0
	local update = System:getMachine() == 'baby' and FRAME_RATE / 2 or FRAME_RATE 
	local step  = 128 / update
	if self.ssanimate then
		self.ssicon:removeAnimation(self.ssanimate)
	end
	self.ssanimate = self.ssicon:addAnimation(
		function() 
			alpha = alpha + step
			alpha = alpha > 255 and 255 or alpha
			image:blitAlpha(self.ssbg, offset, 0, alpha)
			if alpha >= 255 then
				self.ssicon:removeAnimation(self.ssanimate)
				self.ssanimate = nil
			end
			self.ssicon:reDraw()
		end,
		update)
end