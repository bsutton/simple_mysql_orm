import 'package:simple_mysql_orm/simple_mysql_orm.dart';
import 'package:simple_mysql_orm/src/dao/tenant.dart';
import '../model/member.dart';

class MemberDao extends DaoTenant<Member> {
  MemberDao() : super(tableName: tablename, tenantColumnName: 'publisherId');

  MemberDao.withDb(Db db)
      : super.withDb(db, tableName: tablename, tenantColumnName: 'publisherId');

  Future<Member?> getByName(String name) async {
    final row = await getByField('email', name);

    if (row == null) {
      return null;
    }

    return row;
  }

  static String get tablename => 'member';

  @override
  Member fromRow(Row row) => Member.fromRow(row);

  Future<List<Member>> search(String name) async => query(
      'select * from $tablename where name like ? and publisherId = ?',
      ['%$name%', Tenant.tenantId]);
}
