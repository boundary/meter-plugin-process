TrueSight Pulse Process Plugin
-------------------------------

Displays CPU usage (%), Memory usage (bytes), Open Handles & No of Processes for specific processes. Uses regular expressions to specify a process name, process full path, the process current working directory and/or process arguments .

Note: This plugin replaces the plugins [Process CPU Plugin](https://help.truesight.bmc.com/hc/en-us/articles/202671821-Process-CPU-Plugin) & [Process Memory Plugin](https://help.truesight.bmc.com/hc/en-us/articles/202671861-Process-Memory-Plugin).

### Prerequisites

|     OS    | Linux | Windows | OS X |
|:----------|:-----:|:-------:|:----:|
| Supported |   v   |    v    |  v   |


### Plugin Setup

#### Plugin Configuration Fields
|Field Name        |Description                                                                                                                                                                                                                                                    |
|:-----------------|:--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|Source            |The source to display in the legend for the CPU & Memory data.                                                                                                                                                                                                          |
|Process Name Regex*|A regular expression to match the name of the process.                                                                                                                                                                                                         |
|Process Path Regex*|A regular expression to match the full path of the process.                                                                                                                                                                                                    |
|Process CWD Regex* |A regular expression to match the current working directory of the process.                                                                                                                                                                                    |
|Process Args Regex*|A regular expression to match the arguments of the process.                                                                                                                                                                                                    |
|Polling Interval|A numeric value representing polling interval time in miliseconds (ex 1000 for 1 Sec).                                                                                                                                                                                                    |
|Reconcile option  |How to reconcile in the case if multiple processes match.  Set to All Source Average to use the average of matching processes, All Individual Source to use each process individually, First Match to use the first matching process, Parent to choose the parent process (useful if process is forked), or Longest Running to pick the process that has been running the longest.|
|Logging Level  |Logging level for plugin                                                                                                                                                                                                   |
|                   |* You should input at least one of the marked fields, all of the fields cannot be empty.                                                                                                                                                                                                    |

### Metrics Collected

|Metric Name   |Description                                                             |
|:-------------|:-----------------------------------------------------------------------|
|CPU Process   |Process specific CPU utilization                                        |
|Memory Process|Process specific Memory utilization                                     |
|Open Handles  |Process specific Open Handles                                           |
|Process Count |No of processes running                                                 |