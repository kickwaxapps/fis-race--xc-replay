import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:spritewidget/spritewidget.dart';
import 'load-fis.dart';
import 'race.dart';
import 'dart:ui' as ui show Image, Gradient, window, Rect;


void main()  {
  runApp(MyApp());
}



//void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FIS Race Replay Simulator',
      theme: ThemeData(

        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'FIS Race Replay Simulation'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _raceCode = '2679';
  double _time = 0;
  double _timeFactor = 1.0;

  int _scale = 1;
  bool _auto = false;

  Future<Race> _raceFut = null;

  _MyHomePageState () {
    Timer.periodic(Duration(milliseconds: 500),      (_){
      if (_auto) {
        setState(() {
          _time += .5* _timeFactor;
        });
      }
    } );
  }

  String timeHHMMSS(double t) {
    final hh = (t / 3600).truncate(),
    mm = ((t - hh * 3600 ) / 60).truncate(),
    ss = (t - hh * 3600 - mm * 60  );
    return '$hh:$mm:${ss.toStringAsFixed(1)}';
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(

        actions: <Widget>[

          SizedBox( width: 50,
              child: Center(child:TextFormField(
            decoration: InputDecoration(labelText: 'Codex', hintText: 'FIS Codex#'),
            initialValue: _raceCode,
            onChanged: (v) {
              setState(() {
                _raceCode =  v;
              });
            },
          ))),
          FlatButton(
            child: Text('Load'),
            onPressed: () {
              setState((){
                _raceFut = getRace('cc-$_raceCode');
              });
            },
        ),
       /* IconButton(icon: Icon(Icons.zoom_in),
              onPressed:  () {
                setState(() {
                  _scale = (_scale -1).clamp(1,10);
                });
              }
          ),
          IconButton(icon: Icon(Icons.zoom_out),
              onPressed:  () {
                setState(() {
                  _scale = (_scale +1).clamp(1,10);
                });
              }
          ),*/
          IconButton(icon: Icon(Icons.replay),
              onPressed:  () {
                setState(() {
                   _time = 0;
                   _timeFactor = 1.0;
                    _raceCode =  '2679';
                  _scale = 1;
                  _auto = false;
                });
              }
          ),
          IconButton(icon: Icon(Icons.fast_rewind),
              onPressed:  () {
             setState(() {
                if (_auto) {
                  _timeFactor  = -10;
                } else {
                  _time = (_time - 60).clamp(0, double.maxFinite);
                }
             });
           }
          ),
          IconButton(icon: Icon(_auto ? Icons.pause : Icons.play_arrow),
              onPressed:  () {
                setState(() {
                  _timeFactor = 1.0;
                  _auto = !_auto;
                });
              }
          ),
          IconButton(icon: Icon(Icons.fast_forward),
              onPressed:  () {
                setState(() {
                  if (_auto) {
                    _timeFactor  = 10;
                  } else {
                    _time += 60;
                  }
                });
              }
          )
      ],
      ),
      body: _raceFut == null  ? Text('Enter an FIS CC race Codex above and hit load...') :  FutureBuilder (
        future: _raceFut,
        builder: (ctx, snap) {
          if(snap.connectionState == ConnectionState.done) {


            final state = snap.data.getState(_time);
            final first = state[0];
            final vpWidth = 1000 * _scale;

            final vpLeft = first.distance* _scale <= vpWidth/2 ? 0 : first.distance*_scale - vpWidth/2;
            final vpRight = vpLeft + vpWidth;

//git            return                 GameLayer();

          return Column(
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Column(children:[Text(snap.data.name), Text('Time: ${timeHHMMSS(_time)}')]),
                ],),
                Tape(vpLeft, vpWidth),
               Expanded(

                  child: ListView.builder(itemBuilder: (_, i) {
                    final s = state[i],
                      r = s.racer;
                    return ListTile(
                      leading: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: <Widget>[
                          Text('${s.rank}'),
                          Image.asset('assets/images/'+r.details.nation.trim()+'.png', height: 24, width: 36),
                          Text(r.details.nation, textScaleFactor: .5,)
                        ],
                      ),
                      //leading:r.pinned ? Icon(Icons.star) : ,
                      title: LinearProgressIndicator(value:((s.distance-vpLeft)/(vpWidth)) ),
                      subtitle: getRacerText(s),
                      onTap: () => r.starred = !r.starred,
                    );
                  }),
                ),
              ],
            );
          ;
          } else {
            return CircularProgressIndicator();
          }
        },
      ),
    );
    }

  Widget getRacerText(RacerSnapshot s) {
    final r = s.racer,
      base = '${r.details.name}  Bib ${r.bib}';

    var detail = '';


    if(s.finish) {
      detail = 'Time: ${timeHHMMSS(s.finishSeconds)}';
    } else if (s.rank == 1) {
      detail =  '${s.distance.round()}m';
    } else {
      final mb = s.metersBack.round();
      detail = '-${mb}m';
    }
    return Row(
        children: [
          Text(base, style: r.starred ? TextStyle(fontWeight: FontWeight.bold): null,),
          Spacer(),
          Text(detail)
        ]
    );


  }

}

class Tape extends StatelessWidget {
  final _vpWidth;
  final _vpLeft;

  const Tape(this._vpLeft, this._vpWidth) : super();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) => getBody(context, constraints.maxWidth)
    );
  }


  Widget getBody(context, width) {

      final tc = (_vpLeft / 500).truncate() +1,
          tickLeft = tc * 500,
          tickCount = (_vpWidth / 500).truncate(),
          mp = width/_vpWidth,
          tape = List.generate(tickCount *2, (i) {
            if (i == 0) {
              return Container(width: (tickLeft - _vpLeft) * mp, child: Text(''), decoration: BoxDecoration(border:Border(right: BorderSide(color: Colors.blueGrey))));
            } else if (i == 1) {
              return Text(tickLeft.toString()+'m', textScaleFactor: .5,);
            } else if ( i % 2 == 0) {
              return Container(width: 500* mp, child: Text(''), decoration: BoxDecoration(border:Border(right: BorderSide(color: Colors.blueGrey))));
            }

            return Text( ((tickLeft + 500  * (i+1) / 2 - 500 )).truncate().toString() + 'm', textScaleFactor: .5, );

          });

        return ListTile(
            leading: Text('Rank'),
            title: Row(
                children: tape
            ));

    }

}



class GameLayer extends StatefulWidget {
  @override
  MyWidgetState createState() => new MyWidgetState();
}

class MyWidgetState extends State<GameLayer> {
  NodeWithSize rootNode;
  ImageMap im;

  bool loaded = false;

  @override
  void initState() {
    super.initState();
    rootNode = new NodeWithSize(const Size(1024.0, 1024.0));

    im = ImageMap(rootBundle);
    Future<String> jsonFut = DefaultAssetBundle.of(context).loadString('assets/images/classic-skier-anim.json');

    Future.wait([im.load(['assets/images/classic-skier-anim.png', 'assets/images/CAN.png']), jsonFut]).then((a) {
      setState(() {
        final i = im['assets/images/classic-skier-anim.png'];
        final si = im['assets/images/CAN.png'];

        final mx = Matrix4.identity().scaled(.5).storage;



        final pt = Paint();
        final pr = PictureRecorder();
        final cv = Canvas(pr);
        final rt = ui.Rect.fromLTWH(0,0,i.width.toDouble(), i.height.toDouble());
        final sh = LinearGradient(colors: [Colors.green, Colors.deepOrange], stops:[0,.5]).createShader(rt);
        //final sh = ImageShader(si, TileMode.clamp, TileMode.repeated, mx );
       // pt.shader = sh;

        cv.saveLayer(rt, pt);
        cv.drawImage(i, Offset.zero, pt);
        cv.drawRect(rt, pt..blendMode = BlendMode.srcATop);
        cv.restore();

        final er = pr.endRecording();
        final  imgg = er.toImage(i.width, i.height);
        Future.wait([imgg]).then((i1){
          final json = a[1];
          SpriteSheet sprites =  SpriteSheet(i1[0], json);
          rootNode.addChild(AnimSprite(sprites.textures.values.toList()));

          loaded = true;

        });


      });
    });



  }

  @override
  Widget build(BuildContext context) {
    if (loaded)
    return SpriteWidget(rootNode);
    else
      return Text('hellooo');
  }
}


class AnimSprite extends Sprite {
  int _index = 0;
  double fps = 10.0;
  double _timeInFrame = 0.0;
  List<SpriteTexture> frames;

  Paint _cachedPaint = Paint();

  AnimSprite(this.frames) : super(frames[0]) {


    motions.run(MotionRepeatForever(MotionSequence([
      MotionTween<double>((v) {
        fps = v;
      }, 5, 15, 20),
      MotionTween<double>((v) {
        fps = v;
      }, 15, 5, 20),
    ])));
  }

  @override
  void update(double dt) {
    if (_timeInFrame > 1 / fps) {
      _index ++;
      _timeInFrame = 0;
      if (_index == frames.length) {
        _index = 0;
      }

      texture = frames[_index];
      scale = 0.5;
      position = Offset(500, 500);
    }

    _timeInFrame += dt;
    super.update(dt);
  }

  @override
  void paint(Canvas canvas) {

    // Account for pivot point
    applyTransformForPivot(canvas);

    double w = texture.size.width;
    double h = texture.size.height;

    if (w <= 0 || h <= 0) return;

    double scaleX = size.width / w;
    double scaleY = size.height / h;

    if (constrainProportions) {
      if (scaleX < scaleY) {
        canvas.translate(0.0, (size.height - scaleX * h) / 2.0);
        scaleY = scaleX;
      } else {
        canvas.translate((size.width - scaleY * w) / 2.0, 0.0);
        scaleX = scaleY;
      }
    }

    texture.drawTexture(canvas, Offset.zero, _cachedPaint);

  }
}




