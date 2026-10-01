import '../../features/parcela/data/models/parcela.dart';
import '../../features/parcela/data/services/parcela_service.dart';
import '../network/api_client.dart';
import 'guest_parcela_store.dart';
import 'parcela_cache.dart';

Future<int> migrarParcelasInvitadoACuenta() async {
  final store = GuestParcelaStore();
  final pendientes = await store.listar();
  if (pendientes.isEmpty) return 0;

  final parcelaService = ParcelaService(ApiClient());
  final cache = ParcelaCache();
  final idsMigrados = <String>[];

  for (final invitada in pendientes) {
    try {
      await parcelaService.crear(
        ParcelaRequest(
          cultivoId: invitada.cultivoId,
          etapaFenologicaId: invitada.etapaFenologicaId,
          tipoSueloId: invitada.tipoSueloId,
          fechaSiembra: invitada.fechaSiembra,
          areaMzs: invitada.areaMzs,
          latitud: invitada.latitud,
          longitud: invitada.longitud,
          municipio: invitada.municipio,
          comunidad: invitada.comunidad,
        ),
      );
      idsMigrados.add(invitada.idLocal);
    } catch (_) {
      continue;
    }
  }

  for (final id in idsMigrados) {
    await store.eliminar(id);
    await cache.limpiarResumenLocal(id);
  }

  return idsMigrados.length;
}
