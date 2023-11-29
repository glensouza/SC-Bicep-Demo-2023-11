targetScope = 'resourceGroup'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Base Name of Resources')
param commonResourceName string = 'gsorservicebusdemo'
var resourceName = toLower(commonResourceName)

var logAnalyticsName = '${resourceName}log'
var logAnalyticsSKU = 'PerGB2018'
var applicationInsightsName = '${resourceName}insights'

var keyvaultName = '${resourceName}keyvault'
var keyVaultSecretsUserRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

var serviceBusNamespaceName = '${resourceName}sb'
var serviceBusConnectionString = listKeys('${serviceBusNamespace.id}/AuthorizationRules/RootManageSharedAccessKey', serviceBusNamespace.apiVersion).primaryConnectionString
var serviceBusSkuName = 'Basic'
var deadLetterQueueName = 'deadletter'
var serviceBusQueueNames = [
  'fromfunction'
  'fromconsole'
]

var storageSKU = 'Standard_LRS'
var storageAccountName = '${resourceName}sa'
var storageAccountConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
var storageBlobDataContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '17d1049b-9a84-46fb-8f53-869881c3d3ab')

var appServicePlanFuncName = '${resourceName}funcasp'
var appServicePlanFuncSKU = 'Y1'
var appServicePlanFuncTier = 'Dynamic'
var functionAppName = '${resourceName}func'

var appServicePlanWebName = '${resourceName}webasp'
var appServicePlanWebSKU = 'B1'
var webAppName = '${resourceName}web'
var webLinuxFxVersion = 'DOTNETCORE|7.0'

var swaSku = 'Free'
var webAppNameViewer = '${resourceName}swa'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespaceName
  location: location
  sku: {
    name: serviceBusSkuName
  }

  resource deadLetterFirehoseQueue 'queues@2018-01-01-preview' = {
    name: deadLetterQueueName
    properties: {
      requiresDuplicateDetection: false
      requiresSession: false
      enablePartitioning: false
    }
  }

  resource queues 'queues@2018-01-01-preview' = [for queueName in serviceBusQueueNames: {
    name: queueName
    dependsOn: [
      deadLetterFirehoseQueue
    ]
    properties: {
      forwardDeadLetteredMessagesTo: deadLetterQueueName
      lockDuration: 'PT1M'
      maxSizeInMegabytes: 1024
      requiresDuplicateDetection: false
      requiresSession: false
      defaultMessageTimeToLive: 'P10D'
      deadLetteringOnMessageExpiration: true
      duplicateDetectionHistoryTimeWindow: 'PT10M'
      maxDeliveryCount: 10
      enablePartitioning: false
      enableExpress: false
      enableBatchedOperations: true
      status: 'Active'
    }
  }]
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageSKU
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
        queue: {
          enabled: true
        }
        table: {
          enabled: true
        }
      }
    }
  }
}

resource storageFunctionAppPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccount.id, functionAppName, storageBlobDataContributorRole)
  scope: storageAccount
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: storageBlobDataContributorRole
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: logAnalyticsSKU
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: logAnalytics.id
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyvaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enabledForDeployment: false
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: false
    sku: {
      family: 'A'
      name: 'standard'
    }
  }

  resource storageAccountConnectionStringSecret 'secrets' = {
    name: 'storageAccountConnectionString'
    properties: {
      value: storageAccountConnectionString
    }
  }
  
  resource serviceBusConnectionStringSecret 'secrets' = {
    name: 'serviceBusConnectionStringString'
    properties: {
      value: listKeys('${serviceBusNamespace.id}/AuthorizationRules/RootManageSharedAccessKey', serviceBusNamespace.apiVersion).primaryConnectionString
    }
  }
}

resource keyVaultFunctionAppPermissions 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyVault.id, functionAppName, keyVaultSecretsUserRole)
  scope: keyVault
  properties: {
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: keyVaultSecretsUserRole
  }
}

resource appServicePlanFunc 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanFuncName
  location: location
  sku: {
    name: appServicePlanFuncSKU
    tier: appServicePlanFuncTier
  }
  properties: {}
}

resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanFunc.id
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      netFrameworkVersion: 'v6.0'
    }
    httpsOnly: true
  }

  resource functionAppConfiguration 'config' = {
    name: 'appsettings'
    properties: {
      apiLocation: 'https://${webApp.properties.defaultHostName}'
      AzureWebJobsStorage: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVault::storageAccountConnectionStringSecret.name})'
      APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
      FUNCTIONS_WORKER_RUNTIME: 'dotnet'
      FUNCTIONS_EXTENSION_VERSION: '~4'
      ServiceBusConnectionString: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=${keyVault::serviceBusConnectionStringSecret.name})'
    }
    dependsOn: [
      storageFunctionAppPermissions
      keyVaultFunctionAppPermissions
    ]
  }  
}

resource appServicePlanWeb 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanWebName
  location: location
  sku: {
    name: appServicePlanWebSKU
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2022-03-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  properties: {
    serverFarmId: appServicePlanWeb.id
    siteConfig: {
      linuxFxVersion: webLinuxFxVersion
      ftpsState: 'FtpsOnly'
      appSettings: [
        {
          name: 'ServiceBusConnectionString'
          value: serviceBusConnectionString
        }
      ]
    }
    httpsOnly: true
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource webReceiverApp 'Microsoft.Web/staticSites@2020-12-01' = {
  name: webAppNameViewer
  location: location
  sku: {
    name: swaSku
    size: swaSku
  }
  properties: {}

  resource staticWebAppAppSettings 'config' = {
    name: 'appsettings'
    properties: {
      APPINSIGHTS_INSTRUMENTATIONKEY: applicationInsights.properties.InstrumentationKey
      apiLocation: 'https://${webApp.properties.defaultHostName}'
    }
  }
}
