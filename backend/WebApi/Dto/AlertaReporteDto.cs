using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

/// <summary>
/// La app calcula la alerta en el dispositivo y solo avisa al servidor QUE evento detecto y para que dia.
/// El texto (acciones, descripcion, nivel) lo pone el servidor desde su propia tabla de reglas,
/// asi un cliente modificado no puede inyectar contenido en la auditoria.
/// </summary>
public class AlertaReporteDto
{
    [Required, Range(1, 100)]
    public int EventoClimaticoId { get; set; }

    [Required]
    public DateTime Fecha { get; set; }
}
