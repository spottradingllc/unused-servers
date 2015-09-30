{%- if grains['osrelease'] == '2003Server' %}
   {%- set event = '528' %}
   {%- set name = 'User' %}
{%- else %}
   {%- set event = '4624' %}
   {%- set name = 'Account' %}
{%- endif -%}

Import-Module Spot-Graphite

$Logs_Dir = Test-Path C:\Utilities\PSScripts\Logs

If (! $Logs_Dir ) { New-Item -Type Directory C:\Utilities\PSScripts\Logs }

Try {
	$ComputerName = ((Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName ComputerName).ComputerName).ToUpper()

	$Logons = Get-EventLog -LogName Security -InstanceId {{ event }} -After "12:00AM" -ErrorAction SilentlyContinue

	$Logons_Number = $Logons | ? { $_.Message -match "Logon Type:.*(2|4|5|10)" -and $_.Message -notmatch "{{ name }} Name:.*(LOCAL SERVICE|NETWORK SERVICE|SYSTEM|svc\.saltmaster|Andrew\.Girin|spotcitrixuser|svc\.python|Administrator|AdminiSpoter|DWM)"}
	
	$Logons_Number = ( $Logons_Number | Measure-Object ).Count

	$Metric_Time = Get-Date

	$Graphite = "{{ salt['pillar.get']('globals:graphite') }}"

	$CustomPath = "$ComputerName.logins.count"

	Send-ToGraphite -CustomPath $CustomPath -Value $Logons_Number -Time $Metric_Time -GraphiteServer $Graphite | Tee-Object C:\Utilities\PSScripts\Logs\logons_to_graphite.log
}

Catch {
	$_
    Write-Output "Security Log is corruped" | Tee-Object C:\Utilities\PSScripts\Logs\logons_to_graphite.log
    Clear-EventLog -LogName Security
    net stop logstash ; net start logstash
}