Function Get-ConfigManagerInfo {

	Param (
	
		[string]
		[Parameter( Mandatory = $true )]
		$ComputerName,
		
		[string]
		[Parameter( Mandatory = $true )]
		[ValidatePattern("Staging|UAT|Production")]
		$Environment,
		
		[string]
		[Parameter( Mandatory = $false )]
		$NumResults = 1
		
	)
	
	
	Try {
		Write-Debug "Getting Config Manager Deployment Information..."
		$DeployInfo = Get-CMDeployInfo -ComputerName $ComputerName -Environment $Environment -First $NumResults -Quiet
		
		If ( $DeployInfo -match "False" ) { $DeployInfo.Application = "-" }
		
		return $DeployInfo.Application
	}
	
	Catch { $_ ; break }
}