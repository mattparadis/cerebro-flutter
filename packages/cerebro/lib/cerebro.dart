/// cerebro: headless screenshot capture and navigation map for Flutter apps.
library;

export 'src/capture.dart' show ContrastReport, LowContrast, ScenarioReset, ScenarioSetup, Tappable, Cerebro, collectTappables, measureTextContrast, splitOccluded;
export 'src/driver.dart';
export 'src/config.dart';
export 'src/contrast.dart';
export 'src/diff.dart';
export 'src/edges.dart';
export 'src/fonts.dart';
export 'src/lint.dart';
export 'src/map_writer.dart';
export 'src/routes.dart';
export 'src/nav_map.dart' show NavMap, NavNode, NavEdgeGroup;
