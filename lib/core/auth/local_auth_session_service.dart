import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/core/service/anon_session_service.dart';

class LocalAuthSessionService implements AuthSessionService {
  final AnonSessionService anonSessionService;

  const LocalAuthSessionService({
    required this.anonSessionService,
  });

  @override
  String get currentUserId => anonSessionService.anonId;

  @override
  bool get isSignedIn => true;

  @override
  bool get isAnonymous => true;
}