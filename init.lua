-- @vitiwari
-- plugin to track Process utilization using lua

local framework = require('framework')
local net = require('net')
local json = require('json')
local os = require('os')
local timer = require('timer')

local Plugin = framework.Plugin
local DataSource = framework.DataSource
local DataSourcePoller = framework.DataSourcePoller
local PollerCollection = framework.PollerCollection
local ipack = framework.util.ipack
local parseJson = framework.util.parseJson
local notEmpty = framework.string.notEmpty
local clone = framework.table.clone
local params = framework.params
local hostName =nil
local pollers = nil
local plugin = nil
local logger = framework.Logger

pIdIndexMap = {}
--default logging
local log = logger:new(process.stderr,logger.parseLevel(logger.ERROR))
log:setLevel(logger.parseLevel(logger.ERROR))

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
  local count = 0
  for K,V  in pairs(table) do
    count = count + 1
  end
  return count
end

function ProcessCpuDataSource:initialize(params,index)
  local options = params or {}
  self.options = options
  self.instanceNumber = "Instance"..index
  self.instancelog = logger:new(process.stderr,logger.parseLevel(params.logLevel))
  self.instancelog:debug(self.instanceNumber..": Process Instance initialized process:"..params.process..", path:"..params.path_expr..",cwd:"..params.cwd_expr..",args:"..params.args_expr)

end

--ProcessCpuDataSource fetch function
function ProcessCpuDataSource:fetch(context, callback,finalCallBack)
  self.instancelog:debug(self.instanceNumber..": Data source fetch called")
  local options = clone(self.options)
  local parse = function (self,val)
    local result = {}
    if table.getn(val) <= 0 then
      local message = '';
      if (self.options.process and self.options.process ~= '') then
        message = message .. ", Process Name Regex = ".. self.options.process
      end
      if (self.options.path_expr and self.options.path_expr ~= '') then
        message= message .. ", Process Path Regex = "..self.options.path_expr
      end
      if (self.options.cwd_expr and self.options.cwd_expr ~= '')  then
        message= message .. ", Process CWD Regex = "..self.options.cwd_expr
      end
      if (self.options.args_expr and self.options.args_expr ~= '') then
        message= message .. ", Process Args Regex="..self.options.args_expr
      end
      plugin:emitEvent('error', 'No process found with given parameters'..message)
      self.instancelog:error(self.instanceNumber..": No process found with given parameters"..message)
      finalCallBack()
      return
    end
    for K,V  in pairs(val) do
      table.insert(result, {metric = V["metric"], value = V["val"],source = V["source"], timestamp = nil})
    end
    callback(result)
    finalCallBack()
  end
  --Call the get process cpu Data which will make JSON RPC calls
  ProcessCpuDataSource:getProcessCpuData(9192,'127.0.0.1',options,parse,finalCallBack,self)
end


function ProcessCpuDataSource:getProcessCommandString(params)

  local commandParam ={}
  commandParam.process = params.process or ''
  commandParam.path_expr = params.path_expr or ''
  commandParam.cwd_expr = params.cwd_expr or ''
  commandParam.args_expr = params.args_expr or ''
  commandParam.reconcile = params.reconcile or ''
  commandParam = commandParam or { match = ''}
  return '{"jsonrpc":"2.0","method":"get_process_info","id":1,"params":' .. json.stringify(commandParam) .. '}\n'
end

function ProcessCpuDataSource:getProcessCpuData(port,host,prams,parse,finalCallBack,self)
  --local logger = self.log
  local socket = nil
  local selfLog = self.instancelog
  local callback = function()
    local cmdstring = ProcessCpuDataSource:getProcessCommandString(prams)
    selfLog:debug(self.instanceNumber..": command written to Rpc : ".. cmdstring)
    socket:write(cmdstring)
  end
  selfLog:debug(self.instanceNumber..": About to make a socket connection ")
  socket = net.createConnection(tonumber(port), host, callback)

  socket:once('error',function(data)
    selfLog:debug(self.instanceNumber..": Get process details resulted into error, "..json.stringify(data))
    plugin:emitEvent('error', 'Get process details resulted into error,'..json.stringify(data))
    socket:destroy()
    finalCallBack()
  end)
  socket:once('data',function(data)
    selfLog:debug(self.instanceNumber..": Get process details successful")
    local sucess,  parsed = parseJson(data)
    local result = {}
    if(parsed and parsed.result and parsed.result.processes~=nil) then

      local processValMap = {}
      local processValList = {}
      local tempProcessValMap = {}

      if(prams.logicChoice == "all_ind_source") then
        selfLog:debug(self.instanceNumber..": Reconcile as Individual sources")
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
          --Fill left processes
          local i=1
          while i <= #leftOutProcesses do
            local j=1;
            while (j <= table.getSize(indexMap)) do
              if(not processValMap[j]) then
                local value = leftOutProcesses[i]
                value["name"] = prams['source'].."_"..value["name"]..j
                table.insert(processValList,value)
                processValMap[j]= value
                table.remove(leftOutProcesses,i)
                table.removeValue(indexMap,j)
                indexMap[value["pid"]]=j
                i=i+1;
                break;
              end
              j=j+1
            end
            i=i+1;
          end
          --append rest processes at end
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

          pIdIndexMap[K] = indexMap
        end
        -- Get the values average from Map
        for K,V  in pairs(processValList) do
          if(prams.isCpuMetricsReq) then
            local resultitem={}
            resultitem['metric']='CPU_PROCESS'
            resultitem['val']= V["cpuPct"]/(V["count"] * 100)
            resultitem['source']= V["name"]
            selfLog:debug(self.instanceNumber..": CPU_PROCESS ",{resultitem['val'],resultitem['source']})
            table.insert(result,resultitem)
          end

          if(prams.isMemMetricsReq) then
            local itm={}
            itm['metric']='MEM_PROCESS'
            itm['val']= V["memRss"]/V["count"]
            itm['source']=  V["name"]
            selfLog:debug(self.instanceNumber..": MEM_PROCESS ",{itm['val'],itm['source']})
            table.insert(result,itm)
          end

          if(prams.isFHMetricsReq) then
            local itm={}
            itm['metric']='OPEN_HANDLES'
            itm['val']= V["openHandles"]/(V["count"])
            itm['source']=  V["name"]
            selfLog:debug(self.instanceNumber..": OPEN_HANDLES ",{itm['val'],itm['source']})
            table.insert(result,itm)
          end

          local resultitem={}
          resultitem['metric']='PROCESS_COUNT'
          resultitem['val']= V["count"]
          resultitem['source']=  V["name"]
          selfLog:debug(self.instanceNumber..": PROCESS_COUNT ",{resultitem['val'],resultitem['source']})
          table.insert(result,resultitem)
        end --for end
      else
        selfLog:debug(self.instanceNumber..": Reconcile as "..prams["reconcile"])

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
          else
            local valueObj = {}
            valueObj["count"] = 1
            valueObj["cpuPct"] = V["cpuPct"]
            valueObj["memRss"] = V["memRss"]
            valueObj["openHandles"] = V["openHandles"]
            valueObj["name"] = prams['source'].."_"..V["name"]
            processMap[V["name"]] = valueObj
          end
        end

        -- Get the values average from Map
        for K,V  in pairs(processMap) do
          if(prams.isCpuMetricsReq) then
            local resultitem={}
            resultitem['metric']='CPU_PROCESS'
            resultitem['val']= V["cpuPct"]/(V["count"] * 100)
            resultitem['source']= V["name"]
            selfLog:debug(self.instanceNumber.." CPU_PROCESS ",{resultitem['val'],resultitem['source']})
            table.insert(result,resultitem)
          end

          if(prams.isMemMetricsReq) then
            local itm={}
            itm['metric']='MEM_PROCESS'
            itm['val']= V["memRss"]/V["count"]
            itm['source']=  V["name"]
            selfLog:debug(self.instanceNumber.." MEM_PROCESS ",{itm['val'],itm['source']})
            table.insert(result,itm)
          end

          if(prams.isFHMetricsReq) then
            local itm={}
            itm['metric']='OPEN_HANDLES'
            itm['val']= V["openHandles"]/(V["count"])
            itm['source']=  V["name"]
            selfLog:debug(self.instanceNumber.." OPEN_HANDLES ",{itm['val'],itm['source']})
            table.insert(result,itm)
          end

          local resultitem={}
          resultitem['metric']='PROCESS_COUNT'
          resultitem['val']= V["count"]
          resultitem['source']=  V["name"]
          selfLog:debug(self.instanceNumber.." PROCESS_COUNT ",{resultitem['val'],resultitem['source']})
          table.insert(result,resultitem)
        end --for end
      end --else end
    end
    socket:destroy()
    parse(self,result)

  end)
end



local createOptions=function(item)

  log:debug("Creating instance parameter options .. ")
  local options = {}
  local isValueAvailable = false;
  options.source = notEmpty(item.source,hostName)
  log:debug("Source : ",options.source)
  if(item.processName and item.processName ~= "") then
    options.process = item.processName
    log:debug("options.process  : ",options.process )
    isValueAvailable = true
  else
    options.process = ''
  end
  if(item.processPath and item.processPath ~= "") then
    options.path_expr = item.processPath
    log:debug(" options.path_expr  : ",options.path_expr )
    isValueAvailable = true
  else
    options.path_expr = ''
  end
  if(item.processCwd and item.processCwd ~= "") then
    options.cwd_expr = item.processCwd
    log:debug(" options.cwd_expr  : ",options.cwd_expr )
    isValueAvailable = true
  else
    options.cwd_expr = ''
  end

  if(item.processArgs and item.processArgs ~= "") then
    options.args_expr = item.processArgs
    log:debug(" options.args_expr  : ",options.args_expr )
    isValueAvailable = true
  else
    options.args_expr = ''
  end

  if(isValueAvailable ~= true ) then
    log:debug("Returning nil, isValueAvailable has value : ",isValueAvailable)
    return nil
  end
  log:debug("Processing ahead, isValueAvailable has value :",isValueAvailable)
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
  options.logLevel = item.loglevel or 'error'
  return options
end

local createStats = function(item,index)

  local options = createOptions(item,index)
  if(options ~= nil)then
    return ProcessCpuDataSource:new(options,index)
  else
    return options
  end
end

local createPollers=function(params)
  local polers = PollerCollection:new()
  local index = 1
  for _, item in pairs(params.items) do
    log:debug("Instance"..index..": Setting the log level as : ",{item.loglevel,logger.parseLevel(item.loglevel)} )
    log:setLevel(logger.parseLevel(item.loglevel))
    log:debug("Instance"..index..":Log level set as ",log:getLevel())
    local cs = createStats(item,index)
    if(cs ~= nil) then
      log:debug("Instance"..index..": Creating DataSource poller..")
      local statsPoller = DataSourcePoller:new(notEmpty(tonumber(item.pollInterval),1000), cs)
      polers:add(statsPoller)
    else
      log:error("Instance"..index..": Plugin instance parameters should not be empty, at least one of the parameters is required.")
      Plugin:emitEvent("error","Process: Instance"..index..": Plugin instance parameters should not be empty, at least one of the parameters is required.")
    end
    index = index + 1
  end
  return polers
end

-- Start function to load the host name and run the plugin
local start = function(retryCount)
  if(retryCount <= 2) then

    local socket1 = nil
    local ck = function(data)
      socket1:write('{"jsonrpc":"2.0","id":3,"method":"get_system_info","params":{}}')
    end
    socket1 = net.createConnection(9192, '127.0.0.1', ck)

    socket1:once('error',function(data)
      log:error("Getting system information resulted into error,", json.stringify(data))
      socket1:destroy()
      log:error("Retry "..(retryCount + 1)..": Sleeping for 5 sec before trying again");
      timer.setTimeout(5000, function()
        init(retryCount + 1)
      end)
    end)

    socket1:once('data',function(data)
      local sucess,  parsed = parseJson(data)
      if(parsed and parsed.result and parsed.result.hostname) then
        hostName =  parsed.result.hostname--:gsub("%-", "")
      end
      socket1:destroy()

      if not hostName then
        log:error("Retry "..(retryCount + 1)..": Sleeping for 5 sec before trying again");
        timer.setTimeout(5000, function()
          init(retryCount + 1)
        end)
      else

        -- create the pollers and run the plugin
        pollers = createPollers(params)
        plugin = Plugin:new(params, pollers)
        function plugin:onError(err)
          return err
        end

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
        plugin:run()
        -- plugin run completed
      end
    end)
  else
    log:error("The host name could not be retrieved. Plugin failed to start. Please try restarting the plugin")
    Plugin:emitEvent("error","Process: The host name could not be retrieved. Plugin failed to start. Please try restarting the plugin")
  end
end

function init(c)
  start(c)
end
-- Start the plugin
init(0);