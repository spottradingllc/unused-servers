Function Get-TableSpacing {

	Param (
	
		[array]
		[Parameter( Mandatory = $true )]
		$Data
	)

	Write-Debug "Getting max length for different table fields..."

	$v = @{}
	
	$Spaces = 1
				
	If ( $Data.ZoomInfo ) { 
		
		$v.ZoomMax = ($Data.ZoomInfo | % { $_.Length } | Measure-Object -Maximum).Maximum + $Spaces 
		If ( $v.ZoomMax -lt 8 ) { $v.ZoomMax = 9 }
	}
	
	If ( $Data.ConfigManagerInfo ) { 
	
		$v.CMMax = ($Data.ConfigManagerInfo | % { $_.Length } | Measure-Object -Maximum).Maximum + $Spaces 
		If ( $v.CMMax -lt 17 ) { $v.CMMax = 18 }
	}
	
	If ( $Data.VMwareInfo ) { 
	
		$v.VMwareMax = ($Data.VMwareInfo | % { $_.Length } | Measure-Object -Maximum).Maximum + $Spaces
		If ( $v.VMwareMax -lt 10 ) { $v.VMwareMax = 11 }
	}
	
	If ( $Data.AWSInfo ) { 
	
		$v.AWSMax = ($Data.AWSInfo | % { $_.Length } | Measure-Object -Maximum).Maximum + $Spaces
		If ( $v.AWSMax -lt 7 ) { $v.AWSMax = 8 }
	}
				
	If ( $Data.ComputerName ) { 
	
		$v.ServerMax = ($Data.ComputerName | % { $_.Length } | Measure-Object -Maximum).Maximum + $Spaces
		If ( $v.ServerMax -lt 6 ) { $v.ServerMax = 7 }
	}
	
	If ( $Data.OS ) { 
	
		$v.OSMax = ($Data.OS | % { $_.Length } | Measure-Object -Maximum).Maximum + $Spaces 
		If ( $v.OSMax -lt 2 ) { $v.OSMax = 3 }	
	}
	If ( $Data.Model ) { 
	
		$v.ModelMax = ($Data.Model | % { $_.Length } | Measure-Object -Maximum).Maximum + $Spaces 
		If ( $v.ModelMax -lt 5 ) { $v.ModelMax = 6 }		
	}
	
	If ( $Data.SerialNumber ) { 
	
		$v.SNMax = ($Data.SerialNumber | % { $_.Length } | Measure-Object -Maximum).Maximum + $Spaces 
		If ( $v.SNMax -lt 8 ) { $v.SNMax = 9 }
	}
		
	return $v
}