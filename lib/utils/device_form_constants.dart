class DeviceFormConstants {
  static const double defaultPadding = 16.0;
  static const double cardElevation = 2.0;
  static final List<String> colleges = [
    'كلية الهندسة',
    'كلية الطب',
    'كلية الحاسب الآلي',
    'كلية العلوم',
    'كلية الإدارة والاقتصاد',
    'اخرى',
  ];

  static final List<String> models = [
    'HP Compaq 6005 Pro Microtower PC',
    'Lenovo A740 AIO',
    'HP Z2 Mini G4 Workstation',
    'HP Elite Mini 800 G9 Desktop PC',
    'HP EliteOne 800 G3 All-in-One PC',
    'اخرى',
  ];

  static final List<String> processors = [
    'Core 2',
    'Core i3',
    'Core i5',
    'Core i7',
    'Core i9',
    'اخرى',
  ];

  // --- [تمت الإضافة] --- قائمة بأحجام الرام
  static final List<String> ramSizes = [
    '4 GB',
    '8 GB',
    '16 GB',
    '32 GB',
    '64 GB',
    'اخرى',
  ];

  static final List<String> storageTypes = [
    'SSD',
    'HDD',
    'NVME',
    'اخرى',
  ];

  static final List<String> storageSizes = [
    '128 GB',
    '256 GB',
    '512 GB',
    '1 TB',
    '2 TB',
    'اخرى',
  ];

  static final List<String> osVersions = [
    'Windows 7',
    'Windows 10',
    'Windows 11',
    'macOS',
    'Linux',
    'اخرى',
  ];

  static final Map<String, List<String>> departments = {
    'كلية الهندسة': [
      'قسم الهندسة الكهربائية',
      'قسم الهندسة المدنية',
      'قسم الهندسة الميكانيكية',
      'قسم الهندسة الصناعية',
      'اخرى',
    ],
    'كلية الطب': [
      'قسم الطب البشري',
      'قسم طب الأسنان',
      'قسم العلوم الطبية التطبيقية',
      'اخرى',
    ],
    'كلية الحاسب الآلي': [
      'قسم علوم الحاسب',
      'قسم هندسة الحاسب والشبكات',
      'قسم علم البيانات',
      'قسم الذكاء الاصطناعي',
      'قسم هندسة البرمجيات',
      'قسم الامن السبراني',
      'اخرى',
    ],
    'كلية العلوم': [
      'قسم الرياضيات',
      'قسم الفيزياء',
      'قسم الكيمياء',
      'قسم الأحياء',
      'اخرى',
    ],
    'كلية الإدارة والاقتصاد': [
      'قسم إدارة الأعمال',
      'قسم المحاسبة',
      'قسم الاقتصاد',
      'قسم التسويق',
      'اخرى',
    ],
    'اخرى': [
      'اخرى',
    ]
  };

  static final List<String> floors = [
    'الدور الأرضي',
    'الدور الأول',
    'الدور الثاني',
    'الدور الثالث',
  ];

  static final List<String> labTypes = [
    'معمل',
    'مكتب',
    'قاعة',
    'مستودع',
    'أخرى',
  ];
}
