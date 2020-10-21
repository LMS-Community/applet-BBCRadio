
-- BBCRadio Meta - see main applet file for details

local oo            = require("loop.simple")
local mime          = require("mime")

local System        = require("jive.System")
local AppletMeta    = require("jive.AppletMeta")
local Playback      = require("jive.audio.Playback")
local Icon          = require("jive.ui.Icon")
local Player        = require("jive.slim.Player")

local appletManager = appletManager
local jiveMain      = jiveMain

local jnt           = jnt

local icon_url = "http://www.mysqueezebox.com/static/images/icons/bbc.png"

module(...)
oo.class(_M, AppletMeta)


function jiveVersion(self)
	return 1, 1
end


function defaultSettings(self)
	return {
		streamtype = System:getMachine() == 'baby' and "wma" or "high"
	}
end


function upgradeSettings(self, settings)
	if settings.streamtype == nil then
		settings.streamtype = System:getMachine() == 'baby' and "wma" or "high"
	end
	return settings
end


function registerApplet(self)
	jnt:subscribe(self)

	local icon = Icon("icon")
	-- use the checkSkin function to load the icon image on first call
	local cs = icon.checkSkin
	icon.checkSkin = function(...)
						 local player = Player:getLocalPlayer()
						 local server = player and player:getSlimServer()
						 if server then
							 server:fetchArtwork(icon_url, icon, jiveMain:getSkinParam('THUMB_SIZE'), 'png')
						 end
						 cs(...)
						 -- replace with original
						 icon.checkSkin = cs
					 end

	self.menu = self:menuItem('appletBBCRadio', 'radios', 'BBC Radio', 
							  function(applet, ...) applet:menu(...) end, 0, { icon = icon }, "hm_radio")
	self.icon = icon

	jiveMain:addItem(self.menu)
	
	self:registerService("bbcparser")

	Playback:registerHandler('bbcmsparser',  function(...) appletManager:callService("bbcparser", "ms", ...)  end)
	Playback:registerHandler('bbcplsparser', function(...) appletManager:callService("bbcparser", "pls", ...) end)
end


-- add to myapps menu
function notify_playerLoaded(self, player)
	if player and player == Player:getLocalPlayer() then
		log:debug("local player loaded - adding to menu")
		local menus = appletManager:getAppletInstance("SlimMenus")
		if menus._addMyAppsNode then
			log:debug("local player selected - adding to menu myApps")
			if not menus.myAppsNode then
				menus:_addMyAppsNode()
			end
			self.menu.node = 'myApps'
			menus:_addItem(self.menu)
			-- update to our custom icon
			self.menu.icon = self.icon
		end
	end
end

