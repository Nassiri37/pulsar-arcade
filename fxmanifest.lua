fx_version("cerulean")
lua54("yes")
game("gta5")

client_script("@pulsar-core/exports/cl_error.lua")
client_script("@pulsar-pwnzor/client/check.lua")

shared_scripts({
	"shared/**/*.lua",
})

client_scripts({
	"client/**/*.lua",
})

server_scripts({
	"shared/**/*.lua",
	"server/inventory.lua",
	"server/matches.lua",
	"server/main.lua",
})

dependencies({
	"ox_inventory",
	"pulsar-core",
	"pulsar-characters",
})
