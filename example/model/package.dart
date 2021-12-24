import 'package:simple_mysql_orm/simple_mysql_orm.dart';

class Package extends Entity<Package> {
  factory Package({required String name, bool private = true}) =>
      Package._internal(
          id: Entity.notSet,
          name: name,
          latestVersion: '1.0.0',
          private: private,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          downloads: 0);

  factory Package.fromRow(Row row) {
    final id = row.fieldAsInt('id');
    final name = row.fieldAsString('name');
    final latestVersion = row.fieldAsString('latestVersion');
    final private = row.fieldAsBool('private');
    final createdAt = row.fieldAsDateTime('createdAt');
    final updatedAt = row.fieldAsDateTime('updatedAt');
    final downloads = row.fieldAsInt('downloads');

    return Package._internal(
        id: id,
        name: name,
        //  publisherId: publisherId,
        latestVersion: latestVersion,
        private: private,
        createdAt: createdAt,
        updatedAt: updatedAt,
        downloads: downloads);
  }

  Package._internal(
      {required int id,
      required this.name,
      required this.latestVersion,
      required this.private,
      required this.createdAt,
      required this.updatedAt,
      required this.downloads})
      : super(id);

  /// name of this package.
  late String name;

  /// The latest version no. for this package.
  late String latestVersion;

  /// If this package is private
  late bool private;

  // When this package was first uploaded
  late DateTime createdAt;

  /// The last time the package was updated.
  late DateTime updatedAt;

  /// total number of downloads for all versions of this package.
  late int downloads;

  @override
  FieldList get fields => [
        'name',
        'latestVersion',
        'private',
        'createdAt',
        'updatedAt',
        'downloads',
      ];

  @override
  ValueList get values =>
      [name, latestVersion, private, createdAt, updatedAt, downloads];
}
