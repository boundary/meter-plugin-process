-- @vitiwari
-- plugin to track Process Cpu utilization using lua
local framework = require('framework')

local Plugin = framework.Plugin
local ProcessCpuDataSource = framework.ProcessCpuDataSource
local DataSourcePoller = framework.DataSourcePoller
local PollerCollection = framework.PollerCollection
local ipack = framework.util.ipack
local parseJson = framework.util.parseJson
local notEmpty = framework.string.notEmpty

--Getting the parameters from params.json.
local params = framework.params

local createOptions=function(item)

   local options = {}
   options.source = item.source or ''
   options.process = item.processName or ''
   options.path_expr = item.processPath or ''
   options.cwd_expr = item.processCwd or ''
   options.args_expr = item.processArgs or ''
   options.reconcile = item.reconcile or ''
   options.pollInterval = notEmpty(tonumber(item.pollInterval),1000)

   return options
end

local createStats = function(item)

    local options = createOptions(item)
    return ProcessCpuDataSource:new(options)
end

local createPollers=function(params)
        local polers = PollerCollection:new()

        for _, item in pairs(params.items) do
                local cs = createStats(item)
                local statsPoller = DataSourcePoller:new(tonumber(item.pollInterval), cs)
                polers:add(statsPoller)
        end
        return polers
end


local pollers = createPollers(params)
local plugin = Plugin:new(params, pollers)

function plugin:onParseValues(data, extra)
    
    local measurements = {}
    local measurement = function (...)
        ipack(measurements, ...)
    end
    for K,V  in pairs(data) do
      measurement(V.metric, V.value, V.timestamp, V.source)
    end

    return measurements
end

plugin:run()
