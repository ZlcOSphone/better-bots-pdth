local module = DMod:new("better_bots", {
	name = "Better Bots", version = "1.1",
	author = "Schmuddel", bundled = false, description = {
		english = "This mod ports many of the features of the Better Bots mod for PD2 to PD:TH while also adding a few new unique features, improvements, and fixes to the teammate AI. Original Thread: http://steamcommunity.com/app/24240/discussions/0/133258593388845203"
	}
})

if Util:version_compare(D:version(), "1.3.99") > 0 then
	module:set_update({ id = "19324", platform = "modworkshop", archive_root_folder = "lib/Lua/BetterBots/", archive_file_filter = "betterbots.lua" })
end

local file_hooks = {
	"lib/managers/criminalsmanager",
	"lib/managers/navigationmanager",
	"lib/managers/group_ai_states/groupaistatebase",
	"lib/units/player_team/logics/teamailogicassault",
	"lib/units/player_team/logics/teamailogicidle",
	"lib/units/player_team/logics/teamailogictravel",
	"lib/units/player_team/teamaidamage",
	"lib/units/weapons/raycastweaponbase"
}
for _, path in pairs(file_hooks) do
	module:hook_post_require(path, "betterbots")
end

return module