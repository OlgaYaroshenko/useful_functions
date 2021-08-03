param([string] $subscriptionname, [string] $resourcegroup, [string] $namespace, [string] $action)
az account set --subscription $subscriptionname
Write-Host "Subscription set."
#Check resource group exists
$rgExist = az group exists --resource-group $resourcegroup
if ($rgExist -eq $false) {
    Write-Host "Resource group is invalid or doesn't exist."
    Exit
}
else {
    Write-Host "Resource group found."
}
#Set status
if ($action.ToLower() -eq "off") { 
    $state = "Disabled"
}
else {
    $state = "Enabled"
}
# Turn off/on logic apps
Write-Host "Logic apps started updating."
$resourceType = 'Microsoft.Logic/workflows'
$logicApps = az logic workflow list --resource-group $resourcegroup | ConvertFrom-Json
ForEach ($app in $logicApps) { 
    $logicApp = az logic workflow show --resource-group $app.resourceGroup --name $app.name | ConvertFrom-Json
    az resource update --name $logicApp.name --resource-group $logicApp.resourceGroup --resource-type $resourceType --set properties.state=$state
}
Write-Host "Logic apps finished updating."
#Set status
if ($action.ToLower() -eq "off") {
    $state = "Disabled"
}
else {
    $state = "Active"
}
# Turn off/on topics and subscriptions
Write-Host "Topics and subscriptions started updating."
$topics = az servicebus topic list --resource-group $resourcegroup --namespace-name $namespace | ConvertFrom-Json
ForEach ($topic in $topics) {
    $topicName = $topic.Name
    $subscriptions = az servicebus topic subscription list --resource-group $resourcegroup --namespace-name $namespace --topic-name $topicName  | ConvertFrom-Json
    ForEach ($subscription in $subscriptions) {
        $subName = $subscription.Name
        az servicebus topic subscription update --name $subName --namespace-name $namespace --resource-group $resourcegroup --topic-name $topicName --set status=$state
    }
    az servicebus topic update --resource-group $resourcegroup --namespace-name $namespace --name $topicName --set status=$state
}
Write-Host "Topics and subscriptions finished updating."

#Test example 
#.\disable-enable-la-sb.ps1 "Microsoft Azure Enterprise DEV" "rg-ae-integration-test" "sb-sanford-integration-test" "off"

