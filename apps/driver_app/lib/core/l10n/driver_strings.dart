// Abra Driver — multilingual string table
// Covers English (en), Telugu (te), Hindi (hi)

const Map<String, Map<String, String>> driverStrings = {
  // ── Navigation / tabs ──
  'tab_home': {'en': 'Home', 'te': 'హోమ్', 'hi': 'होम'},
  'tab_trip': {'en': 'Your Trip', 'te': 'మీ ట్రిప్', 'hi': 'आपकी ट्रिप'},
  'tab_reports': {'en': 'Reports', 'te': 'రిపోర్ట్లు', 'hi': 'रिपोर्ट'},
  'tab_alerts': {'en': 'Alerts', 'te': 'అలర్ట్లు', 'hi': 'सूचनाएँ'},
  'tab_profile': {'en': 'Profile', 'te': 'ప్రొఫైల్', 'hi': 'प्रोफ़ाइल'},

  // ── Home screen ──
  'hello': {'en': 'Hello', 'te': 'నమస్కారం', 'hi': 'नमस्ते'},
  'no_trip_today': {'en': 'No Active Trip Today', 'te': 'ఈరోజు ట్రిప్ లేదు', 'hi': 'आज कोई ट्रिप नहीं'},
  'trips_appear_here': {
    'en': 'New trips from your operator will appear here.',
    'te': 'మీ ఆపరేటర్ కొత్త ట్రిప్‌లు ఇక్కడ కనిపిస్తాయి.',
    'hi': 'ऑपरेटर की नई ट्रिप यहाँ दिखेंगी।',
  },
  'upcoming_trips': {'en': 'Upcoming Assigned Trips', 'te': 'రానున్న ట్రిప్‌లు', 'hi': 'आगामी ट्रिप'},
  'open_trip': {'en': 'Open Trip Details & Passengers', 'te': 'ట్రిప్ వివరాలు తెరవండి', 'hi': 'ट्रिप विवरण खोलें'},

  // ── Trip actions ──
  'start_boarding': {'en': 'Start Boarding', 'te': 'బోర్డింగ్ ప్రారంభించండి', 'hi': 'बोर्डिंग शुरू करें'},
  'start_trip': {'en': 'Start Trip (Pre-Trip Check)', 'te': 'ట్రిప్ ప్రారంభించు (చెక్‌లిస్ట్)', 'hi': 'ट्रिप शुरू करें (चेकलिस्ट)'},
  'report_delay': {'en': 'Report Delay', 'te': 'ఆలస్యం నివేదించు', 'hi': 'देरी बताएँ'},
  'end_trip': {'en': 'End Trip', 'te': 'ట్రిప్ ముగించు', 'hi': 'ट्रिप समाप्त करें'},
  'resume_trip': {'en': 'Resume Trip', 'te': 'ట్రిప్ కొనసాగించు', 'hi': 'ट्रिप फिर शुरू करें'},
  'check_in': {'en': 'Check In', 'te': 'చెక్ ఇన్', 'hi': 'चेक इन'},
  'checked_in': {'en': 'Checked In', 'te': 'చెక్ ఇన్ అయింది', 'hi': 'चेक इन हो गया'},
  'scan_ticket': {'en': 'Scan Ticket', 'te': 'టికెట్ స్కాన్', 'hi': 'टिकट स्कैन'},
  'verify_check_in': {'en': 'Verify & Check In', 'te': 'ధృవీకరించి చెక్ ఇన్ చేయండి', 'hi': 'सत्यापित करें और चेक इन करें'},

  // ── Delay sheet ──
  'report_delay_title': {'en': 'Report Trip Delay', 'te': 'ట్రిప్ ఆలస్యం నివేదించు', 'hi': 'ट्रिप देरी बताएँ'},
  'how_late': {'en': 'How late are you? (minutes)', 'te': 'ఎంత ఆలస్యం? (నిమిషాలు)', 'hi': 'कितनी देरी? (मिनट)'},
  'delay_reason': {'en': 'Reason for delay', 'te': 'ఆలస్య కారణం', 'hi': 'देरी का कारण'},
  'confirm_notify': {'en': 'Confirm & Notify Passengers', 'te': 'నిర్ధారించి ప్రయాణికులకు తెలియజేయండి', 'hi': 'पुष्टि करें और यात्रियों को सूचित करें'},
  'traffic': {'en': 'Traffic', 'te': 'ట్రాఫిక్', 'hi': 'ट्रैफ़िक'},
  'breakdown': {'en': 'Breakdown', 'te': 'బ్రేక్‌డౌన్', 'hi': 'खराबी'},
  'weather': {'en': 'Weather', 'te': 'వాతావరణం', 'hi': 'मौसम'},
  'police_check': {'en': 'Police Check', 'te': 'పోలీస్ తనిఖీ', 'hi': 'पुलिस जाँच'},

  // ── Passengers ──
  'passengers': {'en': 'Passengers', 'te': 'ప్రయాణికులు', 'hi': 'यात्री'},
  'boarding_at': {'en': 'Boarding at', 'te': 'బోర్డింగ్ పాయింట్', 'hi': 'बोर्डिंग पर'},
  'no_passengers': {'en': 'No bookings on this trip yet.', 'te': 'ఈ ట్రిప్‌లో ఇంకా బుకింగ్ లేదు.', 'hi': 'इस ट्रिप में अभी कोई बुकिंग नहीं।'},

  // ── Tracking ──
  'location_active': {'en': 'Location Sharing  Active', 'te': 'లొకేషన్ షేరింగ్  ఆన్', 'hi': 'लोकेशन शेयरिंग  चालू'},
  'progress_covered': {'en': '% covered', 'te': '% పూర్తైంది', 'hi': '% पूरा'},
  'next_stop': {'en': 'Next:', 'te': 'తదుపరి:', 'hi': 'अगला:'},
  'gps_live': {'en': 'GPS • just now', 'te': 'GPS • ఇప్పుడే', 'hi': 'GPS • अभी'},

  // ── SOS ──
  'sos_title': {'en': 'Emergency SOS', 'te': 'అత్యవసర SOS', 'hi': 'आपातकालीन SOS'},
  'what_happened': {'en': 'What happened?', 'te': 'ఏమి జరిగింది?', 'hi': 'क्या हुआ?'},
  'send_sos': {'en': 'Send SOS', 'te': 'SOS పంపండి', 'hi': 'SOS भेजें'},
  'sos_accident': {'en': 'Accident', 'te': 'ప్రమాదం', 'hi': 'दुर्घटना'},
  'sos_breakdown': {'en': 'Breakdown', 'te': 'బ్రేక్‌డౌన్', 'hi': 'खराबी'},
  'sos_medical': {'en': 'Medical Emergency', 'te': 'వైద్య అత్యవసరం', 'hi': 'चिकित्सा आपातकाल'},
  'sos_threat': {'en': 'Threat or Fight', 'te': 'బెదిరింపు లేదా గొడవ', 'hi': 'धमकी या झगड़ा'},

  // ── Reports ──
  'reports_intro': {
    'en': 'Your company asks you for these reports. Send them on time.',
    'te': 'మీ కంపెనీ ఈ రిపోర్ట్‌లు అడుగుతోంది. సకాలంలో పంపండి.',
    'hi': 'आपकी कंपनी ये रिपोर्ट माँगती है। समय पर भेजें।',
  },
  'to_send': {'en': 'To Send', 'te': 'పంపవలసినవి', 'hi': 'भेजने के लिए'},
  'report_now': {'en': 'Report Something Now', 'te': 'ఇప్పుడు నివేదించు', 'hi': 'अभी रिपोर्ट करें'},
  'sent_by_you': {'en': 'Sent by You', 'te': 'మీరు పంపినవి', 'hi': 'आपने भेजी'},
  'save_draft': {'en': 'Save Draft', 'te': 'డ్రాఫ్ట్ సేవ్ చేయి', 'hi': 'ड्राफ्ट सहेजें'},
  'send_report': {'en': 'Send Report', 'te': 'రిపోర్ట్ పంపండి', 'hi': 'रिपोर्ट भेजें'},
  'attach_receipt': {'en': 'Attach Bill or Receipts', 'te': 'బిల్లు లేదా రసీదు జోడించండి', 'hi': 'बिल या रसीद लगाएँ'},
  'receipt_attached': {'en': 'Attached', 'te': 'జోడించారు', 'hi': 'जोड़ा गया'},

  // ── Profile ──
  'profile': {'en': 'Driver Profile', 'te': 'డ్రైవర్ ప్రొఫైల్', 'hi': 'ड्राइवर प्रोफ़ाइल'},
  'licence': {'en': 'Licence No.', 'te': 'లైసెన్స్ నం.', 'hi': 'लाइसेंस नं.'},
  'valid_till': {'en': 'Valid Till', 'te': 'చెల్లు వరకు', 'hi': 'मान्य तक'},
  'company': {'en': 'Company', 'te': 'కంపెనీ', 'hi': 'कंपनी'},
  'phone': {'en': 'Phone', 'te': 'ఫోన్', 'hi': 'फ़ोन'},
  'trips_done': {'en': 'Trips Done', 'te': 'పూర్తయిన ట్రిప్‌లు', 'hi': 'पूरी ट्रिप'},
  'upcoming': {'en': 'Upcoming', 'te': 'రానున్నవి', 'hi': 'आगामी'},
  'sign_out': {'en': 'Sign Out', 'te': 'సైన్ అవుట్', 'hi': 'साइन आउट'},
  'language': {'en': 'Language', 'te': 'భాష', 'hi': 'भाषा'},

  // ── Notifications ──
  'notifications_title': {'en': 'Notifications', 'te': 'నోటిఫికేషన్‌లు', 'hi': 'सूचनाएँ'},
  'mark_all_read': {'en': 'Mark all read', 'te': 'అన్నీ చదివినట్లు గుర్తించు', 'hi': 'सब पढ़ा हुआ करें'},
  'no_notifications': {'en': 'No notifications', 'te': 'నోటిఫికేషన్‌లు లేవు', 'hi': 'कोई सूचना नहीं'},

  // ── AI assistant suggestions ──
  'ai_greeting': {
    'en': 'Hello! Tap a suggestion or type your question. I can check your next stop, count boarding passengers, find missing check-ins, or report a delay.',
    'te': 'నమస్కారం! ఒక సూచన నొక్కండి లేదా మీ ప్రశ్న టైప్ చేయండి.',
    'hi': 'नमस्ते! कोई सुझाव चुनें या अपना सवाल टाइप करें।',
  },
  'ai_next_stop': {'en': 'Next stop', 'te': 'తదుపరి స్టాప్', 'hi': 'अगला स्टॉप'},
  'ai_who_missing': {'en': 'Who has not checked in?', 'te': 'ఎవరు చెక్ ఇన్ కాలేదు?', 'hi': 'किसने चेक इन नहीं किया?'},
  'ai_how_many_board': {'en': 'How many board at next stop?', 'te': 'తదుపరి స్టాప్‌లో ఎంత మంది ఎక్కుతారు?', 'hi': 'अगले स्टॉप पर कितने चढ़ेंगे?'},
  'ai_report_delay': {'en': 'Report 30 min delay', 'te': '30 నిమిషాల ఆలస్యం నివేదించు', 'hi': '30 मिनट देरी बताएँ'},
  'ai_trip_summary': {'en': 'Trip summary', 'te': 'ట్రిప్ సారాంశం', 'hi': 'ट्रिप सारांश'},
};

/// Look up a translated string. Falls back to English if key/lang missing.
String t(String key, String lang) {
  return driverStrings[key]?[lang] ?? driverStrings[key]?['en'] ?? key;
}
