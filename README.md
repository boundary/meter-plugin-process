Truesight pulse Process Plugin
---------------------------------

Displays CPU usage (%) & Memory usage (bytes) for specific processes. Uses regular expressions to specify a process name, process full path,process arguments,or process current working directory .

### Prerequisites

|     OS    | Linux | Windows | SmartOS | OS X |
|:----------|:-----:|:-------:|:-------:|:----:|
| Supported |   v   |    v    |    v    |  v   |



### Plugin Setup

#### Plugin Configuration Fields

|Field Name        |Description                                                                                                                                                                                                                                                    |
|:-----------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|Source            |The source to display in the legend for the CPU data.|
|Process Parameter Option|Parameter option for matching process. Parameter can be any of name/path/cwd/args regex. Choose the parameter option as Process Name Regex, Process Path Regex, Process CWD Regex or Process Args Regex |
|Process Parameter Value|A regular expression to match the chosen Param Option(name/path/cwd/args) of the process.                                                                                               |
|Reconcile option  |How to reconcile in the case that multiple processes match.  Set to First Match to use the first matching process, Parent to choose the parent process (useful if process is forked) and Longest running to choose longest running process                                                              |
|Polling Interval |Polling value in milisecond (ex 1000 for 1sec) |
|Collect Cpu Utilization  |A check/uncheck option to active/inactive CPU utilization metrics display .|
|Collect Memory Utilization  |A check/uncheck option to active/inactive Memory Utilization metrics display.|

### Metrics Collected

|Metric Name|Description                     |
|:----------|:-------------------------------|
|CPU Process|Process specific CPU utilization|
|Memory Process|Process specific Memory utilization|



