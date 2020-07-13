import 'dart:async';

import 'package:better_player/src/controls/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_cupertino_controls.dart';
import 'package:better_player/src/controls/better_player_material_controls.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/subtitles/better_player_subtitles_configuration.dart';
import 'package:better_player/src/subtitles/better_player_subtitles_drawer.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:flutter/material.dart';

class BetterPlayerWithControls extends StatefulWidget {
  final BetterPlayerController controller;

  BetterPlayerWithControls({Key key, this.controller}) : super(key: key);

  @override
  _BetterPlayerWithControlsState createState() =>
      _BetterPlayerWithControlsState();
}

class _BetterPlayerWithControlsState extends State<BetterPlayerWithControls> {
  BetterPlayerSubtitlesConfiguration get subtitlesConfiguration =>
      widget.controller.betterPlayerConfiguration.subtitlesConfiguration;

  BetterPlayerControlsConfiguration get controlsConfiguration =>
      widget.controller.betterPlayerConfiguration.controlsConfiguration;

  final StreamController<bool> playerVisibilityStreamController =
      StreamController();

  @override
  void initState() {
    playerVisibilityStreamController.add(true);
    super.initState();
  }

  @override
  void dispose() {
    playerVisibilityStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BetterPlayerController betterPlayerController =
        BetterPlayerController.of(context);

    return Center(
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: betterPlayerController.aspectRatio,
          child: _buildPlayerWithControls(betterPlayerController, context),
        ),
      ),
    );
  }

  Container _buildPlayerWithControls(
      BetterPlayerController betterPlayerController, BuildContext context) {
    return Container(
      child: Stack(
        children: <Widget>[
          betterPlayerController.placeholder ?? Container(),
          CroppedVideo(
            betterPlayerController: betterPlayerController,
            controller: betterPlayerController.videoPlayerController,
            betterPlayerBoxFit: betterPlayerController.betterPlayerBoxFit,
          ),
          betterPlayerController.overlay ?? Container(),
          betterPlayerController.betterPlayerDataSource.subtitles != null
              ? BetterPlayerSubtitlesDrawer(
                  betterPlayerController: betterPlayerController,
                  betterPlayerSubtitlesConfiguration: subtitlesConfiguration,
                  subtitles: betterPlayerController.subtitles,
                  playerVisibilityStream:
                      playerVisibilityStreamController.stream,
                )
              : const SizedBox(),
          _buildControls(context, betterPlayerController),
        ],
      ),
    );
  }

  Widget _buildControls(
    BuildContext context,
    BetterPlayerController betterPlayerController,
  ) {
    return controlsConfiguration.showControls
        ? controlsConfiguration.customControls != null
            ? controlsConfiguration.customControls
            : Theme.of(context).platform == TargetPlatform.android
                ? BetterPlayerMaterialControls(
                    onPlayerMethondChanged: onPlayerMethondChanged,
                    onControlsVisibilityChanged: onControlsVisibilityChanged,
                    controlsConfiguration: controlsConfiguration,
                  )
                : BetterPlayerCupertinoControls(
                    onControlsVisibilityChanged: onControlsVisibilityChanged,
                    controlsConfiguration: controlsConfiguration,
                  )
        : const SizedBox();
  }

  void onPlayerMethondChanged(
      BetterPlayerController betterPlayerController, BoxFit index) {
    betterPlayerController.setupBetterPlayerBoxFit(index);
    setState(() {});
  }

  void onControlsVisibilityChanged(bool state) {
    playerVisibilityStreamController.add(state);
  }
}

class CroppedVideo extends StatefulWidget {
  CroppedVideo({
    this.controller,
    this.betterPlayerController,
    this.betterPlayerBoxFit,
  });

  final VideoPlayerController controller;
  final BetterPlayerController betterPlayerController;
  final BoxFit betterPlayerBoxFit;

  @override
  CroppedVideoState createState() => CroppedVideoState();
}

class CroppedVideoState extends State<CroppedVideo> {
  VideoPlayerController get controller => widget.controller;

  BoxFit get wBoxFit => widget.betterPlayerController.betterPlayerBoxFit;

  bool initialized = false;

  VoidCallback listener;

  @override
  void initState() {
    super.initState();
    _waitForInitialized();
  }

  @override
  void didUpdateWidget(CroppedVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(listener);
      initialized = false;
      _waitForInitialized();
    }
  }

  void _waitForInitialized() {
    listener = () {
      if (!mounted) {
        return;
      }
      if (initialized != controller.value.initialized) {
        initialized = controller.value.initialized;
        setState(() {});
      }
    };
    controller.addListener(listener);
  }

  @override
  Widget build(BuildContext context) {
    if (initialized) {
      return Center(
        child: Container(
          width: double.infinity,
          child: FittedBox(
            fit: widget.betterPlayerBoxFit,
            child: SizedBox(
              width: controller.value.size?.width ?? 0,
              height: controller.value.size?.height ?? 0,
              child: VideoPlayer(controller),
              //
            ),
          ),
        ),
      );
    } else {
      return Container();
    }
  }
}
