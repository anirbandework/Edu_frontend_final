// lib/core/utils/org_session.dart
class OrgSession {
  static String? _name;
  static String? _orgId;
  static String? _code;
  static String? _organisationId;

  static String? get name => _name;
  static String? get orgId => _orgId;
  static String? get code => _code;
  static String? get organisationId => _organisationId;

  static void setData({
    required String name,
    required String orgId,
    String? code,
    String? organisationId,
  }) {
    _name = name;
    _orgId = orgId;
    _code = code;
    _organisationId = organisationId;
  }

  static void clearData() {
    _name = null;
    _orgId = null;
    _code = null;
    _organisationId = null;
  }

  static bool get hasOrgData => _name != null && _orgId != null;
}
