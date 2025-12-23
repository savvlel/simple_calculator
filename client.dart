import 'dart:convert';
import 'dart:io';

/// Простой WebSocket клиент для калькулятора
class CalculatorClient {
  WebSocket? _webSocket;
  bool _isConnected = false;
  String _serverAddress;
  int _serverPort;

  CalculatorClient({required String serverAddress, int serverPort = 8765})
      : _serverAddress = serverAddress,
        _serverPort = serverPort;

  /// Подключение к серверу
  Future<bool> connect() async {
    try {
      print('🔗 Подключение к ws://$_serverAddress:$_serverPort...');
      
      final uri = Uri.parse('ws://$_serverAddress:$_serverPort');
      _webSocket = await WebSocket.connect(uri.toString());
      
      _isConnected = true;
      print('Подключение установлено');

      // Слушаем входящие сообщения
      _webSocket!.listen(
        _handleMessage,
        onDone: () {
          print('Соединение закрыто сервером');
          _isConnected = false;
        },
        onError: (error) {
          print('Ошибка соединения: $error');
          _isConnected = false;
        },
      );

      return true;
    } catch (e) {
      print('Не удалось подключиться: $e');
      _isConnected = false;
      return false;
    }
  }

  /// Обработка входящих сообщений
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message.toString());
      print('Получено от сервера:');
      _printJson(data);
    } catch (e) {
      print('Ошибка разбора сообщения: $e\nСообщение: $message');
    }
  }

  /// Отправка запроса на вычисление
  Future<void> calculate(double num1, double num2, String operation) async {
    if (!_isConnected || _webSocket == null) {
      print('Нет подключения к серверу');
      return;
    }

    final request = {
      'type': 'calculate',
      'num1': num1,
      'num2': num2,
      'operation': operation,
      'request_id': DateTime.now().millisecondsSinceEpoch,
      'timestamp': DateTime.now().toIso8601String(),
    };

    print('🧮 Отправка запроса: $num1 $operation $num2');
    _webSocket!.add(jsonEncode(request));
  }

  /// Отправка ping запроса
  void ping() {
    if (!_isConnected || _webSocket == null) {
      print('Нет подключения к серверу');
      return;
    }

    final request = {
      'type': 'ping',
      'timestamp': DateTime.now().toIso8601String(),
    };

    _webSocket!.add(jsonEncode(request));
    print('📡 Ping отправлен');
  }

  /// Отключение от сервера
  void disconnect() {
    if (_webSocket != null) {
      _webSocket!.close();
      _isConnected = false;
      print('🔌 Отключено от сервера');
    }
  }

  /// Печать JSON в читаемом формате
  void _printJson(Map<String, dynamic> json) {
    if (json['type'] == 'result') {
      print('   Результат: ${json['expression']} = ${json['result']}');
      print('   Время: ${DateTime.parse(json['timestamp']).toLocal()}');
    } else if (json['type'] == 'error') {
      print('   Ошибка: ${json['error']}');
    } else if (json['type'] == 'connected') {
      print('   ${json['message']}');
      print('   ID клиента: ${json['client_id']}');
    } else if (json['type'] == 'pong') {
      print('   Pong получен');
    } else {
      print('   ℹ ${json.toString()}');
    }
    print('');
  }

  /// Геттер состояния подключения
  bool get isConnected => _isConnected;
}

/// Консольный интерфейс клиента
void main() async {
  print('=' * 50);
  print('🧮 WebSocket клиент калькулятора');
  print('=' * 50);

  // Запрос адреса сервера
  stdout.write('Введите IP адрес сервера [localhost]: ');
  var serverAddress = stdin.readLineSync()?.trim();
  if (serverAddress == null || serverAddress.isEmpty) {
    serverAddress = 'localhost';
  }

  stdout.write('Введите порт сервера [8765]: ');
  var portInput = stdin.readLineSync()?.trim();
  final serverPort = int.tryParse(portInput ?? '') ?? 8765;

  // Создание и подключение клиента
  final client = CalculatorClient(
    serverAddress: serverAddress,
    serverPort: serverPort,
  );

  final connected = await client.connect();
  if (!connected) {
    print(' Не удалось подключиться к серверу');
    return;
  }

  // Основной цикл
  bool running = true;
  print('\n' + '=' * 50);
  print('Доступные команды:');
  print('  calc - выполнить вычисление');
  print('  ping - проверить соединение');
  print('  exit - выход из программы');
  print('=' * 50);

  while (running) {
    stdout.write('\n> ');
    final command = stdin.readLineSync()?.trim().toLowerCase();

    switch (command) {
      case 'calc':
        await _handleCalculation(client);
        break;

      case 'ping':
        client.ping();
        break;

      case 'exit':
      case 'quit':
        print(' Выход из программы...');
        client.disconnect();
        running = false;
        break;

      case '':
        break;

      default:
        print(' Неизвестная команда. Используйте: calc, ping, exit');
    }
  }
}

/// Обработка ввода вычисления
Future<void> _handleCalculation(CalculatorClient client) async {
  try {
    stdout.write('Введите первое число: ');
    final num1Input = stdin.readLineSync();
    final num1 = double.tryParse(num1Input ?? '');
    
    if (num1 == null) {
      print(' Некорректное число');
      return;
    }

    stdout.write('Введите операцию (+, -, *, /): ');
    final operation = stdin.readLineSync()?.trim();
    
    if (operation == null || !['+', '-', '*', '/'].contains(operation)) {
      print(' Некорректная операция');
      return;
    }

    stdout.write('Введите второе число: ');
    final num2Input = stdin.readLineSync();
    final num2 = double.tryParse(num2Input ?? '');
    
    if (num2 == null) {
      print(' Некорректное число');
      return;
    }

    // Проверка деления на ноль
    if (operation == '/' && num2 == 0) {
      print(' Деление на ноль невозможно');
      return;
    }

    await client.calculate(num1, num2, operation);
    
  } catch (e) {
    print(' Ошибка ввода: $e');
  }
}