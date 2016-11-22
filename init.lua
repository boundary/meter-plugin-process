-- @vitiwari
-- plugin to track Process Cpu utilization using lua
local framework = require('framework')
local net = require('net')
local json = require('json')

local Plugin = framework.Plugin
local ProcessCpuDataSource = framework.ProcessCpuDataSource
local DataSourcePoller = framework.DataSourcePoller
local PollerCollection = framework.PollerCollection
local ipack = framework.util.ipack
local parseJson = framework.util.parseJson
local notEmpty = framework.string.notEmpty

--Getting the parameters from params.json.
local params = framework.params
local hostName =nil
local pollers = nil
local plugin = nil
local createOptions=function(item)

   local options = {}
   options.source = notEmpty(item.source,hostName)
   options.process = item.processName or ''
   options.path_expr = item.processPath or ''
   options.cwd_expr = item.processCwd or ''
   options.args_expr = item.processArgs or ''
   options.reconcile = item.reconcile or ''
   options.isCpuMetricsReq = item.isCpuMetricsReq or false
   options.isMemMetricsReq = item.isMemMetricsReq or false
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
                local statsPoller = DataSourcePoller:new(notEmpty(tonumber(item.pollInterval),1000), cs)
                polers:add(statsPoller)
        end
        return polers
end

local ck = function()
end
local socket1 = net.createConnection(9192, '127.0.0.1', ck)
socket1:write('{"jsonrpc":"2.0","id":3,"method":"get_system_info","params":{}}')
   socket1:once('data',function(data)
     local sucess,  parsed = parseJson(data)
       hostName =  parsed.result.hostname--:gsub("%-", "")
       socket1:destroy()
       pollers = createPollers(params)
       plugin = Plugin:new(params, pollers)
       plugin:run()
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
end)

