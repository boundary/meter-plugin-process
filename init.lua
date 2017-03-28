-- @vitiwari
-- plugin to track Process utilization using lua

local framework = require('framework')
local net = require('net')
local json = require('json')
local os = require('os')

local Plugin = framework.Plugin
local DataSource = framework.DataSource
local DataSourcePoller = framework.DataSourcePoller
local PollerCollection = framework.PollerCollection
local ipack = framework.util.ipack
local parseJson = framework.util.parseJson
local notEmpty = framework.string.notEmpty
--local table = framework.table
local clone = framework.table.clone
--Getting the parameters from params.json.
local params = framework.params
local hostName =nil
local pollers = nil
local plugin = nil


-- @vitiwari
-- This datasource to get percentage cpu usage based on parameters
 local ProcessCpuDataSource = DataSource:extend()


function ProcessCpuDataSource:initialize(params)
  local options = params or {}
  self.options = options
end

--ProcessCpuDataSource fetch function
function ProcessCpuDataSource:fetch(context, callback,params)
  local options = clone(self.options)
  local parse = function (val)
      local result = {}
      if table.getn(val) <= 0 then
          self:emit('error', 'No process found with specifications given: '..json.stringify(self.options))
          return
      end
      for K,V  in pairs(val) do
         table.insert(result, {metric = V["metric"], value = V["val"],source = V["source"], timestamp = nil})
      end
   callback(result)
  end
  --Call the get process cpu Data which will make JSON RPC calls
  ProcessCpuDataSource:getProcessCpuData(9192,'127.0.0.1',options,parse)
end


function ProcessCpuDataSource:getProcessCommandString(params)
 
 local commandParam ={}
 commandParam.process = params.process or ''
 commandParam.path_expr = params.path_expr or ''
 commandParam.cwd_expr = params.cwd_expr or ''
 commandParam.args_expr = params.args_expr or ''
 commandParam.reconcile = params.reconcile or ''
 
 commandParam = commandParam or { match = ''}
 return '{"jsonrpc":"2.0","method":"get_process_info","id":1,"params":' .. json.stringify(params) .. '}\n'
end




function ProcessCpuDataSource:getProcessCpuData(port,host,prams,parse)
  local callback = function()
  end
  local socket = net.createConnection(tonumber(port), host, callback)
  socket:write(ProcessCpuDataSource:getProcessCommandString(prams))
  socket:once('data',function(data)
  local sucess,  parsed = parseJson(data)
  local result = {}
   if(parsed.result.processes~=nil)then
    for K,V  in pairs(parsed.result.processes) do
       if(prams.isCpuMetricsReq) then
        local resultitem={}
        resultitem['metric']='CPU_PROCESS'
        resultitem['val']= V["cpuPct"]/100
        resultitem['source']= prams['source'].."_"..V["name"]
        table.insert(result,resultitem)
      end

      if(prams.isMemMetricsReq) then
        local itm={}
        itm['metric']='MEM_PROCESS'
        itm['val']= V["memRss"]
        itm['source']= prams['source'].."_"..V["name"]
        table.insert(result,itm)
      end
      
      if(prams.isFHMetricsReq) then
        local itm={}
        itm['metric']='OPEN_HANDLES'
        itm['val']= V["openHandles"]
        itm['source']= prams['source'].."_"..V["name"]
        table.insert(result,itm)
      end

      --i=i+1;
    end
  end
  socket:destroy()
  parse(result)
end)
end



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
   options.isFHMetricsReq = item.isFHMetricsReq or false
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
                measurement(V.metric, V.value, nil , V.source)
            end

         return measurements
       end
end)

