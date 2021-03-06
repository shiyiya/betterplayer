import 'dart:async';

import 'package:better_player/src/controls/better_player_clickable_widget.dart';
import 'package:better_player/src/controls/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_material_progress_bar.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/core/utils.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:better_player/src/configuration/better_player_p_methond.dart';
import 'package:flutter/material.dart';
import 'package:music_volume/music_volume.dart';
import 'package:screen/screen.dart';

import 'better_player_clickable_widget.dart';

const PLAYER_ERMETHOND_LIST = [
  BetterPlayerBoxFitWithText(BoxFit.contain, text: '适应'),
  BetterPlayerBoxFitWithText(BoxFit.fill, text: '拉伸'),
  BetterPlayerBoxFitWithText(BoxFit.cover, text: '填充'),
];

class BetterPlayerMaterialControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;
  final Function(BetterPlayerController betterPlayerController, BoxFit boxFit)
      onPlayerMethondChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  BetterPlayerMaterialControls({
    Key key,
    this.onControlsVisibilityChanged,
    this.controlsConfiguration,
    this.onPlayerMethondChanged,
  })  : assert(onControlsVisibilityChanged != null),
        assert(controlsConfiguration != null),
        super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerMaterialControlsState();
  }
}

class _BetterPlayerMaterialControlsState
    extends State<BetterPlayerMaterialControls> with TickerProviderStateMixin {
  VideoPlayerValue _latestValue;
  double _latestVolume;
  bool _hideStuff = true;
  Timer _hideTimer;
  Timer _initTimer;
  Timer _showAfterExpandCollapseTimer;
  bool _dragging = false;
  bool _displayTapped = false;
  VideoPlayerController _controller;
  BetterPlayerController _betterPlayerController;

  BetterPlayerControlsConfiguration get _controlsConfiguration =>
      widget.controlsConfiguration;

  ///Min. time of buffered video to hide loading timer (in milliseconds)
  static const int _bufferingInterval = 20000;

  AnimationController sideAnimationController;
  Animation<Offset> sideAnimation;

  AnimationController sideVideoListAnimationController;
  Animation<Offset> sideVideoListAnimation;

  AnimationController sideMoreAnimationController;
  Animation<Offset> sideMoreAnimation;

  bool isLock = false;
  bool showLockIcon = false;

  void toggleHideStuff() {
    if (_sideShow) {
      toggleSide();
      return;
    }
    if (_videoListsideShow) {
      toggleVideoSide();
      return;
    }

    if (_moreSideShow) {
      toggleMoreSide();
      return;
    }

    setState(() {
      _hideStuff = !_hideStuff;
    });

    if (!_hideStuff) {
      _startHideTimer();
    }
  }

  void toggleLock() {
    isLock = !isLock;
    if (isLock) showLockIcon = true;
    setState(() {});
  }

  void toggleLockIconShow() {
    showLockIcon = !showLockIcon;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return isLock
        ? AnimatedOpacity(
            opacity: showLockIcon ? 1.0 : 0.0,
            duration: _controlsConfiguration.controlsHideTime,
            child: GestureDetector(
              onTap: toggleLockIconShow,
              child: Container(
                alignment: Alignment.centerLeft,
                color: Colors.transparent,
                child: IconButton(
                  icon: Icon(Icons.lock_outline),
                  color: _controlsConfiguration.iconsColor,
                  onPressed: toggleLock,
                ),
              ),
            ),
          )
        : MouseRegion(
            onHover: (_) {
              _cancelAndRestartTimer();
            },
            child: Stack(
              children: <Widget>[
                Column(
                  children: <Widget>[
                    AbsorbPointer(
                      absorbing: _hideStuff,
                      child: _buildAppBar(context),
                    ),
                    if (!isLock)
                      Expanded(
                        child: _latestValue.hasError
                            ? _buildErrorWidget()
                            : GestureDetector(
                                onTap: toggleHideStuff,
                                onDoubleTap: _onPlayPause,

                                //垂直
                                onVerticalDragDown: _onVerticalDragDown,
                                onVerticalDragStart: _onVerticalDragStart,
                                onVerticalDragUpdate: _onVerticalDragUpdate,
                                onVerticalDragEnd: _onVerticalDragEnd,

                                //水平滑动
                                onHorizontalDragStart: _onHorizontalDragStart,
                                onHorizontalDragDown: _onHorizontalDragDown,
                                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                                onHorizontalDragEnd: _onHorizontalDragEnd,
                                child: Stack(
                                  children: <Widget>[
                                    isLoading(_latestValue)
                                        ? _buildLoadingWidget()
                                        : _buildHitArea(),
                                    if (showTimeLine) _buildTimeLine(),
                                    if (showBrightness)
                                      Center(
                                        child: LinearProgress(
                                          brighting,
                                          Icons.brightness_6,
                                          _controlsConfiguration.iconsColor,
                                          _betterPlayerController.isFullScreen,
                                        ),
                                      ),
                                    if (showVolTip)
                                      Center(
                                        child: LinearProgress(
                                          volProgress,
                                          Icons.volume_up,
                                          _controlsConfiguration.iconsColor,
                                          _betterPlayerController.isFullScreen,
                                        ),
                                      ),
                                    if (_betterPlayerController.isFullScreen)
                                      AnimatedOpacity(
                                        opacity: _hideStuff ? 0.0 : 1.0,
                                        duration: _controlsConfiguration
                                            .controlsHideTime,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: IconButton(
                                            icon: Icon(Icons.lock_open),
                                            color: _controlsConfiguration
                                                .iconsColor,
                                            onPressed: toggleLock,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                      ),
                    if (!isLock)
                      AbsorbPointer(
                        absorbing: _hideStuff,
                        child: _buildBottomBar(context),
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: SlideTransition(
                    position: sideAnimation,
                    child: Container(
                      alignment: Alignment.topRight,
                      height: double.infinity,
                      width: MediaQuery.of(context).size.width / 5,
                      color: Colors.black.withOpacity(0.6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [2.0, 1.5, 1.25, 1.0, 0.75, 0.5]
                            .map((e) => Container(
                                  alignment: Alignment.center,
                                  child: InkWell(
                                    onTap: () {
                                      _controller.setSpeed(e);
                                      toggleSide();
                                    },
                                    child: Text(
                                      '$e x',
                                      style: TextStyle(
                                        color: _controller.value.speed == e
                                            ? _controlsConfiguration.textColor
                                                .withRed(5)
                                            : _controlsConfiguration.textColor,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: SlideTransition(
                    position: sideVideoListAnimation,
                    child: Container(
                      height: MediaQuery.of(context).size.height,
                      width: MediaQuery.of(context).size.width / 3,
                      color: Colors.black.withOpacity(0.6),
                      padding: EdgeInsets.all(10.0),
                      child: SingleChildScrollView(
                        child: Wrap(
                          alignment: WrapAlignment.start,
                          children: [
                            for (var i = 0;
                                i < _betterPlayerController.videoListLen;
                                i++)
                              InkWell(
                                onTap: () {
                                  toggleVideoSide();
                                  _betterPlayerController.ganerateVideoFn(i);
                                },
                                child: Container(
                                  padding: EdgeInsets.all(20.0),
                                  decoration: _betterPlayerController
                                              .currentVideoIndex ==
                                          i
                                      ? BoxDecoration(
                                          border: Border.all(
                                            color: _controlsConfiguration
                                                .textColor
                                                .withRed(5),
                                          ),
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(2.0)),
                                        )
                                      : null,
                                  child: Text(
                                    '${i + 1}',
                                    style: TextStyle(
                                      color: _betterPlayerController
                                                  .currentVideoIndex ==
                                              i
                                          ? _controlsConfiguration.textColor
                                              .withRed(5)
                                          : _controlsConfiguration.textColor,
                                    ),
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                buildMoreSide(),
              ],
            ),
          );
  }

  Align buildMoreSide() {
    final s = Theme.of(context).textTheme.caption.copyWith(
          color: _controlsConfiguration.textColor.withOpacity(0.5),
        );
    return Align(
      alignment: Alignment.topRight,
      child: SlideTransition(
        position: sideMoreAnimation,
        child: Container(
          height: MediaQuery.of(context).size.height,
          width: MediaQuery.of(context).size.width / 2.5,
          color: Colors.black.withOpacity(0.6),
          padding: EdgeInsets.all(10.0),
          child: ListView(children: [
            Text('播放速度', style: s),
            Row(
              // mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                  .map((e) => Expanded(
                        flex: 1,
                        child: GestureDetector(
                          onTap: () {
                            _controller.setSpeed(e);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 15),
                            alignment: Alignment.center,
                            color: Colors.transparent,
                            child: Text(
                              '$e',
                              style: TextStyle(
                                color: _controller.value.speed == e
                                    ? _controlsConfiguration.textColor
                                        .withRed(5)
                                    : _controlsConfiguration.textColor,
                              ),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            SizedBox(height: 20),
            Text('画面尺寸', style: s),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: PLAYER_ERMETHOND_LIST
                  .map(
                    (e) => Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: () {
                          widget.onPlayerMethondChanged(
                              _betterPlayerController, e.type);
                        },
                        child: Container(
                          color: Colors.transparent,
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(vertical: 15),
                          alignment: Alignment.center,
                          child: Text(
                            '${e.text}',
                            style: TextStyle(
                              color: _betterPlayerController
                                          .betterPlayerBoxFit ==
                                      e.type
                                  ? _controlsConfiguration.textColor.withRed(5)
                                  : _controlsConfiguration.textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            )
          ]),
        ),
      ),
    );
  }

  bool isLoading(VideoPlayerValue latestValue) {
    assert(latestValue != null, "Latest value can't be null");
    if (latestValue != null) {
      if (!latestValue.isPlaying && latestValue.duration == null) {
        return true;
      }

      var position = latestValue.position;
      var bufferedEndPosition = latestValue.buffered.last.end;
      if (position != null && bufferedEndPosition != null) {
        var difference = bufferedEndPosition - position;

        if (latestValue.isPlaying &&
            latestValue.isBuffering &&
            difference.inMilliseconds < _bufferingInterval) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller?.removeListener(_updateState);
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _showAfterExpandCollapseTimer?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController.videoPlayerController;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  // 横向滑动进度条
  bool showTimeLine = false;
  double horizontalPoint;
  Duration currentPlayerPosition;
  double horizontalDragTime = 0.0;

  void _onHorizontalDragDown(DragDownDetails d) async {
    horizontalPoint = d.localPosition.dx;
    currentPlayerPosition = _latestValue.position;
  }

  void _onHorizontalDragStart(DragStartDetails d) async {
    _cancelAndRestartTimer();
    setState(() {
      showTimeLine = true;
    });
  }

  void _onHorizontalDragUpdate(DragUpdateDetails d) async {
    _cancelAndRestartTimer();
    final w = MediaQuery.of(context).size.width;
    final m = (d.localPosition.dx - horizontalPoint) / w * 90; // 90s
    _betterPlayerController.seekTo(
        currentPlayerPosition + Duration(seconds: horizontalDragTime.toInt()));
    horizontalDragTime = m;

    setState(() {});
  }

  void _onHorizontalDragEnd(DragEndDetails d) async {
    _cancelAndRestartTimer();

    setState(() {
      showTimeLine = false;
    });
  }

  // = 横向滑动 end

  // |||
  double _startVerticalDragY = 0;
  double _startVerticalDragX = 0;
  double _endVerticalDragY = 0;

  bool showBrightness = false;
  double initBri;
  double brighting = 0.0;

  bool showVolTip = false;
  int initVol;
  double voling = 0.0;
  double volProgress = 0.0;

  void _onVerticalDragDown(DragDownDetails d) {
    _startVerticalDragX = d.localPosition.dx;
    _startVerticalDragY = d.localPosition.dy;
  }

  void _onVerticalDragStart(DragStartDetails d) async {
    if (_startVerticalDragX < MediaQuery.of(context).size.width / 2) {
      initBri = await Screen.brightness;
      showBrightness = true;
    } else {
      initVol = await MusicVolume.currentVolume; /*await Volume.getVol*/
      showVolTip = true;
    }
    setState(() {});
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) async {
    final w = MediaQuery.of(context).size.width;
    _endVerticalDragY = d.localPosition.dy;
    final drag = -(_endVerticalDragY - _startVerticalDragY);
    final totalHor = w / _betterPlayerController.aspectRatio -
        2 * _controlsConfiguration.controlBarHeight;
    if (_startVerticalDragX < w / 2) {
      final _ = initBri + (drag / totalHor);
      brighting = _ <= 0 ? 0.0 : _ >= 1 ? 1.0 : _;
      await Screen.setBrightness(brighting);
    } else {
      final int maxVol = await MusicVolume.maxVolume ?? 0;
      final _ = initVol + drag / totalHor * maxVol;
      voling = _ > maxVol ? maxVol.toDouble() : _ < 0.0 ? 0.0 : _;
      volProgress = voling / maxVol;
      await MusicVolume.changeVolume(_.toInt(), 0);
    }
    setState(() {});
  }

  void _onVerticalDragEnd(DragEndDetails d) async {
    if (_startVerticalDragX < MediaQuery.of(context).size.width / 2) {
      showBrightness = false;
    } else {
      showVolTip = false;
    }
    setState(() {});
  }

  Widget _buildErrorWidget() {
    if (_betterPlayerController.errorBuilder != null) {
      return _betterPlayerController.errorBuilder(context,
          _betterPlayerController.videoPlayerController.value.errorDescription);
    } else {
      return GestureDetector(
        onTap: toggleHideStuff,
        child: Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
            color: Colors.black.withOpacity(0.4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.warning,
                color: _controlsConfiguration.iconsColor,
                size: 42,
              ),
              Text(
                _controlsConfiguration.defaultErrorText,
                style: TextStyle(color: _controlsConfiguration.textColor),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildAppBar(BuildContext context) {
    return AnimatedOpacity(
      opacity: _hideStuff ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        padding: EdgeInsets.only(right: 12),
        decoration: _controlsConfiguration.controlAppBarDecoration ??
            BoxDecoration(color: _controlsConfiguration.controlBarColor),
        height: _controlsConfiguration.controlBarHeight,
        child: Row(
          children: [
            if (Navigator.of(context).canPop())
              IconButton(
                icon: Icon(Icons.arrow_back,
                    color: _controlsConfiguration.iconsColor),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            Expanded(
              child: Text(
                _betterPlayerController.appBarTitle ?? '',
                style: TextStyle(color: _controlsConfiguration.textColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.av_timer,
                color: _controlsConfiguration.iconsColor,
              ),
              onPressed: toggleSide,
            ),
            if (_betterPlayerController.isFullScreen)
              IconButton(
                icon: Icon(
                  Icons.more_horiz,
                  color: _controlsConfiguration.iconsColor,
                ),
                onPressed: toggleMoreSide,
              )
          ],
        ),
      ),
    );
  }

  bool _sideShow = false; // 倍速
  bool _videoListsideShow = false;
  bool _moreSideShow = false;

  void toggleMoreSide() {
    if (!_betterPlayerController.isFullScreen) return;
    if (_moreSideShow) {
      sideMoreAnimationController.reverse();
      _moreSideShow = false;
      return;
    } else if (!_moreSideShow) {
      sideMoreAnimationController.forward();
      _hideStuff = true;
      _moreSideShow = true;
      setState(() {});
      return;
    }
  }

  void toggleVideoSide() {
    if (_videoListsideShow) {
      sideVideoListAnimationController.reverse();
      _videoListsideShow = false;
      return;
    } else if (!_videoListsideShow) {
      sideVideoListAnimationController.forward();
      _hideStuff = true;
      _videoListsideShow = true;
      setState(() {});
      return;
    }
  }

  void toggleSide() {
    if (_sideShow) {
      //关闭
      sideAnimationController.reverse();
      _sideShow = false;
    } else {
      //打开side
      sideAnimationController.forward();
      _hideStuff = true;
      _sideShow = true;
    }
    setState(() {});
  }

  AnimatedOpacity _buildBottomBar(BuildContext context) {
    return AnimatedOpacity(
      opacity: _hideStuff ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        decoration: _controlsConfiguration.controlBarDecoration ??
            BoxDecoration(color: _controlsConfiguration.controlBarColor),
        height: _controlsConfiguration.controlBarHeight,
        child: Row(
          children: [
            _controlsConfiguration.enablePlayPause
                ? _buildPlayPause(_controller)
                : const SizedBox(),
            _betterPlayerController.isLiveStream()
                ? _buildLiveWidget()
                : _controlsConfiguration.enableProgressText
                    ? _buildPosition()
                    : const SizedBox(),
            _betterPlayerController.isLiveStream()
                ? const SizedBox()
                : _controlsConfiguration.enableProgressBar
                    ? _buildProgressBar()
                    : const SizedBox(),
            if (_betterPlayerController.isFullScreen)
              BetterPlayerMaterialClickableWidget(
                child: Container(
                  height: double.infinity,
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '选集',
                    style: TextStyle(color: _controlsConfiguration.textColor),
                  ),
                ),
                onTap: toggleVideoSide,
              ),
            _controlsConfiguration.enableMute
                ? _buildMuteButton(_controller)
                : const SizedBox(),
            _controlsConfiguration.enableFullscreen
                ? _buildExpandButton()
                : const SizedBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveWidget() {
    return Expanded(
      child: Text(
        _controlsConfiguration.liveText,
        style: TextStyle(
          color: _controlsConfiguration.liveTextColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildExpandButton() {
    final isFullScreen = _betterPlayerController.isFullScreen;
    return BetterPlayerMaterialClickableWidget(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: _hideStuff ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: Container(
          height: _controlsConfiguration.controlBarHeight,
          margin: EdgeInsets.symmetric(horizontal: isFullScreen ? 10 : 4),
          padding: isFullScreen
              ? EdgeInsets.only(right: 15)
              : EdgeInsets.symmetric(horizontal: 10),
          child: Center(
            child: Icon(
              _betterPlayerController.isFullScreen
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen,
              color: _controlsConfiguration.iconsColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeLine() {
    final duration = _latestValue != null && _latestValue.duration != null
        ? _latestValue.duration
        : Duration.zero;
    return Center(
      child: Container(
        padding: _betterPlayerController.isFullScreen
            ? EdgeInsets.all(20)
            : EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(2.0)),
          color: Colors.black.withOpacity(0.6),
        ),
        child: Text(
          '${formatDuration(currentPlayerPosition + Duration(seconds: horizontalDragTime.toInt()))} / ${formatDuration(duration)}',
          style: TextStyle(color: _controlsConfiguration.textColor),
        ),
      ),
    );
  }

  Widget _buildHitArea() {
    return AbsorbPointer(
      absorbing: _hideStuff,
      child: Container(
        color: Colors.transparent,
        child: Center(
          child: AnimatedOpacity(
            opacity:
                _latestValue != null && !_latestValue.isPlaying && !_dragging
                    ? 1.0
                    : 0.0,
            duration: _controlsConfiguration.controlsHideTime,
            child: Stack(
              children: [
                _buildPlayReplayButton(),
                _buildNextVideoWidget(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayReplayButton() {
    bool isFinished = _latestValue?.position != null &&
        _latestValue?.duration != null &&
        _latestValue.position >= _latestValue.duration;
    IconData _hitAreaIconData = isFinished ? Icons.replay : Icons.play_arrow;
    return BetterPlayerMaterialClickableWidget(
      child: Align(
        alignment: Alignment.center,
        child: Container(
          decoration: BoxDecoration(
            color: _controlsConfiguration.controlBarColor,
            borderRadius: BorderRadius.circular(48),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Icon(
                  _hitAreaIconData,
                  size: 32,
                  color: _controlsConfiguration.iconsColor,
                )
              ],
            ),
          ),
        ),
      ),
      onTap: () {
        if (_sideShow) {
          toggleSide();
          return;
        }
        if (_videoListsideShow) {
          toggleVideoSide();
          return;
        }

        if (_latestValue != null && _latestValue.isPlaying) {
          if (_displayTapped) {
            setState(() {
              _hideStuff = true;
            });
          } else
            _cancelAndRestartTimer();
        } else {
          _onPlayPause();

          setState(() {
            _hideStuff = true;
          });
        }
      },
    );
  }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int>(
      stream: _betterPlayerController.nextVideoTimeStreamController.stream,
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return BetterPlayerMaterialClickableWidget(
            onTap: () {
              _betterPlayerController.playNextVideo();
            },
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 4, right: 4),
                decoration: BoxDecoration(
                  color: _controlsConfiguration.controlBarColor,
                  borderRadius: BorderRadius.circular(48),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "Next video in ${snapshot.data} ...",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  Widget _buildMuteButton(
    VideoPlayerController controller,
  ) {
    return BetterPlayerMaterialClickableWidget(
      onTap: () {
        _cancelAndRestartTimer();
        if (_latestValue.volume == 0) {
          _betterPlayerController.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller.value.volume;
          _betterPlayerController.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: _hideStuff ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRect(
          child: Container(
            child: Container(
              height: _controlsConfiguration.controlBarHeight,
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(
                (_latestValue != null && _latestValue.volume > 0)
                    ? _controlsConfiguration.muteIcon
                    : _controlsConfiguration.unMuteIcon,
                color: _controlsConfiguration.iconsColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayPause(VideoPlayerController controller) {
    final isFullScreen = _betterPlayerController.isFullScreen;
    return BetterPlayerMaterialClickableWidget(
      onTap: _onPlayPause,
      child: Container(
        height: _controlsConfiguration.controlBarHeight,
        margin: EdgeInsets.symmetric(horizontal: isFullScreen ? 10 : 4),
        padding: EdgeInsets.symmetric(horizontal: isFullScreen ? 15 : 10),
        child: Icon(
          controller.value.isPlaying
              ? _controlsConfiguration.pauseIcon
              : _controlsConfiguration.playIcon,
          color: _controlsConfiguration.iconsColor,
        ),
      ),
    );
  }

  Widget _buildPosition() {
    final position = _latestValue != null && _latestValue.position != null
        ? _latestValue.position
        : Duration.zero;
    final duration = _latestValue != null && _latestValue.duration != null
        ? _latestValue.duration
        : Duration.zero;

    return Padding(
      padding: EdgeInsets.only(right: 25),
      child: Text(
        '${formatDuration(position)}/${formatDuration(duration)}',
        style: TextStyle(
          fontSize: 12,
          color: _controlsConfiguration.textColor,
        ),
      ),
    );
  }

  void _cancelAndRestartTimer() {
    _hideTimer?.cancel();
    _startHideTimer();

    setState(() {
      _hideStuff = false;
      _displayTapped = true;
    });
  }

  Future<Null> _initialize() async {
    _controller.addListener(_updateState);

    sideAnimationController = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
    sideAnimation = Tween(begin: Offset(1, 0), end: Offset(0, 0))
        .animate(sideAnimationController);

    if (_betterPlayerController.videoListLen > 0) {
      sideVideoListAnimationController = AnimationController(
          duration: const Duration(milliseconds: 200), vsync: this);
      sideVideoListAnimation = Tween(begin: Offset(1, 0), end: Offset(0, 0))
          .animate(sideVideoListAnimationController);
    }

    sideMoreAnimationController = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this);
    sideMoreAnimation = Tween(begin: Offset(1, 0), end: Offset(0, 0))
        .animate(sideMoreAnimationController);

    _updateState();

    if ((_controller.value != null && _controller.value.isPlaying) ||
        _betterPlayerController.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(Duration(milliseconds: 200), () {
        setState(() {
          _hideStuff = false;
        });
      });
    }
  }

  void _onExpandCollapse() {
    setState(() {
      _hideStuff = true;

      _betterPlayerController.toggleFullScreen();
      _showAfterExpandCollapseTimer =
          Timer(_controlsConfiguration.controlsHideTime, () {
        setState(() {
          _cancelAndRestartTimer();
        });
      });
    });
  }

  void _onPlayPause() {
    if (_sideShow) {
      toggleSide();
      return;
    }

    bool isFinished = false;
    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue.position >= _latestValue.duration;
    }

    setState(() {
      if (_controller.value.isPlaying) {
        _hideStuff = false;
        _hideTimer?.cancel();
        _betterPlayerController.pause();
      } else {
        _cancelAndRestartTimer();

        if (!_controller.value.initialized) {
          if (_betterPlayerController.betterPlayerDataSource.liveStream) {
            _betterPlayerController.play();
            _betterPlayerController.cancelNextVideoTimer();
          }
        } else {
          if (isFinished) {
            _betterPlayerController.seekTo(Duration(seconds: 0));
          }
          _betterPlayerController.play();
          _betterPlayerController.cancelNextVideoTimer();
        }
      }
    });
  }

  void _startHideTimer() {
    _hideTimer = Timer(const Duration(seconds: 3), () {
      setState(() {
        _hideStuff = true;
      });
    });
  }

  void _updateState() {
    _latestValue = _controller.value;
    if (_latestValue.hasError) _hideStuff = false;
    setState(() {});
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: 10),
        child: BetterPlayerMaterialVideoProgressBar(
          _controller,
          _betterPlayerController,
          onDragStart: () {
            setState(() {
              _dragging = true;
            });
            _hideTimer?.cancel();
          },
          onDragEnd: () {
            setState(() {
              _dragging = false;
            });
            _startHideTimer();
          },
          colors: BetterPlayerProgressColors(
              playedColor: _controlsConfiguration.progressBarPlayedColor,
              handleColor: _controlsConfiguration.progressBarHandleColor,
              bufferedColor: _controlsConfiguration.progressBarBufferedColor,
              backgroundColor:
                  _controlsConfiguration.progressBarBackgroundColor),
        ),
      ),
    );
  }

  void _onPlayerHide() {
    widget.onControlsVisibilityChanged(!_hideStuff);
  }

  Widget _buildLoadingWidget() {
    return GestureDetector(
      onTap: toggleHideStuff,
      child: Container(
        color: Colors.transparent,
        alignment: Alignment.center,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            _controlsConfiguration.iconsColor,
          ),
        ),
      ),
    );
  }
}

class LinearProgress extends StatelessWidget {
  final double len;
  final IconData icon;
  final Color color;
  final bool isFullScreen;

  LinearProgress(this.len, this.icon, this.color, this.isFullScreen);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      width: isFullScreen
          ? MediaQuery.of(context).size.width / 6
          : MediaQuery.of(context).size.width / 4,
      padding: EdgeInsets.all(8),
      child: Row(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: len,
              backgroundColor: Colors.white.withOpacity(0.5),
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
            ),
          )
        ],
      ),
    );
  }
}
