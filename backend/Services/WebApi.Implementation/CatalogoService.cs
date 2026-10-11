using System.Linq;
using Npgsql;
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
        using var command = new NpgsqlCommand(
            "SELECT id, nombre, nombre_cientifico FROM cultivos ORDER BY nombre", connection);

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
        using var command = new NpgsqlCommand(
            "SELECT id, nombre, descripcion FROM tipos_suelo ORDER BY nombre", connection);

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
        using var command = new NpgsqlCommand(
            "SELECT id, nombre, descripcion FROM eventos_climaticos ORDER BY id", connection);

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

    public List<string> ObtenerMunicipiosCobertura()
    {
        return MunicipioCentroide.Departamentos.ToList();
    }

    public async Task<bool> CultivoExiste(int id)
    {
        return await ExisteEnTabla("cultivos", id);
    }

    public async Task<bool> TipoSueloExiste(int id)
    {
        return await ExisteEnTabla("tipos_suelo", id);
    }

    public async Task<bool> EtapaFenologicaExiste(int id)
    {
        return await ExisteEnTabla("etapas_fenologicas", id);
    }

    // "tabla" solo recibe literales fijos de esta clase, nunca datos del usuario.
    private async Task<bool> ExisteEnTabla(string tabla, int id)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT EXISTS (SELECT 1 FROM {tabla} WHERE id = @Id)", connection);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return result is true;
    }
}