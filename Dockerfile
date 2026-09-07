# escape=`
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2022 AS build
WORKDIR C:\src
COPY . .
RUN nuget restore LegacyDatabaseMigrationPOC.sln
RUN msbuild LegacyDatabaseMigrationPOC.sln /p:Configuration=Release /p:DeployOnBuild=true /p:WebPublishMethod=FileSystem /p:publishUrl=C:\publish

FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2022
WORKDIR C:\inetpub\wwwroot
COPY --from=build C:\publish .
