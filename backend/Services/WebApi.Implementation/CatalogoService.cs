using Microsoft.Data.SqlClient;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class CatalogoService : ICatalogoService
{
    private readonly ConnectionBD _connectionBD;
    private readonly IEtapaFenologicaService _etapaFenologicaService;

    public CatalogoService(ConnectionBD connectionBD, IEtapaFenologicaService etapaFenologicaService)
    {
        _connectionBD = connectionBD;
        _etapaFenologicaService = etapaFenologicaService;
    }

    public async Task<List<Cultivo>> ObtenerCultivos()
    {
        var lista = new List<Cultivo>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, Nombre, NombreCientifico FROM Cultivos ORDER BY Nombre", connection);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            lista.Add(new Cultivo
            {
                Id = reader.GetInt32(0),
                Nombre = reader.GetString(1),
                NombreCientifico = reader.IsDBNull(2) ? null : reader.GetString(2)
            });
        }

        return lista;
    }

    public async Task<List<TipoSuelo>> ObtenerTiposSuelo()
    {
        var lista = new List<TipoSuelo>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, Nombre, Descripcion FROM TipoSuelo ORDER BY Nombre", connection);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            lista.Add(new TipoSuelo
            {
                Id = reader.GetInt32(0),
                Nombre = reader.GetString(1),
                Descripcion = reader.IsDBNull(2) ? null : reader.GetString(2)
            });
        }

        return lista;
    }

    public async Task<List<EventoClimatico>> ObtenerEventosClimaticos()
    {
        var lista = new List<EventoClimatico>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, Nombre, Descripcion FROM EventoClimatico ORDER BY Id", connection);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            lista.Add(new EventoClimatico
            {
                Id = reader.GetInt32(0),
                Nombre = reader.GetString(1),
                Descripcion = reader.IsDBNull(2) ? null : reader.GetString(2)
            });
        }

        return lista;
    }
    
    public Task<List<EtapaFenologica>> ObtenerEtapasFenologicas()
    {
        return _etapaFenologicaService.ObtenerTodas();
    }
}