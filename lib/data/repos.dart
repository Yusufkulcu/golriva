import 'genc_repository.dart';
import 'hedef_repository.dart';
import 'ikiz_repository.dart';
import 'kor_av_repository.dart';
import 'kupa_repository.dart';
import 'players_repository.dart';
import 'serbest_repository.dart';

/// Tum oyun veri setlerinin tek catisi — uygulama acilisinda paralel yuklenir.
class GolrivaRepos {
  final PlayersRepository boy;
  final GencRepository genc;
  final HedefRepository hedef;
  final KorAvRepository fee;
  final KorAvRepository card;
  final SerbestRepository mac;
  final SerbestRepository milligol;
  final KupaRepository kupa;
  final IkizRepository ikiz;

  GolrivaRepos(
      {required this.boy,
      required this.genc,
      required this.hedef,
      required this.fee,
      required this.card,
      required this.mac,
      required this.milligol,
      required this.kupa,
      required this.ikiz});

  static Future<GolrivaRepos> load() async {
    final r = await Future.wait([
      PlayersRepository.load(),
      GencRepository.load(),
      HedefRepository.load(),
      KorAvRepository.loadFee(),
      KorAvRepository.loadCard(),
      SerbestRepository.loadMac(),
      SerbestRepository.loadMilligol(),
      KupaRepository.load(),
      IkizRepository.load(),
    ]);
    return GolrivaRepos(
      boy: r[0] as PlayersRepository,
      genc: r[1] as GencRepository,
      hedef: r[2] as HedefRepository,
      fee: r[3] as KorAvRepository,
      card: r[4] as KorAvRepository,
      mac: r[5] as SerbestRepository,
      milligol: r[6] as SerbestRepository,
      kupa: r[7] as KupaRepository,
      ikiz: r[8] as IkizRepository,
    );
  }
}
