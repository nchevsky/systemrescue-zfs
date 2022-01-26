#!/usr/bin/env lua
--
-- Author: Francois Dupoux
-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- SystemRescue configuration processing script
--
-- This script uses the SystemRescue yaml configuration files and the options
-- passed on the boot command line to override the default configuration.
-- It processes yaml configuration files in the alphabetical order, and each option
-- found in a file override the options defined earlier. Options passed on the
-- boot command like take precedence over configuration options defined in files.
-- At the end it writes the effective configuration to a JSON file which is meant
-- to be ready by any initialisation script which needs to know the configuration.
-- Shell scripts can read values from the JSON file using a command such as:
-- jq --raw-output '.global.copytoram' /etc/sysrescue/sysrescue-effective-config.json
-- This script requires the following lua packages to run on Arch Linux:
-- sudo pacman -Sy lua lua-yaml lua-dkjson

-- ==============================================================================
-- Import modules
-- ==============================================================================
local lfs = require('lfs')
local yaml = require('yaml')
local json = require("dkjson")

-- ==============================================================================
-- Utility functions
-- ==============================================================================
function read_file_contents(path)
    local file = io.open(path, "rb")
    if not file then
        return nil
    end
    local content = file:read("*a")
    file:close()
    return content
end

function list_config_files(path)
    local results = {}
    for curfile in lfs.dir(path) do
        fullpath = path.."/"..curfile
        filetype = lfs.attributes(fullpath, "mode")
        if filetype == "file" and curfile:match(".[Yy][Aa][Mm][Ll]$") then
            table.insert(results, fullpath)
        end
    end
    table.sort(results)
    return results
end

-- ==============================================================================
-- Define the default configuration
-- ==============================================================================
print ("====> Define the default configuration ...")
config = {
    ["global"] = {
        ['copytoram'] = false,
        ['checksum'] = false,
        ['loadsrm'] = false,
        ['dostartx'] = false,
        ['dovnc'] = false,
        ['noautologin'] = false,
        ['nofirewall'] = false,
        ['rootshell'] = "",
        ['rootpass'] = "",
        ['rootcryptpass'] = "",
        ['setkmap'] = "",
        ['vncpass'] = "",
    },
    ["autorun"] = {
        ['ar_disable'] = false,
        ['ar_nowait'] = false,
        ['ar_nodel'] = false,
        ['ar_ignorefail'] = false,
        ['ar_attempts'] = false,
        ['ar_source'] = "",
        ['ar_suffixes'] = "0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F",
    },
    ["ca-trust"] = {},
}

-- ==============================================================================
-- Override the configuration with values from yaml files
-- ==============================================================================
print ("====> Overriding the default configuration with values from yaml files ...")
yamlconfdirs = {"/run/archiso/bootmnt/sysrescue.d", "/run/archiso/copytoram/sysrescue.d"}
for _, confdir in ipairs(yamlconfdirs) do
    if lfs.attributes(confdir, "mode") == "directory" then
        print("Searching for yaml configuration files in "..confdir.." ...")
        for _, curfile in ipairs(list_config_files(confdir)) do
            print("Processing yaml configuration file: "..curfile.." ...")
            local curconfig = yaml.loadpath(curfile)
            --print("++++++++++++++\n"..yaml.dump(curconfig).."++++++++++++++\n")
            if curconfig ~= nil then
                -- Override specific pre-defined options
                for _, scope in ipairs({"global", "autorun"}) do
                    for key, val in pairs(config[scope]) do
                        if (curconfig[scope] ~= nil) and (curconfig[scope][key] ~= nil) then
                            print("- Overriding config['"..scope.."']['"..key.."'] with the value from the yaml file")
                            config[scope][key] = curconfig[scope][key]
                        end
                    end
                end
                -- Populate additional items
                for _, scope in ipairs({"ca-trust"}) do
                    if curconfig[scope] ~= nil then
                        for key, val in pairs(curconfig[scope]) do
                            print("- Setting config['"..scope.."']['"..key.."'] with the value from the yaml file")
                            config[scope][key] = val
                        end
                    end
                end
            end
        end
    else
        print("Directory "..confdir.." was not found so it has been ignored")
    end
end

-- ==============================================================================
-- Override the configuration with values passed on the boot command line
-- ==============================================================================
print ("====> Overriding the configuration with options passed on the boot command line ...")
local cmdline = read_file_contents("/proc/cmdline");
for curopt in cmdline:gmatch("%S+") do
    --print ("Found option on the boot command line: "..curopt)
    for _, scope in ipairs({"global", "autorun"}) do
        for key,val in pairs(config[scope]) do
            optmatch1 = string.match(curopt, "^"..key.."$")
            _, _, optmatch2 = string.find(curopt, "^"..key.."=([^%s]+)$")
            if type(val) == "boolean" then
                if (optmatch1 ~= nil) or (optmatch2 == 'y') or (optmatch2 == 'yes') or (optmatch2 == 'true') then
                    print("- Option '"..key.."' has been enabled on the boot command line")
                    config[scope][key] = true
                elseif (optmatch2 == 'n') or (optmatch2 == 'no') or (optmatch2 == 'false') then
                    print("- Option '"..key.."' has been disabled on the boot command line")
                    config[scope][key] = false
                end
            else
                if optmatch2 ~= nil then
                    print("- Option '"..key.."' has been defined on the boot command line")
                    config[scope][key] = optmatch2
                end
            end
        end
    end
end

-- ==============================================================================
-- Print the effective configuration
-- ==============================================================================
print ("====> Printing the effective configuration")
local jsoncfgtxt = json.encode (config, { indent = true })
print (jsoncfgtxt)

-- ==============================================================================
-- Write the effective configuration to a JSON file
-- ==============================================================================
print ("====> Writing the effective configuration to a JSON file ...")
output_location = "/etc/sysrescue"
output_filename = "sysrescue-effective-config.json"
output_fullpath = output_location.."/"..output_filename
lfs.mkdir(output_location)
jsoncfgfile = io.open(output_fullpath, "w")
jsoncfgfile:write(jsoncfgtxt)
jsoncfgfile:close()
os.execute("chmod 700 "..output_location)
os.execute("chmod 600 "..output_fullpath)
print ("Effective configuration has been written to "..output_fullpath)
