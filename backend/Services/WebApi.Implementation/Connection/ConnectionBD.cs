using Microsoft.Extensions.Configuration;
using Npgsql;

namespace WebApi.Implementation.Connection;

/// <summary>
/// Envuelve un unico <see cref="NpgsqlDataSource"/> para toda la aplicacion.
/// Segun la documentacion de Npgsql (7.0+), el data source es el punto de partida
/// recomendado: es thread-safe, representa el pool de conexiones y debe crearse una
/// sola vez. Se registra como singleton y se libera al apagar la app.
/// </summary>
public sealed class ConnectionBD : IAsyncDisposable, IDisposable
{
    private readonly NpgsqlDataSource _dataSource;

    public ConnectionBD(IConfiguration configuracion)
    {
        var cadena = configuracion.GetConnectionString("BD_CosechaClima")
            ?? throw new InvalidOperationException(
                "No se encontro la cadena de conexion 'BD_CosechaClima' en appsettings.json");

        _dataSource = new NpgsqlDataSourceBuilder(cadena).Build();
    }

    /// <summary>
    /// Devuelve una conexion cerrada del pool. Quien la use debe abrirla
    /// (OpenAsync) y liberarla con using para devolverla al pool.
    /// </summary>
    public NpgsqlConnection CrearConexion() => _dataSource.CreateConnection();

    public void Dispose() => _dataSource.Dispose();

    public ValueTask DisposeAsync() => _dataSource.DisposeAsync();
}
