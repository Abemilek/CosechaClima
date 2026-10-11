namespace WebApi.Implementation;

/// <summary>
/// Npgsql 6+ solo acepta DateTime con Kind=Utc para columnas timestamptz
/// (docs: npgsql.org/doc/types/datetime.html). Estas utilidades normalizan los
/// valores que llegan de la API antes de escribirlos.
/// </summary>
public static class FechasUtc
{
    // Nicaragua no usa horario de verano desde 2006: UTC-6 fijo.
    public static readonly TimeSpan OffsetNicaragua = TimeSpan.FromHours(-6);

    public static DateTime AUtc(DateTime valor) => valor.Kind switch
    {
        DateTimeKind.Utc => valor,
        DateTimeKind.Local => valor.ToUniversalTime(),
        // Un cliente que mande "2026-10-09T10:00:00" sin zona: se asume UTC (la app nueva siempre manda Z).
        _ => DateTime.SpecifyKind(valor, DateTimeKind.Utc)
    };

    public static DateOnly ADateOnly(DateTime valor) => DateOnly.FromDateTime(valor);

    public static DateTime DeDateOnly(DateOnly valor) => valor.ToDateTime(TimeOnly.MinValue);

    /// <summary>Fecha de hoy en Nicaragua, independiente de la zona horaria del servidor.</summary>
    public static DateTime HoyNicaragua() => DateTime.UtcNow.Add(OffsetNicaragua).Date;
}
