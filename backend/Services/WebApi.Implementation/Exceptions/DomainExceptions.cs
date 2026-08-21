namespace WebApi.Implementation.Exceptions;

public sealed class RecursoNoEncontradoException : Exception
{
    public RecursoNoEncontradoException(string mensaje) : base(mensaje) { }
}

public sealed class FlujoIncompletoException : Exception
{
    public FlujoIncompletoException(string mensaje) : base(mensaje) { }
}
