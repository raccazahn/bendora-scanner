import 'ticket_model.dart';

class EventPackModel {
  final int version;
  final int eventId;
  final String eventName;
  final int? gateId;
  final String? gateName;
  final String publicKey;
  final DateTime generatedAt;
  final List<TicketModel> tickets;

  EventPackModel({
    required this.version,
    required this.eventId,
    required this.eventName,
    this.gateId,
    this.gateName,
    required this.publicKey,
    required this.generatedAt,
    required this.tickets,
  });

  factory EventPackModel.fromMap(Map<String, dynamic> map, List<TicketModel> tickets) {
    return EventPackModel(
      version: map['version'] as int,
      eventId: map['event_id'] as int,
      eventName: map['event_name'] as String,
      gateId: map['gate_id'] as int?,
      gateName: map['gate_name'] as String?,
      publicKey: map['public_key'] as String,
      generatedAt: DateTime.parse(map['generated_at'] as String),
      tickets: tickets,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'event_id': eventId,
      'event_name': eventName,
      'gate_id': gateId,
      'gate_name': gateName,
      'public_key': publicKey,
      'generated_at': generatedAt.toIso8601String(),
    };
  }
}
