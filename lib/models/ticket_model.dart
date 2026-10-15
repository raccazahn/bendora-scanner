class TicketModel {
  final String publicTicketId;
  final String ticketType;
  final int? gateId;
  final String status;

  TicketModel({
    required this.publicTicketId,
    required this.ticketType,
    this.gateId,
    required this.status,
  });

  factory TicketModel.fromMap(Map<String, dynamic> map) {
    return TicketModel(
      publicTicketId: map['public_ticket_id'] as String,
      ticketType: map['ticket_type'] as String,
      gateId: map['gate_id'] as int?,
      status: map['status'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'public_ticket_id': publicTicketId,
      'ticket_type': ticketType,
      'gate_id': gateId,
      'status': status,
    };
  }
}
