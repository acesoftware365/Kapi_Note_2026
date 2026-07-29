class AudioAssets {
  AudioAssets._();

  static const menuTheme = 'music_for_game/menu_theme_loop.wav';
  static const gameplayLoop = 'music_for_game/gameplay_loop.wav';
  static const resultsTheme = 'music_for_game/results_theme.wav';
  static const victoryMusic = 'music_for_game/victory_music.wav';
  static const defeatMusic = 'music_for_game/defeat_music.wav';

  static const buttonTap = 'sfx_for_game/button_tap.wav';
  static const dominoPlace = 'sfx_for_game/domino_place.wav';
  static const dominoLastTile = 'sfx_for_game/domino_last_tile.wav';
  static const dominoPass = 'sfx_for_game/domino_pass.wav';
  static const dominoBlocked = 'sfx_for_game/domino_blocked.wav';
  static const dominoShuffle = 'sfx_for_game/domino_shuffle.wav';
  static const dominoDraw = 'sfx_for_game/domino_draw.wav';
  static const dominoDouble = 'sfx_for_game/domino_double.wav';
  static const scoreIncrease = 'sfx_for_game/score_increase.wav';
  static const scoreDecrease = 'sfx_for_game/score_decrease.wav';
  static const turnNotification = 'sfx_for_game/turn_notification.wav';
  static const countdownTick = 'sfx_for_game/countdown_tick.wav';
  static const timerEnd = 'sfx_for_game/timer_end.wav';
  static const success = 'sfx_for_game/success.wav';
  static const error = 'sfx_for_game/error.wav';
  static const celebration = 'sfx_for_game/celebration.wav';
  static const gameStart = 'sfx_for_game/game_start.wav';
  static const gameOver = 'sfx_for_game/game_over.wav';
  static const roundWin = 'sfx_for_game/round_win.wav';
  static const invalidMove = 'sfx_for_game/invalid_move.wav';
  static const playerJoined = 'sfx_for_game/player_joined.wav';
  static const playerLeft = 'sfx_for_game/player_left.wav';
  static const messageReceived = 'sfx_for_game/message_received.wav';

  static const music = <String, String>{
    'Menu Theme': menuTheme,
    'Gameplay Loop': gameplayLoop,
    'Results Theme': resultsTheme,
    'Victory Music': victoryMusic,
    'Defeat Music': defeatMusic,
  };

  static const soundEffects = <String, String>{
    'Button Tap': buttonTap,
    'Domino Place': dominoPlace,
    'Domino Last Tile': dominoLastTile,
    'Domino Pass': dominoPass,
    'Domino Blocked': dominoBlocked,
    'Domino Shuffle': dominoShuffle,
    'Domino Draw': dominoDraw,
    'Domino Double': dominoDouble,
    'Score Increase': scoreIncrease,
    'Score Decrease': scoreDecrease,
    'Turn Notification': turnNotification,
    'Countdown Tick': countdownTick,
    'Timer End': timerEnd,
    'Success': success,
    'Error': error,
    'Celebration': celebration,
    'Game Start': gameStart,
    'Game Over': gameOver,
    'Round Win': roundWin,
    'Invalid Move': invalidMove,
    'Player Joined': playerJoined,
    'Player Left': playerLeft,
    'Message Received': messageReceived,
  };

  static bool loops(String path) =>
      path == menuTheme || path == gameplayLoop || path == resultsTheme;
}
