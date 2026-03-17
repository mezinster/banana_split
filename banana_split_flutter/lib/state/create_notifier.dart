import 'package:flutter/foundation.dart';
import 'package:banana_split_flutter/crypto/crypto.dart';
import 'package:banana_split_flutter/crypto/passphrase.dart';

class CreateNotifier extends ChangeNotifier {
  final PassphraseGenerator _passphraseGenerator;

  String _title = '';
  String _secret = '';
  int _totalShards = 5;
  int _requiredShards = 3;
  String _passphrase = '';
  List<String> _generatedShards = [];
  bool _isGenerating = false;
  bool _showResults = false;
  String? _error;
  bool _useManualPassphrase = false;

  CreateNotifier(this._passphraseGenerator) {
    _passphrase = _passphraseGenerator.generate(6);
  }

  String get title => _title;
  String get secret => _secret;
  int get totalShards => _totalShards;
  int get requiredShards => _requiredShards;
  String get passphrase => _passphrase;
  List<String> get generatedShards => List.unmodifiable(_generatedShards);
  bool get isGenerating => _isGenerating;
  bool get showResults => _showResults;
  String? get error => _error;
  bool get useManualPassphrase => _useManualPassphrase;

  bool get secretTooLong => _secret.length > 1024;

  bool get canGenerate {
    final passphraseOk = !_useManualPassphrase || _passphrase.length >= 8;
    return _title.isNotEmpty &&
        _secret.isNotEmpty &&
        !secretTooLong &&
        _totalShards >= 3 &&
        _totalShards <= 255 &&
        _requiredShards >= 2 &&
        _requiredShards <= _totalShards &&
        _passphrase.isNotEmpty &&
        passphraseOk;
  }

  void updateTitle(String value) {
    _title = value;
    notifyListeners();
  }

  void updateSecret(String value) {
    _secret = value;
    notifyListeners();
  }

  void updateTotalShards(int value) {
    _totalShards = value.clamp(3, 255);
    // Keep requiredShards within valid range
    _requiredShards = _requiredShards.clamp(2, _totalShards);
    notifyListeners();
  }

  void updateRequiredShards(int value) {
    _requiredShards = value.clamp(2, _totalShards);
    notifyListeners();
  }

  void updatePassphrase(String value) {
    _passphrase = value;
    notifyListeners();
  }

  void toggleManualPassphrase() {
    _useManualPassphrase = !_useManualPassphrase;
    if (!_useManualPassphrase) {
      _passphrase = _passphraseGenerator.generate(6);
    }
    notifyListeners();
  }

  void regeneratePassphrase() {
    _passphrase = _passphraseGenerator.generate(6);
    notifyListeners();
  }

  Future<void> generate() async {
    if (!canGenerate) return;

    _isGenerating = true;
    _error = null;
    notifyListeners();

    try {
      _generatedShards = await BananaCrypto.share(
        data: _secret,
        title: _title,
        passphrase: _passphrase,
        totalShards: _totalShards,
        requiredShards: requiredShards,
      );
      _showResults = true;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void backToEdit() {
    _showResults = false;
    _error = null;
    notifyListeners();
  }

  void reset() {
    _title = '';
    _secret = '';
    _totalShards = 5;
    _requiredShards = 3;
    _passphrase = _passphraseGenerator.generate(6);
    _generatedShards = [];
    _isGenerating = false;
    _showResults = false;
    _error = null;
    _useManualPassphrase = false;
    notifyListeners();
  }
}
