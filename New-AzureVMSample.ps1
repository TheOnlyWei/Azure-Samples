# This sample creates a VM in Azure that the user can access from the internet using the given credentials passed in from the parameters.

param(
    # Admin username for accessing your VM.
    [Parameter(Mandatory=$true)]
    [string]$VMAdminName,
    # Admin password for accessing your VM.
    [Parameter(Mandatory=$true)]
    [Security.SecureString]$VMPassword,
    # Location of your environment.
    [string]$LocationName
)

# General configuration and name options for VM and related resources.
$Credential = New-Object System.Management.Automation.PSCredential ($VMAdminName, $VMLocalAdminSecurePassword)
$ResourceGroupName = "azurestack-vm-sample"
$ComputerName = "windows2016"
$VMName = "windows2016"
# See https://docs.microsoft.com/en-us/azure/virtual-machines/sizes-previous-gen for list of VM sizes.
$VMSize = "Standard_A3"
$NetworkName = "azurestack-Net"
$NICName = "azurestack-NIC"
$SubnetName = "azurestack-Subnet"
$SubnetAddressPrefix = "10.0.0.0/24"
$VnetAddressPrefix = "10.0.0.0/16"
$availSet = "avail-set-0"
$securityGroupName = "azurestack-nsg"

$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet -Force
$securityGroup = Get-AzNetworkSecurityGroup -Name $securityGroupName -ResourceGroupName $ResourceGroupName
if ($null -eq $securityGroup)
{
    $rdpRule = New-AzNetworkSecurityRuleConfig -Name rdp-rule `
        -Description "Allow RDP" `
        -Access Allow `
        -Protocol Tcp `
        -Direction Inbound `
        -Priority 100 `
        -SourceAddressPrefix Any `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 3389
    $securityGroup = New-AzNetworkSecurityGroup -Name $securityGroupName -ResourceGroupName $ResourceGroupName -Location $LocationName -SecurityRules $rdpRule
}

$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -NetworkSecurityGroupId $securityGroup.Id -Force

# Add public IP address with New-AzPublicIpAddress:
$publicIpName = "azurestack-pubip"
$publicIp = New-AzPublicIpAddress -Name $publicIpName -ResourceGroupName $ResourceGroupName -AllocationMethod Static -DomainNameLabel "azurestackazaccount2" -Location $LocationName -Force
$NIC = Get-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName
$NIC.IpConfigurations[0].PublicIpAddress = $publicIp
Set-AzNetworkInterface -NetworkInterface $NIC

New-AzAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $availSet  -Location $LocationName -Sku Aligned -PlatformFaultDomainCount 2
$AvailabilitySet = Get-AzAvailabilitySet -ResourceGroupName $ResourceGroupName -Name $availSet 
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetID $AvailabilitySet.Id
$VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
$VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id
# Get list of publishers using Get-AzVMImagePublisher
# Get list of offers using Get-AzVMImageOffer
# Get list of skus using Get-AzVMImageSku
$VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2016-Datacenter' -Version latest

# Finally, create the VM.
New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose -debug