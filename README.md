TrueSight Pulse Process Plugin
---------------------------

Displays CPU usage (%) & Memory usage (bytes) for specific processes. Uses regular expressions to specify a process name, process full path, the process current working directory and/or process arguments .

### Prerequisites

|     OS    | Linux | Windows | SmartOS | OS X |
|:----------|:-----:|:-------:|:-------:|:----:|
| Supported |   v   |    v    |    v    |  v   |


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
|Reconcile option  |How to reconcile in the case that multiple processes match.  Set to First Match to use the first matching process, Parent to choose the parent process (useful if process is forked), or Longest Running to pick the process that has been running the longest.|
|                   |* You should input at least one of the marked fields, all of the fields cannot be empty.                                                                                                                                                                                                    |

### Metrics Collected

|Metric Name   |Description                                                             |
|:-------------|:-----------------------------------------------------------------------|
|CPU Process   |Process specific CPU utilization                                        |
|Memory Process|Process specific Memory utilization                                     |
