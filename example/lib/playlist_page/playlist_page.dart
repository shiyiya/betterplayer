import 'dart:io';

import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class PlaylistPage extends StatefulWidget {
  @override
  _PlaylistPageState createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  List dataSourceList = List<BetterPlayerDataSource>();

  Future<List<BetterPlayerDataSource>> setupData() async {
    dataSourceList.add(BetterPlayerDataSource(
      BetterPlayerDataSourceType.NETWORK,
      "https://gss3.baidu.com/6LZ0ej3k1Qd3ote6lo7D0j9wehsv/tieba-smallvideo/6331_39ecb93c60353cc2d0187af6d8201100.mp4",
    ));

    dataSourceList.add(BetterPlayerDataSource(
        BetterPlayerDataSourceType.NETWORK,
        "https://vt1.doubanio.com/201902111139/0c06a85c600b915d8c9cbdbbaf06ba9f/view/movie/M/302420330.mp4"));

    return dataSourceList;
  }

  Future _saveAssetToFile() async {
    String content =
        await rootBundle.loadString("assets/example_subtitles.srt");
    final directory = await getApplicationDocumentsDirectory();
    var file = File("${directory.path}/example_subtitles.srt");
    file.writeAsString(content);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<BetterPlayerDataSource>>(
      future: setupData(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Text("Building!");
        } else {
          return AspectRatio(
            child: BetterPlayerPlaylist(
              betterPlayerConfiguration: BetterPlayerConfiguration(
                  autoPlay: false,
                  subtitlesConfiguration:
                      BetterPlayerSubtitlesConfiguration(fontSize: 10),
                  controlsConfiguration:
                      BetterPlayerControlsConfiguration.cupertino()),
              betterPlayerPlaylistConfiguration:
                  BetterPlayerPlaylistConfiguration(
                      nextVideoDelay: Duration(seconds: 30)),
              betterPlayerDataSourceList: snapshot.data,
            ),
            aspectRatio: 16 / 9,
          );
        }
      },
    );
  }
}
