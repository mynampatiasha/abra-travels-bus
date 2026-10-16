import '../models/ai_models.dart';

class AiNlpService {
  static const Map<String, String> cityAliases = {
    'bangalore': 'Bengaluru',
    'bengaluru': 'Bengaluru',
    'blr': 'Bengaluru',
    'hyd': 'Hyderabad',
    'hyderabad': 'Hyderabad',
    'chennai': 'Chennai',
    'madras': 'Chennai',
    'vizag': 'Visakhapatnam',
    'visakhapatnam': 'Visakhapatnam',
    'mumbai': 'Mumbai',
    'bombay': 'Mumbai',
    'kochi': 'Kochi',
    'mysuru': 'Mysuru',
    'mysore': 'Mysuru',
    'vijayawada': 'Vijayawada',
    'tirupati': 'Tirupati',
    'coimbatore': 'Coimbatore',
    'pune': 'Pune',
  };

  static AiChatMessage processQuery(String rawQuery) {
    final q = rawQuery.trim();
    final lower = q.toLowerCase();
    final now = DateTime.now();

    // 1. Safety / Emergency
    if (RegExp(r'\b(unsafe|danger|harass|emergency|sos|scared|help me)\b', caseSensitive: false).hasMatch(lower)) {
      return AiChatMessage(
        sender: 'ai',
        text: 'If you are in danger, please call 112 immediately. During an active journey, hold the SOS button for 3 seconds to alert your emergency contacts and the Abra safety desk.',
        timestamp: now,
        isDanger: true,
        cards: const [
          AiCardData(
            title: 'Police Helpline 112',
            subtitle: 'Immediate national emergency response',
            action: AiAction(label: 'Call 112', actionType: 'call', payload: '112'),
          ),
          AiCardData(
            title: 'Women Helpline 181',
            subtitle: 'Dedicated 24/7 women safety desk',
            action: AiAction(label: 'Call 181', actionType: 'call', payload: '181'),
          ),
        ],
        chips: const ['Where is my bus?', 'Show offers'],
      );
    }

    // 2. Refund Status
    if (RegExp(r'\b(refund|money back|utr)\b', caseSensitive: false).hasMatch(lower)) {
      return AiChatMessage(
        sender: 'ai',
        text: 'Your refund of ₹1,850 for booking ABRK2941A has been credited to your account. Bank UTR: UTR92847192.',
        timestamp: now,
        cards: const [
          AiCardData(
            title: 'Refund for Seats 2A, 2B',
            subtitle: '₹1,850 • Status: Completed',
            badge: 'REFUNDED',
            action: AiAction(label: 'View details', actionType: 'refund', payload: 'RF-4001'),
          ),
        ],
        chips: ['What is the cancellation policy?', 'Where is my bus?'],
      );
    }

    // 3. Cancellation Policy / Cancel Booking
    if (RegExp(r'\bcancel\b', caseSensitive: false).hasMatch(lower)) {
      if (lower.contains('policy')) {
        return AiChatMessage(
          sender: 'ai',
          text: 'Abra Cancellation Policy:\n• > 48h before departure: 100% refund\n• 24 to 48h: 75% refund\n• 12 to 24h: 50% refund\n• 4 to 12h: 25% refund\n• Under 4h: No refund\nOperator cancellations receive 100% refund.',
          timestamp: now,
          chips: ['Cancel my booking', 'Where is my bus?'],
        );
      }
      return AiChatMessage(
        sender: 'ai',
        text: 'You have 1 upcoming booking: Bengaluru to Hyderabad on 20 Oct 2026. Cancelling now yields an 85% refund (₹1,530 back to your UPI).',
        timestamp: now,
        cards: const [
          AiCardData(
            title: 'Bengaluru to Hyderabad',
            subtitle: 'Kaveri Express • Seats 4A, 4B • PNR: ABRM7412B',
            badge: 'UPCOMING',
            action: AiAction(label: 'Cancel booking', actionType: 'cancel', payload: 'BK-7001'),
          ),
        ],
        chips: ['Keep my booking', 'What is the cancellation policy?'],
      );
    }

    // 4. Where is my bus / Live Tracking
    if (RegExp(r'\b(where.*bus|track|live location|delay)\b', caseSensitive: false).hasMatch(lower)) {
      return AiChatMessage(
        sender: 'ai',
        text: 'Your bus TS09 UB 4521 (Kaveri Express) is currently moving at 62 km/h on NH44, 45% of the journey completed. Arriving at Kurnool in ~35 minutes.',
        timestamp: now,
        cards: const [
          AiCardData(
            title: 'Kaveri Express (TS09 UB 4521)',
            subtitle: 'Driver: Ramesh K • On Time • Last ping 1 min ago',
            badge: 'LIVE',
            action: AiAction(label: 'Open live tracking', actionType: 'track', payload: 'BK-7001'),
          ),
        ],
        chips: ['What is my boarding point?', 'I feel unsafe'],
      );
    }

    // 5. Boarding Point
    if (RegExp(r'\b(boarding|pick ?up|where to board)\b', caseSensitive: false).hasMatch(lower)) {
      return AiChatMessage(
        sender: 'ai',
        text: 'Your boarding point is Madiwala Flyover Pickup, Bengaluru at 21:00 on 20 Oct 2026. Landmark: Opposite Petrol Bunk. Please report 15 minutes early by 20:45.',
        timestamp: now,
        cards: const [
          AiCardData(
            title: 'Madiwala Flyover Pickup',
            subtitle: 'Opposite Shell Petrol Bunk, Main Road',
            action: AiAction(label: 'Open in Google Maps', actionType: 'map', payload: 'Madiwala Bengaluru'),
          ),
        ],
        chips: ['Where is my bus?', 'Show ticket QR'],
      );
    }

    // 6. Offers & Discounts
    if (RegExp(r'\b(offer|coupon|discount|promo|cashback)\b', caseSensitive: false).hasMatch(lower)) {
      return AiChatMessage(
        sender: 'ai',
        text: 'Here are the top active discount codes you can apply during review:',
        timestamp: now,
        cards: const [
          AiCardData(
            title: 'ABRA100',
            subtitle: '₹100 off your first booking (Min ₹300)',
            badge: 'NEW USER',
            action: AiAction(label: 'Copy ABRA100', actionType: 'copy', payload: 'ABRA100'),
          ),
          AiCardData(
            title: 'WEEKEND15',
            subtitle: '15% off up to ₹250 on weekend departures',
            badge: 'WEEKENDS',
            action: AiAction(label: 'Copy WEEKEND15', actionType: 'copy', payload: 'WEEKEND15'),
          ),
          AiCardData(
            title: 'UPIFEST',
            subtitle: '₹75 instant cashback when paying with UPI',
            badge: 'UPI',
            action: AiAction(label: 'Copy UPIFEST', actionType: 'copy', payload: 'UPIFEST'),
          ),
        ],
        chips: ['Bengaluru to Hyderabad tomorrow AC sleeper', 'Refund status'],
      );
    }

    // 7. Bus Search by Natural Language
    String? fromCity;
    String? toCity;

    cityAliases.forEach((alias, canonical) {
      if (lower.contains(alias)) {
        if (fromCity == null) {
          fromCity = canonical;
        } else if (toCity == null && canonical != fromCity) {
          toCity = canonical;
        }
      }
    });

    if (fromCity != null || RegExp(r'\b(bus|seat|ticket|travel)\b', caseSensitive: false).hasMatch(lower)) {
      final origin = fromCity ?? 'Bengaluru';
      final dest = toCity ?? 'Hyderabad';

      return AiChatMessage(
        sender: 'ai',
        text: 'I found 3 buses running from $origin to $dest tomorrow. Lowest fare first:',
        timestamp: now,
        cards: const [
          AiCardData(
            title: 'Kaveri Express (AC Sleeper 2+1)',
            subtitle: '21:00 → 06:30 (9h 30m) • ★ 4.7 • 12 seats left',
            price: '₹1,250',
            action: AiAction(label: 'Choose seats', actionType: 'route', payload: 'TRP-3001'),
          ),
          AiCardData(
            title: 'Deccan Voyager (Volvo Multi-Axle AC)',
            subtitle: '22:15 → 07:15 (9h 00m) • ★ 4.8 • 6 seats left',
            price: '₹1,450',
            action: AiAction(label: 'Choose seats', actionType: 'route', payload: 'TRP-3002'),
          ),
          AiCardData(
            title: 'Godavari Lines (AC Seater)',
            subtitle: '20:30 → 06:00 (9h 30m) • ★ 4.5 • 20 seats left',
            price: '₹850',
            action: AiAction(label: 'Choose seats', actionType: 'route', payload: 'TRP-3003'),
          ),
        ],
        chips: ['Apply the best coupon', 'What is the cancellation policy?'],
      );
    }

    // Default Greeting / Help
    return AiChatMessage(
      sender: 'ai',
      text: 'Hello! I am your Abra AI travel assistant. Ask me to find buses, check live bus tracking, verify your boarding point, check refunds, or show active discount offers.',
      timestamp: now,
      chips: const [
        'Bengaluru to Hyderabad tomorrow night AC sleeper under 1500',
        'Where is my bus?',
        'What is my boarding point?',
        'Refund status',
        'Show offers',
        'Cancel my booking',
        'I feel unsafe',
      ],
    );
  }
}
