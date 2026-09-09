# Non-secret backend settings, used via: terraform init -backend-config=backend.hcl
# Auth to the storage account itself comes from ARM_* env vars set in the
# GitHub Actions workflow, not from anything in this file.
#
# You already have a resource group named rg-tfstate -- reuse it here.
# CHANGE storage_account_name to a real, globally-unique storage account you
# create once (see README-CICD.md step 1) inside rg-tfstate.

resource_group_name  = "rg-tfstate"
storage_account_name = "CHANGE-ME-tfstateacct"
container_name        = "tfstate"
key                    = "legacydbmig-dev.tfstate"
