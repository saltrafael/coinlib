import "package:coinlib/coinlib.dart";

void main() async {

  // Always remember to load the library for web use
  await loadCoinlib();

  // Create a HD Key from a seed
  final seed = generateRandomBytes(16);
  final wallet = HDPrivateKey.fromSeed(seed);

  // Derive hardened key at 10'
  final hardened = wallet.deriveHardened(10);

  // Further derive key at 4
  final key1 = hardened.derive(4);

  // Keys can be derived from the path too
  final key2 = wallet.derivePath("m/10'/4");

  // Public keys can be compared
  if (key1.publicKey == key2.publicKey) {
    print("Derived keys match");
  }

  // Generate a P2PKH address with the mainnet prefix
  final address = P2PKHAddress.fromPublicKey(
    key1.publicKey,
    version: NetworkParams.mainnet.p2pkhPrefix,
  );
  print("Address: $address");

  // Sign message with key and verify with address

  final msg = "Hello World!";
  final msgSig = MessageSignature.sign(
    key: key1.privateKey,
    message: msg,
    prefix: NetworkParams.mainnet.messagePrefix,
  );

  if (
    msgSig.verifyAddress(
      address: address,
      message: msg,
      prefix: NetworkParams.mainnet.messagePrefix,
    )
  ) {
    print("Msg signature is valid: $msgSig");
  }

  // Create a transaction that spends a P2PKH input to the address generated
  // earlier. The version is set to 3 by default with a 0 locktime.
  // hexToBytes is a convenience function.

  final prevHash = hexToBytes(
    "32d1f1cf811456c6da4ef9e1cb7f8bb80c4c5e9f2d2c3d743f2b68a9c6857823",
  );

  final tx = LegacyTransaction(
    inputs: [
      P2PKHInput(prevOut: OutPoint(prevHash, 1), publicKey: key1.publicKey),
    ],
    outputs: [
      Output.fromAddress(BigInt.from(2000000), address)
    ],
  );

  if (!tx.complete) {
    print("Unsigned transaction is incomplete");
  }

  // Sign the input with the private key. The signed transaction is returned as
  // a new object as most objects in the library are immutable.
  final signedTx = tx.sign(inputN: 0, key: key1.privateKey);

  if (signedTx.complete) {
    print("Signed transaction is complete");
  }

  print("Txid = ${signedTx.txid}");
  print("Tx hex = ${signedTx.toHex()}");

}