# etapa build para compilar
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /src

# copiar el codigo, primero el .sln y el .csproj
COPY ["CosechaClima.sln", "./"]
COPY ["WebApi/WebApi.csproj", "WebApi/"]
COPY ["WebApi.Models/WebApi.Models.csproj", "WebApi.Models/"]
COPY ["Services/WebApi.Interface/WebApi.Interface.csproj", "Services/WebApi.Interface/"]
COPY ["Services/WebApi.Implementation/WebApi.Implementation.csproj", "Services/WebApi.Implementation/"]

# bajar los paquetes nugets de toda la solucion
RUN dotnet restore "CosechaClima.sln"

COPY . .

# publicar el proyecto de inicio sin restaurar pues ya se hizo arriba
RUN dotnet publish "WebApi/WebApi.csproj" -c Release -o /app/publish --no-restore

# la etapa del runtime
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final

WORKDIR /app

RUN chown -R app:app /app

# copiar solo lo compilado
COPY --from=build /app/publish .

EXPOSE 8080

ENV ASPNETCORE_URLS=http://+:8080

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# cambiar al usuario 
USER app

# correr la api compilada
ENTRYPOINT ["dotnet", "WebApi.dll"]