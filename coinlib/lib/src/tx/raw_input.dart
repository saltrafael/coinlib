import 'dart:typed_data';
import 'package:coinlib/src/common/checks.dart';
import 'package:coinlib/src/common/serial.dart';
import 'package:coinlib/src/tx/input_signature.dart';
import 'input.dart';
import 'outpoint.dart';

/// A transaction input without any associated witness data that acts as the
/// base for all other inputs as all inputs include a outpoint, script and
/// sequence number.
class RawInput extends Input {

  @override
  final OutPoint prevOut;
  @override
  final Uint8List scriptSig;
  @override
  final int sequence;

  RawInput({
    required this.prevOut,
    required this.scriptSig,
    this.sequence = Input.sequenceFinal,
  }) {
    checkUint32(sequence, "this.sequence");
  }

  RawInput.fromReader(BytesReader reader)
    : prevOut = OutPoint.fromReader(reader),
    scriptSig = reader.readVarSlice(),
    sequence = reader.readUInt32();

  @override
  void write(Writer writer) {
    prevOut.write(writer);
    writer.writeVarSlice(scriptSig);
    writer.writeUInt32(sequence);
  }

  /// Always true as a simple [RawInput] is assumed to be fully signed as there
  /// is no way to determine if it is or not.
  @override
  bool get complete => true;

  @override
  Input filterSignatures(bool Function(InputSignature insig) predicate) => this;

}
