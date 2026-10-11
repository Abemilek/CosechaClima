using WebApi.Interface;

namespace WebApi;

/// <summary>Borra periodicamente los refresh tokens vencidos para que la tabla no crezca sin limite.</summary>
public class LimpiezaRefreshTokensWorker : BackgroundService
{
    private static readonly TimeSpan Intervalo = TimeSpan.FromHours(6);

    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<LimpiezaRefreshTokensWorker> _logger;

    public LimpiezaRefreshTokensWorker(
        IServiceScopeFactory scopeFactory, ILogger<LimpiezaRefreshTokensWorker> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var temporizador = new PeriodicTimer(Intervalo);
        do
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var servicio = scope.ServiceProvider.GetRequiredService<IRefreshTokenService>();
                var borrados = await servicio.LimpiarExpiradosAsync();
                if (borrados > 0)
                    _logger.LogInformation("Refresh tokens vencidos eliminados: {Cantidad}", borrados);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogWarning(ex, "No se pudo limpiar refresh tokens vencidos");
            }
        }
        while (await temporizador.WaitForNextTickAsync(stoppingToken));
    }
}
