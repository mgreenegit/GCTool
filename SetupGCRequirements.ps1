# Name of the resource group in scope
$RG = 'resourcegroupname'

# Information about the configuration assignment
$GC = new-object -TypeName PSObject -Property @{
    kind = $null
    name = 'configurationname'
    version = '1.*'
    configurationParameter = {}
    configurationSetting = $null
}

# Remove and reinstall the extension if it exists
$ResetExtension = $false

# Scope of VM's
$vmScope = Get-AzVM -ResourceGroupName $RG

foreach ($VM in $vmScope) {
    # Deploy guest assignment if not present
    $GA = Get-AzResource –ResourceGroupName $RG `
        –ResourceType "Microsoft.Compute/virtualMachines/providers/guestConfigurationAssignments/$($GC.Name)" `
        –ResourceName "$($VM.Name)/Microsoft.GuestConfiguration" `
        -ApiVersion '2018-11-20'
    if ($null -eq $GA) {
        New-AzResource –ResourceGroupName $RG `
            –ResourceType "Microsoft.Compute/virtualMachines/providers/guestConfigurationAssignments/$($GC.Name)" `
            –ResourceName "$($VM.Name)/Microsoft.GuestConfiguration" `
            -Location $VM.Location `
            -Properties @{guestConfiguration = $GC} `
            -ApiVersion '2018-11-20' -Force
    }

    # Add System MSI if not present
    $Id = $VM.Identity | ? Type -eq 'SystemAssigned'
    if ($null -eq $Id) {
        Update-AzVM -ResourceGroupName $RG -VM $VM -AssignIdentity:$SystemAssigned
    }

    # Deploy Extension if not present (reset if control variable is set to true)
    $OS = if ($null = $VM.OSProfile.Windows) {'Linux'} else {'Windows'}
    $Ext = Get-AzVMExtension -ResourceGroupName $RG -VMName $VM.Name -Name "AzurePolicyfor$OS"
    if ($null -ne $Ext -AND $ResetExtension -eq $true) {
        Remove-AzVMExtension -ResourceGroupName $RG -VMName $VM.Name -Name "AzurePolicyfor$OS" -Force
    }
    if ($null -eq $Ext) {
        Set-AzVMExtension -ResourceGroupName $RG -VMName $VM.Name -Location $VM.Location`
            -Publisher 'Microsoft.GuestConfiguration' `
            -ExtensionType "Configurationfor$OS" `
            -Name "AzurePolicyFor$OS"
    }
}
