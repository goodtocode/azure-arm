@minLength(1)
@maxLength(64)
@description('The name of the virtual machine resource. 1-64 characters.')
param name string

@minLength(1)
@maxLength(15)
@description('The guest OS computer name. 1-15 characters (Windows NetBIOS limit).')
param computerName string

@description('The Azure region where the virtual machine will be deployed.')
param location string = resourceGroup().location

@description('Tags to apply to the virtual machine.')
param tags object = {}

@minLength(1)
@description('Virtual machine size, for example Standard_D2s_v5.')
param size string

@allowed([
  'Windows11'
  'Windows10'
  'WindowsServer2022'
  'Ubuntu2204'
])
@description('Guest operating system image. Windows11 and Windows10 are client desktop images and require Windows client licensing.')
param os string

@minLength(1)
@maxLength(20)
@description('Local administrator user name.')
param adminUsername string

@secure()
@description('Local administrator password.')
param adminPassword string

@minLength(1)
@description('Resource ID of the network interface to attach.')
param nicId string

@allowed([
  'Standard_LRS'
  'StandardSSD_LRS'
  'Premium_LRS'
])
@description('OS disk SKU.')
param osDiskSku string = 'StandardSSD_LRS'

@description('Enable Trusted Launch (secure boot and vTPM).')
param trustedLaunch bool = false

@description('Enable encryption at host for temp disks and caches. Requires the EncryptionAtHost feature on the subscription.')
param encryptionAtHost bool = false

@description('Install the Microsoft Entra ID login extension and assign a system-managed identity.')
param entraLogin bool = false

var images = {
  Windows11: {
    publisher: 'MicrosoftWindowsDesktop'
    offer: 'windows-11'
    sku: 'win11-23h2-pro'
    version: 'latest'
  }
  Windows10: {
    publisher: 'MicrosoftWindowsDesktop'
    offer: 'windows-10'
    sku: 'win10-22h2-pro-g2'
    version: 'latest'
  }
  WindowsServer2022: {
    publisher: 'MicrosoftWindowsServer'
    offer: 'WindowsServer'
    sku: '2022-datacenter-azure-edition'
    version: 'latest'
  }
  Ubuntu2204: {
    publisher: 'Canonical'
    offer: '0001-com-ubuntu-server-jammy'
    sku: '22_04-lts-gen2'
    version: 'latest'
  }
}
var isWindows = startsWith(os, 'Windows')

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: name
  location: location
  tags: empty(tags) ? null : tags
  identity: entraLogin ? {
    type: 'SystemAssigned'
  } : null
  properties: {
    hardwareProfile: {
      vmSize: size
    }
    storageProfile: {
      imageReference: images[os]
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskSku
        }
      }
    }
    osProfile: {
      computerName: computerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: isWindows ? null : {
        disablePasswordAuthentication: false
      }
    }
    securityProfile: {
      encryptionAtHost: encryptionAtHost
      securityType: trustedLaunch ? 'TrustedLaunch' : null
      uefiSettings: trustedLaunch ? {
        secureBootEnabled: true
        vTpmEnabled: true
      } : null
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicId
        }
      ]
    }
  }
}

resource aadLogin 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = if (entraLogin) {
  parent: vm
  name: 'AADLogin'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: isWindows ? 'AADLoginForWindows' : 'AADSSHLoginForLinux'
    typeHandlerVersion: isWindows ? '2.0' : '1.0'
    autoUpgradeMinorVersion: true
  }
}

@description('Resource ID of the virtual machine.')
output id string = vm.id

@description('Name of the virtual machine.')
output name string = vm.name
