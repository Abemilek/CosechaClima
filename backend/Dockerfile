# etapa build para compilar

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build

WORKDIR /src

# cpoiar el codigo , primero el .sln y el .csproj

COPY ["CosechaClima.sln", "./"]
COPY ["WebApi/WebApi.csproj", "WebApi/"]
COPY ["WebApi.Models/WebApi.Models.csproj", "WebApi.Models/"]
COPY ["Services/WebApi.Interface/WebApi.Interface.csproj", "Services/WebApi.Interface/"]
COPY ["Services/WebApi.Implementation/WebApi.Implementation.csproj", "Services/WebApi.Implementation/"]

# bajar los paquetes nuggets de toda la solucion

RUN dotnet restore "CosechaClima.sln"

COPY . .

# publicar el proyecto de inicio sin restaurar pues ya se hizo arriba, por las referencias se publican ls demas

RUN dotnet publish "WebApi/WebApi.csproj" -c Release -o /app/publish --no-restore

# la etapa del runtime

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final

WORKDIR /app

# este es un usuario no administrador para crrer la app por seguridad lol

RUN adduser --disabled-password --gecos "" user

# aqui se copia solo lo que se compilo en la build, nada de codigo fuente

COPY --from=build /app/publish .

EXPOSE 8080

ENV ASPNETCORE_URLS=http://+:8080

# cmbiar el usurio no root que se creo o sea el appuser

USER appuser

# correr la api compilada

ENTRYPOINT ["dotnet", "WebApi.dll"]