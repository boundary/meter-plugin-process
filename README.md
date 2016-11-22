Truesight pulse Process Plugin
---------------------------------

Displays CPU usage (%) & Memory usage (bytes) for specific processes. Uses regular expressions to specify a process name, process full path, and/or the process current working directory. As above, currently only works for Linux based systems.

### Prerequisites

|     OS    | Linux | Windows | SmartOS | OS X |
|:----------|:-----:|:-------:|:-------:|:----:|
| Supported |   v   |    -    |    -    |  -   |


|  Runtime | node.js | Python | Java |
|:---------|:-------:|:------:|:----:|
| Required |    -    |    -   |   -  |


### Plugin Setup
None

#### Plugin Configuration Fields

|Field Name        |Description                                                                                                                                                                                                                                                    |
|:-----------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|Source            |The source to display in the legend for the CPU data.                                                                                                                                                                                                          |
|Process Name Regex|A regular expression to match the name of the process.                                                                                                                                                                                                         |
|Process Path Regex|A regular expression to match the full path of the process.                                                                                                                                                                                                    |
|Process CWD Regex |A regular expression to match the current working directory of the process.                                                                                                                                                                                    |
|Reconcile option  |How to reconcile in the case that multiple processes match.  Set to First Match to use the first matching process, Parent to choose the parent process (useful if process is forked) and Longest running to choose longest running process|

|Collect Cpu Utilization  |A check/uncheck option to active/inactive CPU utilization metrics display .|

|Collect Memory Utilization  |A check/uncheck option to active/inactive Memory Utilization metrics display.|

### Metrics Collected

|Metric Name|Description                     |
|:----------|:-------------------------------|
|CPU Process|Process specific CPU utilization|
|Memory Process|Process specific Memory utilization|



