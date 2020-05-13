

import 'package:html/parser.dart';
import 'package:http/http.dart' as http;


import 'race.dart';

Future<Race> getRace(String homologationId) async {
  var response = await http.get('http://live.fis-ski.com/$homologationId/results-pda.htm');
  var doc = parse(response.body);

  var title = doc.getElementById('eventtitletext').innerHtml;
  var race = Race(name: title, lapDistance: 0);

  // load race split segments'
  int id = 0;
  doc.getElementById('int1').children.forEach((it) {
    final tkns = it.innerHtml.split(' ');
    if (!['bonus', 'start'].contains(tkns[0].toLowerCase().trim())) {
      final isLastSegment = (tkns.first.toLowerCase() == 'finish');
      final unit = tkns.removeLast().toLowerCase();
      final lengthString = tkns.removeLast(),
        length = double.parse(lengthString) * (unit == 'km' ? 1000 : 1);
      if (isLastSegment) {
        id = 99;
      }
      race.addOrderedSegment(id, length);
    }

    id++;
  });

  // load racers
  response = await http.get('https://www.xcracer.info/api/pt/sys3.novius.net/mobile/$homologationId/startlist-pda-1.htm');
  doc = parse(response.body);

  doc.getElementsByClassName('cc')[0].children.forEach((it) {
      var bib = int.parse(it.getElementsByClassName('col_bib')[0].innerHtml),
        name = it.getElementsByClassName('name')[0].text.trim(),
        nation = it.getElementsByClassName('col_nsa')[0].text.trim();
      race.addRacer(bib, RacerDetails(name,nation));
  });

  // load splits for each segment


   await Future.forEach(race.segments, (it)  async {
    final int segmentId = it.id;
    response = await http.get('https://www.xcracer.info/api/pt/sys3.novius.net/mobile/$homologationId/results-pda-$segmentId.htm');
    doc = parse(response.body);

    doc.getElementsByClassName('cc')[0].children.forEach((it) {
      var bib = int.parse(it.getElementsByClassName('col_bib')[0].innerHtml),
          timeString = it.getElementsByClassName('col_result')[0].innerHtml,
          tkns = timeString.split(':').reversed.toList(),
          ss = double.tryParse(tkns[0]) ?? 0,
          mm = tkns.length > 1 ? int.parse(tkns[1]) : 0,
          hh = tkns.length > 2 ? int.parse(tkns[2]) : 0,
          split = hh * 60 * 60 + mm * 60 + ss;
      if( split > 0 ) {
        race.addOrderedSplit(bib, split, segmentId);
      }
    });

  });

  //race.removeRacersWithMissingSegments();

  return race;
}