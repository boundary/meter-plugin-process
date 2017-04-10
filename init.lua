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

pIdIndexMap = {}

-- @vitiwari
-- This datasource to get percentage cpu usage based on parameters
local ProcessCpuDataSource = DataSource:extend()

function table.removeValue(table, value)
  for K,V  in pairs(table) do
    if(V == value) then
      table[K] = nil
    end
  end
end

function table.getSize(table)
  local count=0
  for K,V  in pairs(table) do
    count = count+1
  end
  return count
end

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

      local processValMap = {}
      local processValList = {}
      local tempProcessValMap = {}

      if(prams.logicChoice == "all_ind_source") then

        -- extract All process & keep name wise
        for K,V  in pairs(parsed.result.processes) do

          local processArray = tempProcessValMap[V["name"]] or {}
          local valueObj = {}
          valueObj["count"] = 1
          valueObj["pid"] = V["pid"]
          valueObj["name"] = V["name"]
          valueObj["cpuPct"] =  V["cpuPct"]
          valueObj["memRss"] =  V["memRss"]
          valueObj["openHandles"] =  V["openHandles"]
          table.insert(processArray,valueObj)
          tempProcessValMap[V["name"]] = processArray
        end
        --print(" tempProcessValMap ".. json.stringify(tempProcessValMap))

        for K,V  in pairs(tempProcessValMap) do
          local indexMap =  pIdIndexMap[K] or {}
          local processArray = tempProcessValMap[K] or {}
          local leftOutProcesses = {}
          for K1,V1  in pairs(processArray) do
            if(indexMap[V1["pid"]]) then
              V1["name"]= prams['source'].."_"..V1["name"]..indexMap[V1["pid"]]
              table.insert(processValList,V1)
              processValMap[indexMap[V1["pid"]]] = V1
            else
              table.insert(leftOutProcesses,V1)
            end
          end
          --print("processValList 1  ".. json.stringify(processValList))
          --print("indexMap  1  " .. json.stringify(indexMap))
          --print("leftOutProcesses 1  " .. json.stringify(leftOutProcesses))
          --Fill left processes
          local i=1
          while i <= #leftOutProcesses do
            --indexSort and start from 1
            --print("indexMap "..json.stringify(indexMap).." , ".. table.getSize(indexMap))
            local j=1;
            while (j <= table.getSize(indexMap)) do
              --print("j "..j.." processValMap[j] "..json.stringify(processValMap))
              if(not processValMap[j]) then
                local value = leftOutProcesses[i]
                value["name"] = prams['source'].."_"..value["name"]..j
                table.insert(processValList,value)
                processValMap[j]= value
                table.remove(leftOutProcesses,i)
                table.removeValue(indexMap,j)
                indexMap[value["pid"]]=j
                --print("VALUe inserted at position J "..j)
                i=i+1;
                break;
              end
              j=j+1
            end
            i=i+1;
          end
          --print("processValList 2  ".. json.stringify(processValList))
          --print("indexMap 2  " .. json.stringify(indexMap))
          --print("leftOutProcesses 2  " .. json.stringify(leftOutProcesses).."  size "..#leftOutProcesses)
          i=1
          while i <= #leftOutProcesses do
            local count = #processValList
            local value = leftOutProcesses[i]
            value["name"] = prams['source'].."_"..value["name"]..(count+1)
            indexMap[value["pid"]]= count+1
            table.insert(processValList,value)
            processValMap[indexMap[value["pid"]]] = value
            i=i+1
          end

          --print("processValList  3 ".. json.stringify(processValList))
          --print("indexMap  3 " .. json.stringify(indexMap))
          --print("leftOutProcesses 3  " .. json.stringify(leftOutProcesses))
          pIdIndexMap[K] = indexMap
        end

        --end
      else
        --start
        local processMap = {}

        for K,V  in pairs(parsed.result.processes) do
          if(processMap[V["name"]])then
            local valueObj = processMap[V["name"]]
            valueObj["count"] = valueObj["count"] + 1
            valueObj["cpuPct"] =  valueObj["cpuPct"] + V["cpuPct"]
            valueObj["memRss"] =  valueObj["memRss"] + V["memRss"]
            valueObj["openHandles"] =  valueObj["openHandles"] + V["openHandles"]
            valueObj["name"] = prams['source'].."_"..V["name"]
            processMap[V["name"]] = valueObj
            table.insert(processValList,valueObj)
          else
            local valueObj = {}
            valueObj["count"] = 1
            valueObj["cpuPct"] = V["cpuPct"]
            valueObj["memRss"] = V["memRss"]
            valueObj["openHandles"] = V["openHandles"]
            valueObj["name"] = prams['source'].."_"..V["name"]
            processMap[V["name"]] = valueObj
            table.insert(processValList,valueObj)
          end
        end
      end

      for K,V  in pairs(processValList) do

        if(prams.isCpuMetricsReq) then
          local resultitem={}
          resultitem['metric']='CPU_PROCESS'
          resultitem['val']= V["cpuPct"]/(V["count"] * 100)
          resultitem['source']= V["name"]
          table.insert(result,resultitem)
        end

        if(prams.isMemMetricsReq) then
          local itm={}
          itm['metric']='MEM_PROCESS'
          itm['val']= V["memRss"]/V["count"]
          itm['source']=  V["name"]
          table.insert(result,itm)
        end

        if(prams.isFHMetricsReq) then
          local itm={}
          itm['metric']='OPEN_HANDLES'
          itm['val']= V["openHandles"]/(V["count"])
          itm['source']=  V["name"]
          table.insert(result,itm)
        end

        local resultitem={}
        resultitem['metric']='PROCESS_COUNT'
        resultitem['val']= V["count"]
        resultitem['source']=  V["name"]
        table.insert(result,resultitem)

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

  if ((item.reconcile == "all_source_avg") or (item.reconcile == "all_ind_source")) then
    options.reconcile = "all"
    options.logicChoice = item.reconcile
  else
    options.reconcile = item.reconcile
    options.logicChoice = "all_source_avg"
  end
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


