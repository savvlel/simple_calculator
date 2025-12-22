// Основные элементы интерфейса
const num1Input = document.getElementById('num1');
const num2Input = document.getElementById('num2');
const operationButtons = document.querySelectorAll('.operation-btn');
const calculateButton = document.getElementById('calculate-btn');
const resultDisplay = document.getElementById('result-display');
const errorDisplay = document.getElementById('error-message');

// Текущая выбранная операция
let currentOperation = '+';

// Инициализация приложения
function initApp() {
    // Устанавливаем начальную активную операцию
    setActiveOperation(currentOperation);
    
    // Добавляем обработчики событий
    setupEventListeners();
}

// Устанавливает активную операцию
function setActiveOperation(operation) {
    // Убираем активный класс у всех кнопок операций
    operationButtons.forEach(btn => {
        btn.classList.remove('active');
        if (btn.dataset.operation === operation) {
            btn.classList.add('active');
        }
    });
    
    currentOperation = operation;
}

// Настраивает обработчики событий
function setupEventListeners() {
    // Обработчики для кнопок операций
    operationButtons.forEach(button => {
        button.addEventListener('click', () => {
            const operation = button.dataset.operation;
            setActiveOperation(operation);
        });
    });
    
    // Обработчик для кнопки вычисления
    calculateButton.addEventListener('click', performCalculation);
    
    // Обработчик для клавиши Enter
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') {
            performCalculation();
        }
    });
}

// Асинхронная функция для выполнения вычисления
async function performCalculation() {
    // Скрываем предыдущую ошибку
    errorDisplay.textContent = '';
    
    // Получаем значения из полей ввода
    const num1 = parseFloat(num1Input.value);
    const num2 = parseFloat(num2Input.value);
    
    // Проверяем, что введены числа
    if (isNaN(num1) || isNaN(num2)) {
        showError('Пожалуйста, введите оба числа');
        return;
    }
    
    // Проверяем деление на ноль
    if (currentOperation === '/' && num2 === 0) {
        showError('Деление на ноль невозможно');
        return;
    }
    
    try {
        // Выполняем асинхронный запрос к серверу
        const result = await sendCalculationRequest(num1, num2, currentOperation);
        
        // Отображаем результат
        resultDisplay.textContent = result;
        
    } catch (error) {
        // Обрабатываем ошибку
        showError(error.message);
    }
}

// Отправляет запрос на сервер для вычисления
async function sendCalculationRequest(num1, num2, operation) {
    // Создаем тело запроса
    const requestBody = {
        num1: num1,
        num2: num2,
        operation: operation
    };
    
    // Используем async/await для асинхронного запроса
    const response = await fetch('/calculate', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(requestBody)
    });
    
    // Парсим JSON-ответ
    const data = await response.json();
    
    // Проверяем наличие ошибки в ответе
    if (data.error) {
        throw new Error(data.error);
    }
    
    return data.result;
}

// Альтернативная реализация с использованием Promise
function sendCalculationRequestPromise(num1, num2, operation) {
    return new Promise((resolve, reject) => {
        const requestBody = {
            num1: num1,
            num2: num2,
            operation: operation
        };
        
        fetch('/calculate', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(requestBody)
        })
        .then(response => response.json())
        .then(data => {
            if (data.error) {
                reject(new Error(data.error));
            } else {
                resolve(data.result);
            }
        })
        .catch(error => {
            reject(error);
        });
    });
}

// Показывает сообщение об ошибке
function showError(message) {
    errorDisplay.textContent = message;
    resultDisplay.textContent = 'Ошибка';
}

// Инициализируем приложение при загрузке страницы
document.addEventListener('DOMContentLoaded', initApp);