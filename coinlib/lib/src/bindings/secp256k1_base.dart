import 'dart:typed_data';
import 'heap_array_base.dart';

class Secp256k1Exception implements Exception {
  final String what;
  Secp256k1Exception(this.what);
  @override
  String toString() => what;
}

class SigWithRecId {
  final Uint8List signature;
  final int recid;
  SigWithRecId(this.signature, this.recid);
}

abstract class Secp256k1Base<
  CtxPtr, HeapArrayPtr, PubKeyPtr, SizeTPtr, SignaturePtr,
  RecoverableSignaturePtr, IntPtr, NullPtr
> {

  static const contextNone = 1;
  static const compressedFlags = 258;
  static const uncompressedFlags = 2;
  static const privkeySize = 32;
  static const hashSize = 32;
  static const entropySize = 32;
  static const pubkeySize = 64;
  static const compressedPubkeySize = 33;
  static const uncompressedPubkeySize = 65;
  static const sigSize = 64;
  static const derSigSize = 72;
  static const recSigSize = 65;

  // Functions
  late int Function(CtxPtr, HeapArrayPtr) extEcSeckeyVerify;
  late int Function(CtxPtr, PubKeyPtr, HeapArrayPtr) extEcPubkeyCreate;
  late int Function(
    CtxPtr, HeapArrayPtr, SizeTPtr, PubKeyPtr, int,
  ) extEcPubkeySerialize;
  late int Function(CtxPtr, PubKeyPtr, HeapArrayPtr, int) extEcPubkeyParse;
  late int Function(
    CtxPtr, HeapArrayPtr, SignaturePtr,
  ) extEcdsaSignatureSerializeCompact;
  late int Function(
    CtxPtr, SignaturePtr, HeapArrayPtr,
  ) extEcdsaSignatureParseCompact;
  late int Function(
    CtxPtr, SignaturePtr, SignaturePtr,
  ) extEcdsaSignatureNormalize;
  late int Function(
    CtxPtr, HeapArrayPtr, SizeTPtr, SignaturePtr,
  ) extEcdsaSignatureSerializeDer;
  late int Function(
    CtxPtr, SignaturePtr, HeapArrayPtr, int,
  ) extEcdsaSignatureParseDer;
  late int Function(
    CtxPtr, SignaturePtr, HeapArrayPtr, HeapArrayPtr, NullPtr, NullPtr,
  ) extEcdsaSign;
  late int Function(
    CtxPtr, SignaturePtr, HeapArrayPtr, PubKeyPtr,
  ) extEcdsaVerify;
  late int Function(
    CtxPtr, HeapArrayPtr, IntPtr, RecoverableSignaturePtr,
  ) extEcdsaRecoverableSignatureSerializeCompact;
  late int Function(
    CtxPtr, RecoverableSignaturePtr, HeapArrayPtr, int,
  ) extEcdsaRecoverableSignatureParseCompact;
  late int Function(
    CtxPtr, RecoverableSignaturePtr, HeapArrayPtr, HeapArrayPtr, NullPtr,
    NullPtr,
  ) extEcdsaSignRecoverable;
  late int Function(
    CtxPtr, PubKeyPtr, RecoverableSignaturePtr, HeapArrayPtr,
  ) extEcdsaRecover;
  late int Function(CtxPtr, HeapArrayPtr, HeapArrayPtr) extEcSeckeyTweakAdd;
  late int Function(CtxPtr, HeapArrayPtr, HeapArrayPtr) extEcSeckeyTweakMul;
  late int Function(CtxPtr, PubKeyPtr, HeapArrayPtr) extEcPubkeyTweakAdd;
  late int Function(CtxPtr, PubKeyPtr, HeapArrayPtr) extEcPubkeyTweakMul;
  late int Function(CtxPtr, HeapArrayPtr) extEcPrivkeyNegate;

  // Heap arrays
  late HeapArrayBase privKeyArray;
  late HeapArrayBase scalarArray;
  late HeapArrayBase serializedPubKeyArray;
  late HeapArrayBase hashArray;
  late HeapArrayBase entropyArray;
  late HeapArrayBase serializedSigArray;
  late HeapArrayBase derSigArray;

  // Other pointers
  late CtxPtr ctxPtr;
  late PubKeyPtr pubKeyPtr;
  late SizeTPtr sizeTPtr;
  late SignaturePtr sigPtr;
  late RecoverableSignaturePtr recSigPtr;
  late IntPtr recIdPtr;
  late NullPtr nullPtr;

  Uint8List _serializePubKeyFromPtr(bool compressed) {

    sizeT = compressed
      ? Secp256k1Base.compressedPubkeySize
      : Secp256k1Base.uncompressedPubkeySize;

    final flags = compressed
      ? Secp256k1Base.compressedFlags
      : Secp256k1Base.uncompressedFlags;

    extEcPubkeySerialize(
      ctxPtr, serializedPubKeyArray.ptr, sizeTPtr, pubKeyPtr, flags,
    );

    // Return copy of public key
    return serializedPubKeyArray.list.sublist(0, sizeT);

  }

  Uint8List _serializeSignatureFromPtr() {
    extEcdsaSignatureSerializeCompact(ctxPtr, serializedSigArray.ptr, sigPtr);
    return serializedSigArray.list.sublist(0);
  }

  void _parsePubkeyIntoPtr(Uint8List pubKey) {
    serializedPubKeyArray.load(pubKey);
    if (
      extEcPubkeyParse(
        ctxPtr, pubKeyPtr, serializedPubKeyArray.ptr, pubKey.length,
      ) != 1
    ) {
      throw Secp256k1Exception("Invalid public key");
    }
  }

  void _parseSignatureIntoPtr(Uint8List signature) {
    serializedSigArray.load(signature);
    if (
      extEcdsaSignatureParseCompact(
        ctxPtr, sigPtr, serializedSigArray.ptr,
      ) != 1
    ) {
      throw Secp256k1Exception("Invalid compact signature");
    }
  }

  void _parseRecoverableSignatureIntoPtr(Uint8List signature, int recid) {
    serializedSigArray.load(signature);
    if (
      extEcdsaRecoverableSignatureParseCompact(
        ctxPtr, recSigPtr, serializedSigArray.ptr, recid,
      ) != 1
    ) {
      throw Secp256k1Exception("Invalid compact recoverable signature");
    }
  }

  bool _noRaiseAfterRequireLoad(void Function() fn) {
    _requireLoad();
    try {
      fn();
    } on Secp256k1Exception {
      return false;
    }
    return true;
  }

  // This may be overriden by the subclass to load the library asynchronously
  Future<void> internalLoad() async {}

  bool _loaded = false;
  _requireLoad() {
    if (!_loaded) throw Secp256k1Exception("load() not called");
  }

  /// Asynchronously load the library. `await` must be used to ensure the
  /// library is loaded. Must be called before other methods are available.
  Future<void> load() async {
    if (_loaded) return;
    await internalLoad();
    _loaded = true;
  }

  /// Returns true if a 32-byte [privKey] is valid.
  bool privKeyVerify(Uint8List privKey) {
    _requireLoad();
    privKeyArray.load(privKey);
    return extEcSeckeyVerify(ctxPtr, privKeyArray.ptr) == 1;
  }

  /// Returns true if a compressed or uncompressed public key is valid.
  bool pubKeyVerify(Uint8List pubKey)
    => _noRaiseAfterRequireLoad(() => _parsePubkeyIntoPtr(pubKey));

  /// Returns true if the compact [signature] can be parsed with valid R and S
  /// values
  bool ecdsaCompactSignatureVerify(Uint8List signature)
    => _noRaiseAfterRequireLoad(() => _parseSignatureIntoPtr(signature));

  /// Returns true if the compact recoverable signature can be parsed given the
  /// [signature] and [recid]
  bool ecdsaCompactRecoverableSignatureVerify(Uint8List signature, int recid)
    => _noRaiseAfterRequireLoad(
      () => _parseRecoverableSignatureIntoPtr(signature, recid),
    );

  /// Converts a 32-byte [privKey] into a either a 33-byte compressed or a
  /// 65-byte uncompressed public key.
  Uint8List privToPubKey(Uint8List privKey, bool compressed) {
    _requireLoad();

    privKeyArray.load(privKey);

    // Derive public key from private key
    if (extEcPubkeyCreate(ctxPtr, pubKeyPtr, privKeyArray.ptr) != 1) {
      throw Secp256k1Exception("Cannot compute public key from private key");
    }

    return _serializePubKeyFromPtr(compressed);

  }

  /// Takes a [signature] and returns an equally valid signature that has a low
  /// s-value.
  Uint8List ecdsaSignatureNormalize(Uint8List signature) {
    _requireLoad();
    _parseSignatureIntoPtr(signature);
    extEcdsaSignatureNormalize(ctxPtr, sigPtr, sigPtr);
    return _serializeSignatureFromPtr();
  }

  /// Takes a compact [signature] and returns a DER encoded signature
  Uint8List ecdsaSignatureToDer(Uint8List signature) {
    _requireLoad();

    _parseSignatureIntoPtr(signature);
    sizeT = derSigArray.list.length;

    // Should always have space
    extEcdsaSignatureSerializeDer(ctxPtr, derSigArray.ptr, sizeTPtr, sigPtr);

    return derSigArray.list.sublist(0, sizeT);

  }

  /// Takes a BIP66 DER ([der]) representation of a signature and returns the
  /// compact representation
  Uint8List ecdsaSignatureFromDer(Uint8List der) {
    _requireLoad();

    derSigArray.load(der);

    if (
      extEcdsaSignatureParseDer(
        ctxPtr, sigPtr, derSigArray.ptr, der.length,
      ) != 1
    ) {
      throw Secp256k1Exception("Invalid DER signature");
    }

    return _serializeSignatureFromPtr();

  }

  /// Constructs a signature in the compact format using a 32-byte message
  /// [hash] and 32-byte [privKey] scalar. The signature contains a 32-byte
  /// big-endian R value followed by a 32-byte big-endian low-S value.
  /// Signatures are deterministic according to RFC6979. Additional entropy may
  /// be added as 32 bytes with [extraEntropy].
  Uint8List ecdsaSign(
    Uint8List hash, Uint8List privKey, [Uint8List? extraEntropy,]
  ) {
    _requireLoad();

    privKeyArray.load(privKey);
    hashArray.load(hash);
    if (extraEntropy != null) entropyArray.load(extraEntropy);

    // Sign
    if (
      extEcdsaSign(
        ctxPtr, sigPtr, hashArray.ptr, privKeyArray.ptr,
        // Passing null will give secp256k1_nonce_function_rfc6979. If secp256k1
        // changes this default function in the future,
        // secp256k1_nonce_function_rfc6979 should be used directly.
        // Using null as it doesn't require passing an additional constant from
        // the web and io implementations.
        nullPtr,
        extraEntropy == null ? nullPtr : entropyArray.ptr,
      ) != 1
    ) {
      throw Secp256k1Exception("Cannot sign message with private key");
    }

    return _serializeSignatureFromPtr();

  }

  /// Verifys a compact [signature] against a 32-byte [hash] for a [pubKey] that
  /// is either compressed or uncompressed in size
  bool ecdsaVerify(Uint8List signature, Uint8List hash, Uint8List pubKey) {
    _requireLoad();

    _parseSignatureIntoPtr(signature);
    _parsePubkeyIntoPtr(pubKey);
    hashArray.load(hash);

    return extEcdsaVerify(ctxPtr, sigPtr, hashArray.ptr, pubKeyPtr) == 1;

  }

  SigWithRecId ecdsaSignRecoverable(Uint8List hash, Uint8List privKey) {
    _requireLoad();

    privKeyArray.load(privKey);
    hashArray.load(hash);

    if (
      extEcdsaSignRecoverable(
        ctxPtr, recSigPtr, hashArray.ptr, privKeyArray.ptr, nullPtr, nullPtr,
      ) != 1
    ) {
      throw Secp256k1Exception("Cannot sign message with private key");
    }

    extEcdsaRecoverableSignatureSerializeCompact(
      ctxPtr, serializedSigArray.ptr, recIdPtr, recSigPtr,
    );
    return SigWithRecId(serializedSigArray.list.sublist(0), internalRecId);

  }

  /// Takes a compact recoverable [signature] with [recid] and message [hash]
  /// and recovers the associated public key. If [compressed] is true, the
  /// public key will be compressed or else it shall be uncompressed. Will
  /// return null if no public key can be extracted.
  Uint8List? ecdaSignatureRecoverPubKey(
    Uint8List signature, int recid, Uint8List hash, bool compressed,
  ) {
    _requireLoad();

    _parseRecoverableSignatureIntoPtr(signature, recid);
    hashArray.load(hash);

    if (extEcdsaRecover(ctxPtr, pubKeyPtr, recSigPtr, hashArray.ptr) != 1) {
      return null;
    }

    return _serializePubKeyFromPtr(compressed);

  }

  /// Tweaks a private key ([privKey]) by a [scalar]. Returns null if a tweaked
  /// private key could not be created.
  Uint8List? privKeyTweakAdd(Uint8List privKey, Uint8List scalar) {
    _requireLoad();

    privKeyArray.load(privKey);
    scalarArray.load(scalar);

    if (extEcSeckeyTweakAdd(ctxPtr, privKeyArray.ptr, scalarArray.ptr) != 1) {
      return null;
    }

    // Return copy of private key or contents are subject to change
    return Uint8List.fromList(privKeyArray.list);

  }

  Uint8List? privKeyTweakMul(Uint8List privKey, Uint8List scalar) {
    _requireLoad();

    privKeyArray.load(privKey);
    scalarArray.load(scalar);

    if (extEcSeckeyTweakMul(ctxPtr, privKeyArray.ptr, scalarArray.ptr) != 1) {
      return null;
    }

    // Return copy of private key or contents are subject to change
    return Uint8List.fromList(privKeyArray.list);
  }

  Uint8List? privKeyNegate(Uint8List privKey) {
    _requireLoad();

    privKeyArray.load(privKey);

    if (extEcPrivkeyNegate(ctxPtr, privKeyArray.ptr) != 1) {
      return null;
    }

    // Return copy of private key or contents are subject to change
    return Uint8List.fromList(privKeyArray.list);
  }

  /// Tweaks a public key ([pubKey]) by adding the generator point multiplied by
  /// the givern [scalar]. The resulting public key corresponds to the
  /// private key tweaked by the same scalar. Returns null if a public key could
  /// not be created. Will return a compressed public key if [compressed] is
  /// true regardless of the size of the passed [pubKey].
  Uint8List? pubKeyTweakAdd(Uint8List pubKey, Uint8List scalar, bool compressed) {
    _requireLoad();

    _parsePubkeyIntoPtr(pubKey);
    scalarArray.load(scalar);

    if (extEcPubkeyTweakAdd(ctxPtr, pubKeyPtr, scalarArray.ptr) != 1) {
      return null;
    }

    return _serializePubKeyFromPtr(compressed);

  }

  Uint8List? pubKeyTweakMul(Uint8List pubKey, Uint8List scalar, bool compressed) {
    _requireLoad();

    _parsePubkeyIntoPtr(pubKey);
    scalarArray.load(scalar);

    if (extEcPubkeyTweakMul(ctxPtr, pubKeyPtr, scalarArray.ptr) != 1) {
      return null;
    }

    return _serializePubKeyFromPtr(compressed);

  }

  /// Specialised sub-classes should override to set the value behind the
  /// sizeTPtr
  set sizeT(int size);

  /// Specialised sub-classes should override to obtain the value behind the
  /// sizeTPtr
  int get sizeT;

  /// Specialised sub-classes should override to obtain the value behind the
  /// recIdPtr
  int get internalRecId;

}
