from flask import Flask, render_template, request, jsonify

app = Flask(__name__)

@app.route('/')
def index():
    """Главная страница с калькулятором"""
    return render_template('index.html')

@app.route('/calculate', methods=['POST'])
def calculate():
    """API для выполнения вычислений"""
    try:
        data = request.get_json()
        
        # Получаем данные из запроса
        num1 = float(data.get('num1', 0))
        num2 = float(data.get('num2', 0))
        operation = data.get('operation', '+')
        
        # Выполняем операцию
        result = 0
        if operation == '+':
            result = num1 + num2
        elif operation == '-':
            result = num1 - num2
        elif operation == '*':
            result = num1 * num2
        elif operation == '/':
            if num2 == 0:
                return jsonify({'error': 'Деление на ноль невозможно'})
            result = num1 / num2
        else:
            return jsonify({'error': 'Неизвестная операция'})
        
        # Возвращаем результат
        return jsonify({'result': result})
        
    except ValueError:
        return jsonify({'error': 'Пожалуйста, введите корректные числа'})
    except Exception as e:
        return jsonify({'error': f'Произошла ошибка: {str(e)}'})

if __name__ == '__main__':
    app.run(debug=True, port=5000)