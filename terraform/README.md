# Terraform for LegacyDatabaseMigrationPOC

Infrastructure-as-code for [ilyas-kazi/LegacyDatabaseMigrationPOC](https://github.com/ilyas-kazi/LegacyDatabaseMigrationPOC),
a .NET Framework 4.8 / ASP.NET MVC 5.2.9 app used to test MSSQL → PostgreSQL
migration compatibility via Entity Framework 6.

The app's `Web.config` currently points `AppDbConnection` at a local SQL
Server instance. This Terraform stack stands up cloud infrastructure so the
app can run somewhere real and be tested against both a SQL Server (the
legacy source) and a PostgreSQL server (the migration target) side by side.

## What gets created

| Module | Resource | Why |
|---|---|---|
| `modules/resource-group` | Resource Group | Container for everything below |
| `modules/app-service` | Windows App Service Plan + Web App | .NET Framework 4.8 requires the Windows App Service stack (not Linux/.NET Core) |
| `modules/sql-server` | Azure SQL logical server + database | The legacy MSSQL source, matches `Initial Catalog=LegacyDatabaseMigrationPOC` in `Web.config` |
| `modules/postgresql` | Azure Database for PostgreSQL Flexible Server + database | The migration target being validated |
| `modules/key-vault` | Key Vault + secrets | Stores generated DB passwords and connection strings; readable by the Web App's managed identity |

`envs/dev` is the root/environment module that wires the five modules
together with sensible POC-sized defaults (Basic SQL tier, B1 App Service
Plan, Burstable Postgres tier). Copy it to `envs/test` or `envs/prod` and
adjust SKUs/tags for other environments.

## Layout

```
terraform/
├── modules/
│   ├── resource-group/
│   ├── app-service/
│   ├── sql-server/
│   ├── postgresql/
│   └── key-vault/
└── envs/
    └── dev/
        ├── providers.tf
        ├── variables.tf
        ├── main.tf
        ├── outputs.tf
        └── terraform.tfvars.example
```

## Usage

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
# edit terraform.tfvars: region, admin usernames, your IP for firewall access

terraform init
terraform plan  -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
```

Requires an authenticated `az login` session (or `ARM_*` environment
variables / a service principal) since the `azurerm` provider uses your
Azure CLI context by default.

After `apply`, useful values are in the outputs:

```bash
terraform output web_app_url
terraform output sql_server_fqdn
terraform output postgres_server_fqdn
```

## Notes / next steps

- **Passwords** are auto-generated with `random_password` and stored in Key
  Vault — they're never written to `.tf` files. Pull them with
  `terraform output -raw` or read them from Key Vault; avoid printing them
  in CI logs.
- **State**: this example uses local state. For anything beyond a solo POC,
  uncomment the `backend "azurerm"` block in `providers.tf` and point it at
  a storage account you provision separately.
- **Deploying the app itself**: these modules provision infrastructure only.
  Publish the `LegacyDatabaseMigrationPOC.csproj` build output to the Web App
  (e.g. `az webapp deploy` or a CI/CD pipeline) — `WEBSITE_RUN_FROM_PACKAGE`
  is already set to expect a zip-deploy package.
  Because the Web App's connection strings are set via Terraform, they will
  override whatever's baked into `Web.config` at deploy time.
- **Networking**: firewall rules currently allow "any Azure service" plus
  whatever IPs you list in `allowed_client_ips`. For a tighter setup, drop
  `allow_azure_services`, put the App Service on VNet integration
  (`vnet_integration_subnet_id` on the app-service module), and add private
  endpoints to the two database modules.
- **Cost**: defaults (B1 App Service, Basic SQL, Burstable Postgres) are
  picked to be cheap for a POC, not production-sized.
