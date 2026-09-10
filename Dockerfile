# escape=`
FROM mcr.microsoft.com/dotnet/framework/sdk:4.8-windowsservercore-ltsc2022 AS build
WORKDIR C:\src
COPY . .
RUN nuget restore LegacyDatabaseMigrationPOC.sln
RUN msbuild LegacyDatabaseMigrationPOC.csproj /p:Configuration=Release /p:VisualStudioVersion=17.0

FROM mcr.microsoft.com/dotnet/framework/aspnet:4.8-windowsservercore-ltsc2022
WORKDIR C:\inetpub\wwwroot
COPY --from=build C:\src\bin .\bin
COPY --from=build C:\src\Views .\Views
COPY --from=build C:\src\Content .\Content
COPY --from=build C:\src\Scripts .\Scripts
COPY --from=build C:\src\Web.config .
COPY --from=build C:\src\Global.asax .
COPY --from=build C:\src\favicon.ico .