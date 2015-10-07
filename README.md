# Unused Servers

UnusedServers module is used to automatically discover `unused` physical or virtual servers (`VMware` or `AWS`) in the infrastructure. 

Module will deprecate virtual machines but shutting them down and renaming to `<original name>-<Year><Month><Day>` so another script can delete them in two weeks.

Physical servers will only be displayed so it is easy to re-claim them if need to.

Module can send output to console as well as send HTML email reports for further analysis.

**[Find more information about this in our blog!](http://www.spottradingllc.com/automating-the-discovery-and-decommissioning-of-servers-with-open-source-tools-saltstack-graphite-zookeeper-and-collectl/)**

Please visit our **[wiki pages](https://github.com/spottradingllc/unused-servers/wiki)** for usage details.

# Hard Requirements

1. [Graphite](https://github.com/graphite-project)
2. [Salt](https://github.com/saltstack/salt)
3. VMware 5.0 or later
4. PowerShell 5.0 (beta for now)
5. Any method of getting CPU `usertime` and network `kbout` stats into Graphite. We recommend [collectl](http://collectl.sourceforge.net/)
6. [Scripts to get login information from Linux and Windows to Graphite](https://github.com/spottradingllc/get-logins-to-graphite)
7. Spot-Cloud PowerShell module (will be open sourced soon)
8. [Spot-Graphite PowerShell module](https://github.com/spottradingllc/Spot-Graphite)
9. [Spot-Salt PowerShell module](https://github.com/spottradingllc/Spot-Salt)
10. [AWS PowerShell module](https://aws.amazon.com/powershell/)

# Soft Requirements

1. AWS account 
2. Salt Cache (soon to be opened sourced)
3. [Apache Zookeeper](http://zookeeper.apache.org/)
4. [Netflix Exhibitor](https://github.com/Netflix/exhibitor)
5. [Spot Trading Zoom](https://github.com/spottradingllc/zoom)
6. [Jira](https://www.atlassian.com/software/jira/)
7. [Spot-Jira PowerShell module](https://github.com/spottradingllc/Spot-Jira)

# Installation

1. Determine PowerShell modules directory you want to use (type `$env:PSModulePath` and chose one, for example `c:\Windows\system32\WindowsPowerShell\v1.0\Modules`).
2. Download repo and place all files under Modules directory you chose in the first step into `UnusedServers` folder (`c:\Windows\system32\WindowsPowerShell\v1.0\Modules\UnusedServers`).
3. Make sure the files are not blocked. Right click on the files and un-block them by going into properties.
4. Rename *UnusedServers-config-example.xml* configuration file to *UnusedServers-config.xml*.
5. Make sure to set your PowerShell Execution Policy to `RemoteSigned`, for example `Set-ExecutionPolicy RemoteSigned -Force`.
6. Type `Get-Module -ListAvailable` and make sure you see UnusedServers module in the list
7. Type `help Get-UnusedServers -Detailed` to get detailed information about how to use the module
