using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace WebApi.Implementation.Connection;

/// <summary>
/// Aplica los scripts SQL de Scripts/migrations en orden alfabetico, una sola vez cada uno.
/// - Registra version y checksum en schema_migrations.
/// - Cada script corre dentro de una transaccion (PostgreSQL soporta DDL transaccional).
/// - Usa un advisory lock para que dos instancias de la API no migren a la vez.
/// - Si un script ya aplicado cambia (checksum distinto) se detiene: los cambios van en un archivo nuevo.
/// </summary>
public sealed class MigradorBD
{
    // Identificador arbitrario del advisory lock de esta aplicacion.
    private const long IdBloqueo = 7_243_001_991L;

    private readonly ConnectionBD _connectionBD;
    private readonly ILogger<MigradorBD> _logger;

    public MigradorBD(ConnectionBD connectionBD, ILogger<MigradorBD> logger)
    {
        _connectionBD = connectionBD;
        _logger = logger;
    }

    public async Task AplicarPendientesAsync(CancellationToken ct = default)
    {
        var carpeta = Path.Combine(AppContext.BaseDirectory, "Scripts", "migrations");
        if (!Directory.Exists(carpeta))
            throw new DirectoryNotFoundException($"No se encontro la carpeta de migraciones: {carpeta}");

        var archivos = Directory.GetFiles(carpeta, "*.sql")
            .OrderBy(Path.GetFileName, StringComparer.Ordinal)
            .ToList();

        await using var conexion = await AbrirConReintentosAsync(ct);

        await EjecutarAsync(conexion, "SELECT pg_advisory_lock(@id)", ct, ("@id", IdBloqueo));
        try
        {
            await EjecutarAsync(conexion,
                "CREATE TABLE IF NOT EXISTS schema_migrations (" +
                "version text PRIMARY KEY, " +
                "checksum text NOT NULL, " +
                "aplicada_en timestamptz NOT NULL DEFAULT now())", ct);

            var aplicadas = await LeerAplicadasAsync(conexion, ct);

            foreach (var archivo in archivos)
            {
                var version = Path.GetFileNameWithoutExtension(archivo);
                var sql = (await File.ReadAllTextAsync(archivo, Encoding.UTF8, ct)).Replace("\r\n", "\n");
                var checksum = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(sql)));

                if (aplicadas.TryGetValue(version, out var checksumGuardado))
                {
                    if (!string.Equals(checksumGuardado, checksum, StringComparison.Ordinal))
                    {
                        throw new InvalidOperationException(
                            $"La migracion '{version}' ya fue aplicada y el archivo cambio. " +
                            "No edites migraciones existentes: crea una nueva (por ejemplo 004_...).");
                    }
                    continue;
                }

                _logger.LogInformation("Aplicando migracion {Version}", version);

                await using var transaccion = await conexion.BeginTransactionAsync(ct);
                await using (var comando = new NpgsqlCommand(sql, conexion, transaccion))
                {
                    await comando.ExecuteNonQueryAsync(ct);
                }
                await using (var registro = new NpgsqlCommand(
                    "INSERT INTO schema_migrations (version, checksum) VALUES (@v, @c)", conexion, transaccion))
                {
                    registro.Parameters.AddWithValue("@v", version);
                    registro.Parameters.AddWithValue("@c", checksum);
                    await registro.ExecuteNonQueryAsync(ct);
                }
                await transaccion.CommitAsync(ct);
            }
        }
        finally
        {
            await EjecutarAsync(conexion, "SELECT pg_advisory_unlock(@id)", CancellationToken.None, ("@id", IdBloqueo));
        }
    }

    private async Task<NpgsqlConnection> AbrirConReintentosAsync(CancellationToken ct)
    {
        const int intentosMaximos = 6;
        for (var intento = 1; ; intento++)
        {
            var conexion = _connectionBD.CrearConexion();
            try
            {
                await conexion.OpenAsync(ct);
                return conexion;
            }
            catch (NpgsqlException ex) when (intento < intentosMaximos)
            {
                await conexion.DisposeAsync();
                _logger.LogWarning(ex, "Base de datos no disponible (intento {Intento}/{Max}), reintentando...",
                    intento, intentosMaximos);
                await Task.Delay(TimeSpan.FromSeconds(3), ct);
            }
            catch
            {
                await conexion.DisposeAsync();
                throw;
            }
        }
    }

    private static async Task<Dictionary<string, string>> LeerAplicadasAsync(NpgsqlConnection conexion, CancellationToken ct)
    {
        var resultado = new Dictionary<string, string>(StringComparer.Ordinal);
        await using var comando = new NpgsqlCommand("SELECT version, checksum FROM schema_migrations", conexion);
        await using var lector = await comando.ExecuteReaderAsync(ct);
        while (await lector.ReadAsync(ct))
            resultado[lector.GetString(0)] = lector.GetString(1);
        return resultado;
    }

    private static async Task EjecutarAsync(
        NpgsqlConnection conexion, string sql, CancellationToken ct, params (string Nombre, object Valor)[] parametros)
    {
        await using var comando = new NpgsqlCommand(sql, conexion);
        foreach (var (nombre, valor) in parametros)
            comando.Parameters.AddWithValue(nombre, valor);
        await comando.ExecuteNonQueryAsync(ct);
    }
}
