#!/bin/bash

if [[ !("$#" -eq 2) ]]; 
    then echo "Parameters are missing!" >&2
    exit 1
fi

# Parameters
resource_group_name=$1
vm_name=$2

# Variables
#storage_account_name="storacc5708344063db4d"
storage_account_name="storacc$(cat /proc/sys/kernel/random/uuid | sed 's/\-//g' | cut -c 1-14)"
image_path="images/malmo-image.vhd"

echo "Creating resource group: $resource_group_name"
az group create -n $resource_group_name -l "westeurope"

echo "Creating storage account: $storage_account_name"
az storage account create -n $storage_account_name -g $resource_group_name --sku "Standard_LRS" -l "westeurope"

storage_account_key=$(az storage account keys list -n $storage_account_name -g $resource_group_name --query [0].value --output tsv)

echo "Creating container..."
az storage container create -n "vhds" \
	--account-key $storage_account_key \
        --account-name $storage_account_name 

echo -ne "Copying VHD image..."
az storage blob copy start \
        --destination-blob $image_path \
        --destination-container "vhds" \
        --account-key $storage_account_key \
        --account-name $storage_account_name \
        --source-uri https://malmostorage.blob.core.windows.net/system/Microsoft.Compute/Images/malmo/malmo-v1-osDisk.007fdb63-151d-4119-82d7-9ffcab3aec5b.vhd

status="\"pending\""
while [ "$status" == "\"pending\"" ]; do
     status=$(az storage blob show \
	        --name $image_path \
	        --container-name "vhds" \
	        --account-name $storage_account_name \
                --query "properties.copy.status")
     echo -ne "."           
     sleep 10
done

#status="\"success\""
if [ "$status" == "\"success\"" ]; then
        # Add your code here to create VM
        az group deployment create \
                --name "InitalMalmoDeploy" \
                --resource-group $resource_group_name \
                --template-file "azuredeploy.json" \
                --parameters "{\"virtualMachineName\": {\"value\": \"$vm_name\"}, \"storageAccountName\":{\"value\": \"$storage_account_name\"}, \"imagePath\":{\"value\": \"$image_path\"}}"
        echo "Done!!!"
else
        echo -e "\nSome problems occured during copying!"
        echo "Status:$status"
fi
