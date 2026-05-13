fx_version 'cerulean'

game "gta5"

author "Project Sloth & OK1ez (Atlas port)"
version '1.1.7-atlas'
description 'Admin Menu (Atlas port)'
repository 'https://github.com/P-AtlasFramework/ps-adminmenu'

lua54 'yes'

ui_page 'html/index.html'
-- ui_page 'http://localhost:5173/' --for dev

client_script {
  'client/**',
}

server_script {
  '@atlas_mongodb/mongodb.lua',
  "server/**",
}

shared_script {
  '@ox_lib/init.lua',
  "shared/**",
}

files {
  'html/**',
  'data/ped.lua',
  'data/object.lua',
  'data/locations.lua',

  'locales/*.json',
}

dependencies {
  'atlas_core',
  'atlas_mongodb',
  'qb-core',     -- compat bridge that re-exposes atlas_core under the QBCore name
  'ox_lib',
}

ox_lib 'locale' -- v3.8.0 or above
