#!/bin/bash

###########################################################
#
# Adding Image to ACR
#
###########################################################
## Image Name
image='sflaunchpoint_image:v1'

## Creating Image
docker build -t $image .

## Container Registry
az.cmd login

read -p 'Please enter subscription id: ' sub_id
az.cmd account set --subscription $sub_id

declare rg="sflaunchpointrg"
declare rglocation="westus"
az.cmd group create --name $rg --location $rglocation

declare acr="sflaunchpointcr"
az.cmd acr create --resource-group $rg --name $acr --sku Basic --admin-enabled true

az.cmd acr login --name $acr
az.cmd acr show --name $acr --query loginServer --output table

loginServer=$acr
loginServer+=".azurecr.io/$image"

docker tag $image $loginServer
docker push $loginServer

# display table 
az.cmd acr repository list --name $acr --output table

###########################################################
#
# Connecting SFLaunchPointApp to ACR
#
###########################################################
password=$( az.cmd acr credential show -n $acr --query passwords[0].value )
echo Open ApplicationManifest.xml and change the following values
echo Account Name: $acr
echo Password: $password
read -p "Hit enter when prepared to continue: " throwaway

###########################################################
#
# Developing a Self-Signed Linux Cluster
#
###########################################################
declare certSubjectName="sflaunchpoint.westus.cloudapp.azure.com"
declare parameterFilePath="$(pwd)/parameters.json"
declare templateFilePath="$(pwd)/template.json"
declare certOutputFolder="/c/certificates"
declare vaultname="sflaunchpointkv"

az.cmd keyvault create --name $vaultname --resource-group $rg --location $rglocation --enabled-for-template-deployment true 
az.cmd sf cluster create --cluster-name "sflaunchpoint" --resource-group $rg --location $rglocation --certificate-output-folder $certOutputFolder --certificate-subject-name $certSubjectName --template-file $templateFilePath --parameter-file $parameterFilePath --vault-name $vaultname --vault-resource-group $rg

###########################################################
#
#  Connect To Cluster
#
########################################################### 
: <<'END'
read -p "name of PFX/PEM (w/o extension):" cert
declare pem_dir="$certOutputFolder/$cert.pem"
declare app_dir="$(pwd)/SFLaunchPointApp/SFLaunchPointApp/ApplicationPackageRoot"

sfctl cluster select --endpoint https://sflaunchpoint.westus.cloudapp.azure.com:19080 --pem $pem_dir --no-verify
sfctl application upload --path $app_dir --show-progress
cd SFLaunchPointApp/SFLaunchPointApp
sfctl application provision --application-type-build-path ApplicationPackageRoot
sfctl application create --app-name fabric:/SFLaunchPointApp --app-type SFLaunchPointAppType --app-version 1.0.2 
END
