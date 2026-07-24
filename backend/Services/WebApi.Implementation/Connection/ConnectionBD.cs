using Microsoft.Data.SqlClient;
using Microsoft.Extensions.Configuration;

namespace WebApi.Implementation.Connection;

public class ConnectionBD{
    private readonly string _cadena;

    public ConnectionBD (IConfiguration configuracion) {
        _cadena = configuracion.GetConnectionString("BD_CosechaClima")
        ?? throw new InvalidOperationException (
            "No se encontro la cadena de conexion 'BD_CosechaClima' en appsettings.json"  );
    }
       
    public SqlConnection CrearConexion(){
        return new SqlConnection (_cadena);
    }
}