# Исправление падения тестового мода

Свежий RPT: C:/Users/Admin/AppData/Local/Arma 3/Arma3_x64_2026-10-14_01-10-38.rpt

Подтверждено: падение при чтении NeroAirDefense/config.cpp, до запуска сценария. Ошибка: CfgAmmo.M_Titan_AA_static: Member already defined. Генератор повторял объявления базовых классов для обычного и сетевого боеприпасов. Аналогичная ошибка устранена в объявлениях магазинов и оружия. Введена строгая проверка повторных объявлений до упаковки; прежний упрощённый парсер перезаписывал одинаковые ключи и скрывал дефект.

Исправленный пакет: C:\Users\Admin\Desktop\ИИ\NeroAI_Warlords_DualLLM\dist\air-defense-candidates\@NeroAI_AirDefense_866ad802bec2\addons\NeroAirDefense.pbo

Установлен в прежнюю папку мода: H:/SteamLibrary/steamapps/common/Arma 3/@NeroAI_Operations_Test_20261014/addons/NeroAirDefense.pbo

SHA256: 102D11094AC86C36C7E6675042D131A9F17AAC0D9F1B4D1A86331C2F86E7263B

Старый PBO сохранён в backups/editor-crash-20261014. Основная миссия, моды Workshop, настройки лаунчера, сервер и прогресс не менялись. Новое прохождение загрузки в Arma ещё не подтверждено. Для следующей проверки включить тот же тестовый мод, старые отдельные Strategic/AirDefense не включать.
