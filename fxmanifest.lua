fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
author 'NotGoey'
description 'A bridge from qb-target to ox_target'
version '5.5.0'

client_scripts {
	'init.lua',
	'client.lua',
}

dependency 'ox_target'

provide 'qb-target'