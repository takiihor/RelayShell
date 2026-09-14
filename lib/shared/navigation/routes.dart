/// Route paths shared by feature screens and the application router.
///
/// Keeping this value object outside `app/` lets features navigate without
/// depending on the composition layer that imports every screen.
class Routes {
  const Routes._();

  static const String home = '/';
  static const String hosts = '/computers';
  static const String hostNew = '/computers/new';
  static String hostDetail(String id) => '/computers/$id';
  static String hostEdit(String id) => '/computers/$id/edit';

  static const String projects = '/projects';
  static const String projectNew = '/projects/new';
  static String projectDetail(String id) => '/projects/$id';
  static String projectEdit(String id) => '/projects/$id/edit';

  static const String sessions = '/sessions';
  static const String more = '/settings';

  static const String commands = '/settings/commands';
  static const String commandNew = '/settings/commands/new';
  static String commandEdit(String id) => '/settings/commands/$id';

  static const String keys = '/settings/keys';
  static const String forwarding = '/settings/forwarding';
  static const String settings = '/settings';
  static const String trustedKeys = '/settings/trusted-keys';
  static const String about = '/settings/about';

  static const String search = '/search';
  static const String conversation = '/conversation';
  static const String terminal = '/terminal';

  static String files(String hostId) => '/files/$hostId';
}
