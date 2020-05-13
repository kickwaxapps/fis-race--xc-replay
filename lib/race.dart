class Race {
  Race({this.name, this.lapDistance = 0});

  final String name;
  final double lapDistance;

  Map<int, Racer> _racer = Map();
  List<RaceSegment> _segment = List();

  Racer getRacer(int i) {
    return _racer.values.toList()[i];
  }
  addOrderedSegment(int id, double totalDistanceMeters ) {
    double startMeters =  _segment.length > 0 ?_segment.last?.endMeters : 0;
    double endMeters = totalDistanceMeters;
    _segment.add(RaceSegment(id: id, startMeters: startMeters, endMeters: endMeters));
  }

  segmentCount() => _segment.length;
  List<RaceSegment>  get segments => _segment;

  addRacer(int bib, RacerDetails details) {
    _racer[bib] = Racer(bib, details);
  }

  addOrderedSplit(int bib, double elapsedTimeSeconds, int id) {
    final racer = _racer[bib];
    final segment  = _segment.firstWhere((it) => it.id == id);
    racer.addOrderedSplit(elapsedTimeSeconds, segment);
  }

  List<RacerSnapshot> getState(double elapsedSeconds) {
    final temp = List<RacerSnapshot>();

    _racer.values.forEach((it) {
      temp.add(it.getSnapshot(elapsedSeconds));
    });

    temp.sort((a, b) =>
         b.sortForRanking.compareTo(a.sortForRanking));
    final first = temp[0];

    int rank = 1;
    final state = temp.map((it) => RacerSnapshot.clone(it, metersBack: first.distance - it.distance, rank: rank++) );

    return state.toList()..sort((a,b)=> a.sort.compareTo(b.sort));
  }

  void removeRacersWithMissingSegments() {
    final expectedSegmentCount = segmentCount();
    _racer.removeWhere((key, value) => value.splitCount() != expectedSegmentCount);
  }

}

class RacerSnapshot {
  final Racer racer;
  final double distance;
  final double metersBack;
  final int rank;
  final double sortForRanking;
  final int sort;
  final double finishSeconds;
  bool get finish  => finishSeconds > 0;
  final bool error;

  RacerSnapshot(this.racer, this.distance, this.metersBack, this.rank, this.finishSeconds, this.error):
      sortForRanking = finishSeconds > 0 ? (10000000 - finishSeconds/1000) : distance,
      sort = racer.pinned ? -1000 + rank  : rank;

  static RacerSnapshot forPartial(Racer racer, double distance ) => RacerSnapshot(racer, distance, 0, 0, 0, false);
  static RacerSnapshot forFinished(Racer racer, double distance, double finishSeconds) => RacerSnapshot(racer, distance, 0, 0, finishSeconds, false);
  static RacerSnapshot forError(Racer racer) => RacerSnapshot(racer, 0, 0, 0, 0, true);
  RacerSnapshot.clone(RacerSnapshot rs, {double metersBack, int rank}) : this(rs.racer, rs.distance, metersBack ?? rs.metersBack, rank ?? rs.rank, rs.finishSeconds, rs.error);
}

class RaceSegment {
  final int id;
  final double startMeters;
  final double endMeters;
  final double distanceMeters;
  RaceSegment ({this.id, this.startMeters, this.endMeters}) :
      distanceMeters = endMeters - startMeters;
}

class Racer {
  final int bib;
  final RacerDetails details;
  final List<Split> _split = List();

  int splitCount() => _split.length;

  bool pinned = false;
  bool starred = false;
  
  addOrderedSplit(double elapsedTimeSeconds, RaceSegment segment ) {
    _split.add(Split(elapsedTimeSeconds, segment));
  }

  Racer(this.bib, this.details);

  RacerSnapshot getSnapshot(double elapsedTimeSeconds ){
    
      final index = _split.indexWhere((it) => it.timeSeconds > elapsedTimeSeconds);
      if (index == -1) {
        if (elapsedTimeSeconds > 0 && _split.length > 0 ) {
          final finishSplit = _split.last;
          return RacerSnapshot.forFinished(this,finishSplit.segment.endMeters,  finishSplit.timeSeconds);
        }
        return RacerSnapshot.forError(this);
      }
      final split = _split[index];
      final prevSplit = index > 0 ? _split[index-1] : null;
      final segment = split.segment;
      final double segmentTime = elapsedTimeSeconds - (prevSplit?.timeSeconds ?? 0);
      final double segmentSpeed = segment.distanceMeters / (split.timeSeconds - (prevSplit?.timeSeconds ?? 0));
      final double segmentDistance = segmentTime * segmentSpeed;

      return RacerSnapshot.forPartial(this, segment.startMeters + segmentDistance);
    }

}

class Split {
  final double timeSeconds;
  final RaceSegment segment;

  Split(this.timeSeconds, this.segment);
}

class RacerDetails {
  final String name;
  final String nation;

  RacerDetails(this.name, this.nation);
}




