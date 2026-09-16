FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY ["CosechaClima.sln", "./"]
COPY ["WebApi/WebApi.csproj", "WebApi/"]
COPY ["WebApi.Models/WebApi.Models.csproj", "WebApi.Models/"]
COPY ["Services/WebApi.Interface/WebApi.Interface.csproj", "Services/WebApi.Interface/"]
COPY ["Services/WebApi.Implementation/WebApi.Implementation.csproj", "Services/WebApi.Implementation/"]

RUN dotnet restore "CosechaClima.sln"

COPY . .

RUN dotnet publish "WebApi/WebApi.csproj" -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS final
WORKDIR /app

COPY --from=build /app/publish .

EXPOSE 8080
ENV ASPNETCORE_URLS=http://+:8080

ENTRYPOINT ["dotnet", "WebApi.dll"]