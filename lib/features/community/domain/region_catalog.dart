class RegionCatalog {
  static const List<String> labels = <String>[
    '서울',
    '경기',
    '강원',
    '충북',
    '충남',
    '전북',
    '전남',
    '경북',
    '경남',
    '제주',
  ];

  static String? normalize(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return null;

    const map = <String, String>{
      '서울': '서울',
      '서울시': '서울',
      '서울특별시': '서울',

      '경기': '경기',
      '경기도': '경기',

      '강원': '강원',
      '강원도': '강원',
      '강원특별자치도': '강원',

      '충북': '충북',
      '충청북도': '충북',

      '충남': '충남',
      '충청남도': '충남',

      '전북': '전북',
      '전라북도': '전북',
      '전북특별자치도': '전북',

      '전남': '전남',
      '전라남도': '전남',

      '경북': '경북',
      '경상북도': '경북',

      '경남': '경남',
      '경상남도': '경남',

      '제주': '제주',
      '제주도': '제주',
      '제주특별자치도': '제주',
    };

    return map[value] ?? value;
  }
}