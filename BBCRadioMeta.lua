
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
	local lowend = System:getMachine() == 'baby' and true or false
	return { usewma = lowend }
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

	self.menu = self:menuItem('appletBBCRadio', 'hidden', 'BBC Radio', 
							   function(applet, ...) applet:menu(...) end, 0, { icon = icon }, "hm_radio")
	jiveMain:addItem(self.menu)
					 
	self:registerService("bbcmsparser")

	Playback:registerHandler('bbcmsparser', function(...) appletManager:callService("bbcmsparser", ...) end)
end


function notify_playerCurrent(self, player)
	if player and player == Player:getLocalPlayer() then
		log:debug("local player selected - adding to menu")
		jiveMain:addItemToNode(self.menu, 'radios')
	else
		log:debug("local player not selected - removing from menu")
		jiveMain:removeItemFromNode(self.menu, 'radios')
	end
end