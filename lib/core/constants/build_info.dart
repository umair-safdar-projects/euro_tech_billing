abstract final class BuildInfo {
  static const version = '1.0.1';
  static const buildNumber = '2';
  static const sourceRevision = String.fromEnvironment(
    'APP_BUILD_SHA',
    defaultValue: 'local',
  );
  static const pipelineRun = String.fromEnvironment(
    'APP_BUILD_RUN',
    defaultValue: 'local',
  );

  static String get shortRevision => sourceRevision == 'local'
      ? sourceRevision
      : sourceRevision.substring(0, sourceRevision.length.clamp(0, 7));

  static String get display =>
      '$version+$buildNumber • $shortRevision • run $pipelineRun';
}
