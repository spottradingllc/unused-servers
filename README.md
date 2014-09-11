Get Unused Servers

Get-UnusedServers uses Graphite, Salt and Zookeeper to determine which servers are not being used.

.Description

Get-UnusedServers uses data that collectl and custom python script send to Graphite to determine which servers are not being 
used and can be re-used. The process is outlined below:

1. Collectl sends data (CPU, Network and Disk utilizations) to Graphite server.

2. Python script is scheduled (with Salt) to run on all Linux servers to send number of logins on the server during the day to Graphite. It is very important to understand that 'root' login is not counted as active login. Script assumes that we always use domain accounts to login and manage our servers (including running our services under domain user accounts).

3. The script then gets average nettotals.kbout below 3 KB for all servers and selects first 100 servers with lowest average value among the entire dataset for the last 29 days.

4. Then the script determines if these 100 servers also exist in lowest average CPU dataset (average CPU utilization below 2%)and lowest average Logins dataset (maximum below 0.001 logins during 29 days).

5. If the server does not exist in CPU or Logins dataset it is declared as false positive and nothing else is done for this particular server.

6. If the server does exist in all 3 datasets than it is declared unused.

7. Based on the script parameters the following actions will take place:

a. The script determines properties of the server in question by using Salt (CPU, hardware, OS, kernel version etc.)

b. OS and kernel versions match our standard (<your linux version> with <your kernel>):

	If this is a physical server and we declare that this server is ready to be reused as it is in compliance with our standard.

	If this is a virtual machine – we shut it down and rename to make sure VM is deleted by automated process after two weeks of being shut down.

c. If OS and kernel do not match our standard:

	Physical server – we display it in a different section of the report stating that the server must be rebuild with our standard 
	OS before it can be used again.

	Virtual machine - we shut it down and rename to make sure VM is deleted by automated process after two weeks of being shut down.

d. If server does not respond to pings we determine that it was either rebuild or decommissioned and we delete its data from graphite and salt so next time it does not appear in the results or we just mention this in the result without doing anything.

Get-UnusedServers supports exceptions to make sure we do not take servers that are being used. Zookeeper is being used to keep these exceptions.

Get-UnusedServers also supports three different methods of output – console, email or quiet (so we can use output in other script, like Create-VM).

Get-UnusedServers also supports claiming servers as being used to make sure nobody else takes that server if we decided to use it.

.Parameter DeprecateVMs

	Denotes whether to shut down virtual machines and rename them so another script can decommission them after two weeks of being offline.
	This will also create Jira tickets for change tracking.

.Parameter ClaimServer

	Denotes whether we want to claim a server as being used to start using it. This will use Salt API to login to the server with the special account. This way number oflogins will be more than our set threshold and the server will no longer appear in the report of unused servers (for the next 29 days). If the server isnot being used after 29 days it will go back to the list of unused servers.

.Parameter AddException

	Allows us to add exception for the server so it will be skipped during unused servers script logic. It requires Description parameter.

.Parameter Description

	Provides description for the exception. Needs to be enclosed in quotes.

.Parameter RemoveException

	Allows us to remove exception for the server.

.Parameter ListExceptions

	Allows us to list current exceptions.

.Parameter Email

	Denotes whether to send results in the email (good for automated processes). 

.Parameter Quiet

	Denotes whether to display any errors or format results – good for other scripts to use output for processing.

.Parameter Environment

	Denotes environment we work with. Can be Staging, UAT or Production. Default value is Staging.

.Example

	Get-UnusedServers -Environment Staging

	This will display all unused servers in Staging environment but will not clean Graphite, Salt or shut down virtual machines.

.Example

	Get-UnusedServers -Environment Production -DeprecateVMs –Email

	This will send email report with all unused servers and also shutdown and rename all unused virtual machines. 
	It will also delete all Graphite and Salt data for the servers that do not respond to pings.
	Jira tickets will also be created for VMs shutdown, renaming and for removing Graphite and Salt data.

.Example

	Get-UnusedServers -ClaimServer TestServer01

	Claims TestServer01 as being used so it will not appear in the report next time.

.Example

	Get-UnusedServers -AddException TestServer02 -Description “Test server” -Environment Staging

	This will add TestServer02 with the description “Test server” to the list of the exceptions so this server will be skipped by the Get-UnusedServers logic.

.Example

	Get-UnusedServers -RemoveException TestServer02 -Environment Staging

	This will remove TestServer02 from the list of exceptions in Staging.

.Example

	Get-UnusedServers –ListExceptions –Environment UAT

	This will list all exceptions in UAT environment.

To Do:

1. Start reading configuration from config file instead of hardcoding values in the script
2. Better email formatting
