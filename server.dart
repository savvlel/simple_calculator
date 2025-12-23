import 'dart:convert';
import 'dart:io';

/// Простой WebSocket сервер для калькулятора
class CalculatorServer {
  final InternetAddress _host;
  final int _port;
  HttpServer? _server;
  final Map<WebSocket, String> _clients = {};

  CalculatorServer({String host = '0.0.0.0', int port = 8765})
      : _host = InternetAddress(host),
        _port = port;

  /// Запуск сервера
  Future<void> start() async {
    try {
      _server = await HttpServer.bind(_host, _port);
      print('Сервер запущен на ws://${_host.address}:$_port');
      print('Ожидание подключений...\n');

      await for (var request in _server!) {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          handleWebSocket(request);
        } else {
          request.response
            ..statusCode = HttpStatus.badRequest
            ..write('Только WebSocket соединения поддерживаются')
            ..close();
        }
      }
    } catch (e) {
      print('Ошибка запуска сервера: $e');
    }
  }

  /// Обработка WebSocket подключения
  void handleWebSocket(HttpRequest request) async {
    try {
      final webSocket = await WebSocketTransformer.upgrade(request);
      final clientId = 'client_${DateTime.now().millisecondsSinceEpoch}';
      
      _clients[webSocket] = clientId;
      print('📱 Подключился клиент: $clientId');

      // Отправляем приветственное сообщение
      webSocket.add(jsonEncode({
        'type': 'connected',
        'message': 'Подключение к серверу калькулятора установлено',
        'timestamp': DateTime.now().toIso8601String(),
        'client_id': clientId,
      }));

      // Обработка входящих сообщений
      webSocket.listen(
        (message) => handleMessage(webSocket, message),
        onDone: () => disconnectClient(webSocket),
        onError: (error) => disconnectClient(webSocket, error: error.toString()),
      );
    } catch (e) {
      print('Ошибка подключения WebSocket: $e');
    }
  }

  /// Обработка входящих сообщений
  void handleMessage(WebSocket webSocket, dynamic message) {
    try {
      final clientId = _clients[webSocket] ?? 'unknown';
      final data = jsonDecode(message.toString());
      print('Получено от $clientId: $data');

      if (data['type'] == 'calculate') {
        // Выполнение вычисления
        final result = performCalculation(data);
        webSocket.add(jsonEncode(result));
        
        print('Результат для $clientId: ${result['result']}');
      } else if (data['type'] == 'ping') {
        // Ответ на ping
        webSocket.add(jsonEncode({
          'type': 'pong',
          'timestamp': DateTime.now().toIso8601String(),
        }));
      }
    } catch (e) {
      print('Ошибка обработки сообщения: $e');
      webSocket.add(jsonEncode({
        'type': 'error',
        'error': 'Ошибка обработки запроса: $e',
        'timestamp': DateTime.now().toIso8601String(),
      }));
    }
  }

  /// Выполнение математической операции
  Map<String, dynamic> performCalculation(Map<String, dynamic> data) {
    try {
      final num1 = double.parse(data['num1'].toString());
      final num2 = double.parse(data['num2'].toString());
      final operation = data['operation'].toString();

      double result;
      String? error;

      switch (operation) {
        case '+':
          result = num1 + num2;
          break;
        case '-':
          result = num1 - num2;
          break;
        case '*':
          result = num1 * num2;
          break;
        case '/':
          if (num2 == 0) {
            throw Exception('Деление на ноль невозможно');
          }
          result = num1 / num2;
          break;
        default:
          throw Exception('Неизвестная операция: $operation');
      }

      return {
        'type': 'result',
        'result': result,
        'expression': '$num1 $operation $num2',
        'operation': operation,
        'timestamp': DateTime.now().toIso8601String(),
        'success': true,
        'request_id': data['request_id'],
      };
    } catch (e) {
      return {
        'type': 'error',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'success': false,
        'request_id': data['request_id'],
      };
    }
  }

  /// Отключение клиента
  void disconnectClient(WebSocket webSocket, {String? error}) {
    final clientId = _clients.remove(webSocket);
    if (clientId != null) {
      print('📴 Отключился клиент: $clientId ${error != null ? '($error)' : ''}');
    }
    webSocket.close();
  }

  /// Остановка сервера
  Future<void> stop() async {
    print('\n Остановка сервера...');
    
    // Закрываем все соединения
    for (final client in _clients.keys) {
      client.close();
    }
    _clients.clear();
    
    await _server?.close();
    print('Сервер остановлен');
  }
}

/// Точка входа сервера
void main(List<String> arguments) async {
  print('=' * 50);
  print('WebSocket сервер калькулятора');
  print('=' * 50);

  // Получаем IP адрес для отображения
  final networkInterfaces = await NetworkInterface.list();
  final addresses = networkInterfaces
      .expand((interface) => interface.addresses)
      .where((addr) => addr.type == InternetAddressType.IPv4)
      .map((addr) => addr.address)
      .toList();

  print('Доступные IP адреса:');
  for (final addr in addresses) {
    print('   - $addr');
  }
  print('');

  // Запуск сервера
  final server = CalculatorServer(host: '0.0.0.0', port: 8765);
  
  // Обработка Ctrl+C для корректной остановки
  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });

  await server.start();
}