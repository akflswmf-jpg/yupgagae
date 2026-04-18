class CurrentUser {
  final String userId;
  final String industryId;

  const CurrentUser({
    required this.userId,
    required this.industryId,
  });
}

const demoUser = CurrentUser(
  userId: 'demo',
  industryId: 'cafe',
);