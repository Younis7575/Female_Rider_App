import '../../../core/network/json.dart';

/// `GET /verification`.
class VerificationState {
  const VerificationState({
    required this.status,
    required this.label,
    this.reason,
    this.documentType,
    this.submittedAt,
    this.reviewedAt,
    this.canSubmit = false,
    this.canAppeal = false,
    this.policyVersion,
    this.acceptedDocuments = const [],
    this.requireSelfie = false,
    this.policySummary = '',
  });

  final String status;
  final String label;
  final String? reason;
  final String? documentType;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final bool canSubmit;
  final bool canAppeal;
  final String? policyVersion;
  final List<String> acceptedDocuments;
  final bool requireSelfie;
  final String policySummary;

  factory VerificationState.fromJson(Json j) {
    final p = asMap(j['policy']);
    return VerificationState(
      status: asString(j['status'], 'draft'),
      label: asString(j['label'], 'Draft'),
      reason: asStringOrNull(j['reason']),
      documentType: asStringOrNull(j['document_type']),
      submittedAt: asDate(j['submitted_at']),
      reviewedAt: asDate(j['reviewed_at']),
      canSubmit: asBool(j['can_submit']),
      canAppeal: asBool(j['can_appeal']),
      policyVersion: asStringOrNull(p['version']),
      acceptedDocuments: asStringList(p['accepted_documents']),
      requireSelfie: asBool(p['require_selfie']),
      policySummary: asString(p['summary']),
    );
  }
}

class SessionInfo {
  const SessionInfo({required this.id, required this.device, this.current = false, this.lastUsedAt, this.createdAt});
  final int id;
  final String device;
  final bool current;
  final DateTime? lastUsedAt;
  final DateTime? createdAt;

  factory SessionInfo.fromJson(Json j) => SessionInfo(
        id: asInt(j['id']),
        device: asString(j['device'], 'Unknown device'),
        current: asBool(j['current']),
        lastUsedAt: asDate(j['last_used_at']),
        createdAt: asDate(j['created_at']),
      );
}

class AppNotification {
  const AppNotification({required this.id, required this.type, required this.title, this.body, this.data = const {}, this.read = false, this.createdAt});
  final int id;
  final String type;
  final String title;
  final String? body;
  final Json data;
  final bool read;
  final DateTime? createdAt;

  AppNotification markRead() => AppNotification(id: id, type: type, title: title, body: body, data: data, read: true, createdAt: createdAt);

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: asInt(j['id']),
        type: asString(j['type']),
        title: asString(j['title']),
        body: asStringOrNull(j['body']),
        data: asMap(j['data']),
        read: asBool(j['read']),
        createdAt: asDate(j['created_at']),
      );
}

class Payment {
  const Payment({required this.id, this.tripId, this.purpose, required this.amount, this.refundedAmount = 0, this.currency = 'PKR', this.method, required this.status, this.paidAt, this.createdAt, this.from, this.to});
  final String id;
  final String? tripId;
  final String? purpose;
  final double amount;
  final double refundedAmount;
  final String currency;
  final String? method;
  final String status;
  final DateTime? paidAt;
  final DateTime? createdAt;
  final String? from;
  final String? to;

  factory Payment.fromJson(Json j) {
    final route = asMap(j['route']);
    return Payment(
      id: asString(j['id']),
      tripId: asStringOrNull(j['trip_id']),
      purpose: asStringOrNull(j['purpose']),
      amount: asDouble(j['amount']),
      refundedAmount: asDouble(j['refunded_amount']),
      currency: asString(j['currency'], 'PKR'),
      method: asStringOrNull(j['method']),
      status: asString(j['status'], 'pending'),
      paidAt: asDate(j['paid_at']),
      createdAt: asDate(j['created_at']),
      from: asStringOrNull(route['from']),
      to: asStringOrNull(route['to']),
    );
  }
}

class Refund {
  const Refund({required this.id, this.tripId, required this.amount, this.reason, required this.status, this.createdAt});
  final String id;
  final String? tripId;
  final double amount;
  final String? reason;
  final String status;
  final DateTime? createdAt;

  factory Refund.fromJson(Json j) => Refund(
        id: asString(j['id']),
        tripId: asStringOrNull(j['trip_id']),
        amount: asDouble(j['amount']),
        reason: asStringOrNull(j['reason']),
        status: asString(j['status'], 'pending'),
        createdAt: asDate(j['created_at']),
      );
}

class TicketMessage {
  const TicketMessage({required this.id, required this.fromSupport, required this.body, this.createdAt, this.hasAttachment = false});
  final int id;
  final bool fromSupport;
  final String body;
  final DateTime? createdAt;
  final bool hasAttachment;

  factory TicketMessage.fromJson(Json j) => TicketMessage(
        id: asInt(j['id']),
        fromSupport: asString(j['from']) == 'support',
        body: asString(j['body']),
        createdAt: asDate(j['created_at']),
        hasAttachment: asBool(j['has_attachment']),
      );
}

class SupportTicket {
  const SupportTicket({required this.id, required this.reference, required this.category, required this.subject, this.priority, required this.status, this.tripId, this.messages = const [], this.createdAt, this.updatedAt});
  final String id;
  final String reference;
  final String category;
  final String subject;
  final String? priority;
  final String status;
  final String? tripId;
  final List<TicketMessage> messages;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SupportTicket.fromJson(Json j) => SupportTicket(
        id: asString(j['id']),
        reference: asString(j['reference'], asString(j['id'])),
        category: asString(j['category'], 'general'),
        subject: asString(j['subject']),
        priority: asStringOrNull(j['priority']),
        status: asString(j['status'], 'open'),
        tripId: asStringOrNull(j['trip_id']),
        messages: asListOf(j['messages'], TicketMessage.fromJson),
        createdAt: asDate(j['created_at']),
        updatedAt: asDate(j['updated_at']),
      );
}

class Faq {
  const Faq({required this.id, required this.category, required this.audience, required this.question, required this.answer});
  final int id;
  final String category;
  final String audience;
  final String question;
  final String answer;

  factory Faq.fromJson(Json j) => Faq(
        id: asInt(j['id']),
        category: asString(j['category'], 'General'),
        audience: asString(j['audience'], 'all'),
        question: asString(j['question']),
        answer: asString(j['answer']),
      );
}

class CmsPage {
  const CmsPage({required this.slug, required this.title, required this.body, this.version, this.updatedAt});
  final String slug;
  final String title;
  final String body;
  final String? version;
  final DateTime? updatedAt;

  factory CmsPage.fromJson(Json j) => CmsPage(
        slug: asString(j['slug']),
        title: asString(j['title']),
        body: asString(j['body']),
        version: asStringOrNull(j['version']),
        updatedAt: asDate(j['updated_at']),
      );
}

class Incident {
  const Incident({required this.id, required this.reference, required this.type, this.severity, required this.status, this.description, this.tripId, this.resolution, this.createdAt});
  final String id;
  final String reference;
  final String type;
  final String? severity;
  final String status;
  final String? description;
  final String? tripId;
  final String? resolution;
  final DateTime? createdAt;

  factory Incident.fromJson(Json j) => Incident(
        id: asString(j['id']),
        reference: asString(j['reference']),
        type: asString(j['type']),
        severity: asStringOrNull(j['severity']),
        status: asString(j['status'], 'open'),
        description: asStringOrNull(j['description']),
        tripId: asStringOrNull(j['trip_id']),
        resolution: asStringOrNull(j['resolution']),
        createdAt: asDate(j['created_at']),
      );
}
