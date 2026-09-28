import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Contract R7: every request says who is calling. Adds the app's caller
/// headers and a fresh `x-request-id` to each request, so a single tap can be
/// traced through Supabase, One Local's server and their logs.
class CallerClient extends http.BaseClient {
  CallerClient(this._headers, [http.Client? inner])
    : _inner = inner ?? http.Client();

  final Map<String, String> Function() _headers;
  final http.Client _inner;
  static const _uuid = Uuid();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers());
    request.headers['x-request-id'] = _uuid.v4();
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
