# Sorta AI Frontend

Frontend на Flutter для Sorta AI.

Sorta AI — это AI-first ассистент для очистки и сортировки медиатеки пользователя. Этот репозиторий пока содержит базовый Flutter-каркас для будущего MVP-приложения.

## Текущий Статус

Сейчас реализовано:

- минимальный Flutter-проект;
- точка входа приложения;
- пустой экран;
- базовая Material 3 тема.

Пока не реализовано:

- выбор изображений;
- интеграция с backend;
- отображение похожих групп;
- действия пользователя над файлами.

## Стек

- Flutter
- Dart
- Material 3

## Структура Проекта

```text
lib/
  main.dart                         # Точка входа Flutter-приложения и тема
  sorta_shell.dart                  # Основной shell с нижней навигацией

  pages/
    home_page.dart                  # Главный экран сканирования
    files_page.dart                 # Экран файлов
    smart_clean_page.dart           # Экран Smart Clean

  shared/
    sorta_colors.dart               # Цвета дизайн-системы
    sorta_spacing.dart              # Токены отступов
    sorta_components.dart           # Переиспользуемые UI-компоненты

pubspec.yaml                        # Зависимости и настройки проекта
analysis_options.yaml               # Настройки линтера
README.md
```

## MVP Flow

Будущий минимальный поток приложения:

```text
выбор изображений -> отправка на backend -> получение кластеров -> показ рекомендаций
```

Backend endpoint:

```text
POST /api/v1/media/analyze
```

Frontend должен будет отправлять изображения на backend и показывать результат анализа пользователю.

## Установка

Установить Flutter SDK:

```text
https://docs.flutter.dev/get-started/install
```

Проверить установку:

```bash
flutter --version
flutter doctor
```

Если команда `flutter` не находится, нужно добавить Flutter SDK в `PATH`.

## Подготовка Проекта

Установить зависимости:

```bash
flutter pub get
```

Если платформенные папки еще не созданы:

```bash
flutter create --platforms=android,ios .
```

## Запуск

Посмотреть доступные устройства:

```bash
flutter devices
```

Запустить приложение:

```bash
flutter run
```

Запуск на Android:

```bash
flutter run -d android
```

Запуск на iOS:

```bash
flutter run -d ios
```

## Связь С Backend

Локальный backend:

```text
http://127.0.0.1:8000
```

Для Android emulator:

```text
http://10.0.2.2:8000
```

Для реального телефона в одной Wi-Fi сети нужно использовать IP компьютера:

```text
http://192.168.x.x:8000
```

## Что Делать Дальше

1. Установить Flutter SDK.
2. Выполнить `flutter pub get`.
3. Выполнить `flutter create --platforms=android,ios .`, если нужны платформенные папки.
4. Добавить экран выбора изображений.
5. Подключить backend `/api/v1/media/analyze`.
6. Добавить экран результатов анализа.
