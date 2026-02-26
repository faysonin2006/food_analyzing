import 'package:flutter/material.dart';
import 'app_scope.dart';

class Tr {
  static const Map<String, Map<String, String>> _v = {
    'ru': {
      'app_name': 'Food Analyzing',
      'settings': 'Настройки',
      'theme_dark': 'Темная тема',
      'language': 'Язык',
      'lang_ru': 'Русский',
      'lang_en': 'English',
      'save': 'Сохранить',
      'cancel': 'Отмена',
      'edit': 'Редактировать',
      'any': 'Любой',
      'error': 'Ошибка',
      'unknown': 'Неизвестно',
      'loading': 'Загрузка...',
      'permission_denied': 'Доступ запрещен',
      'photo_not_selected': 'Фото не выбрано',
      'target_calories': 'Целевые калории',
      'bmi_label': 'ИМТ',
      'bmi_state_low': 'Низкий',
      'bmi_state_normal': 'Норма',
      'bmi_state_elevated': 'Выше нормы',
      'bmi_state_high': 'Высокий',

      'tab_profile': 'Профиль',
      'tab_analyze': 'Анализ',
      'tab_recipes': 'Рецепты',
      'tab_liked': 'Избранное',
      'liked_empty_title': 'Пока пусто',
      'liked_empty_subtitle': 'Здесь будут лайкнутые рецепты.',

      'login_title': 'Вход',
      'register_title': 'Регистрация',
      'email': 'Email',
      'password': 'Пароль',
      'role': 'Роль (USER/ADMIN)',
      'sign_in': 'Войти',
      'sign_up': 'Зарегистрироваться',
      'no_account': 'Нет аккаунта? Зарегистрироваться',
      'login_error': 'Ошибка входа! Проверьте данные',
      'register_error': 'Ошибка регистрации',
      'register_success': 'Успешно! Теперь войдите.',

      'home_title': 'Анализатор Еды',
      'logout': 'Выход',
      'profile_no_name': 'Без имени',
      'height': 'Рост',
      'weight': 'Вес',
      'goal': 'Цель',
      'calories': 'Калории',
      'activity': 'Активность',
      'gender': 'Пол',
      'allergies': 'Аллергии',
      'diet': 'Диета',
      'health': 'Здоровье',
      'edit_profile': 'Редактировать профиль',
      'calories_day_goal': 'Цель калорий в день',
      'calculating': 'Рассчитывается…',
      'profile_saved': 'Профиль сохранен!',
      'save_error': 'Ошибка сохранения',

      'gallery': 'Галерея',
      'camera': 'Камера',
      'permissions_needed': 'Разрешения нужны для камеры и галереи!',
      'camera_access_error': 'Нет доступа к камере. Откройте настройки.',
      'open_settings': 'Настройки',

      'start_analysis': 'Начать анализ',
      'analyzing': 'AI анализирует...',
      'analysis_complete': 'Анализ завершен',
      'analysis_in_progress': 'В процессе...',
      'analysis_failed': 'Ошибка AI анализа',
      'analysis_timeout': 'Анализ завершён, но данные не загрузились',
      'analyze_again': 'Анализировать еще',
      'additional_info': 'Дополнительно',
      'unknown_dish': 'Неизвестное блюдо',
      'analysis_questions_title': 'Вопросы к анализу',
      'analysis_questions_subtitle':
          'Выберите до 5 вопросов, чтобы получить персональные подсказки.',
      'analysis_questions_search_hint': 'Поиск вопроса по ключевым словам',
      'analysis_questions_open_search': 'Открыть поиск вопросов',
      'analysis_questions_core_title': 'Основные вопросы',
      'analysis_questions_selected': 'Выбранные вопросы',
      'analysis_questions_selected_empty': 'Вопросы пока не выбраны.',
      'analysis_questions_limit_error': 'Можно выбрать максимум 5 вопросов.',
      'analysis_questions_no_matches': 'По вашему запросу ничего не найдено.',
      'analysis_history_title': 'История анализов',
      'analysis_history_empty': 'История пока пустая.',

      'kcal': 'ккал',
      'grams': 'г',
      'protein': 'Белки',
      'fats': 'Жиры',
      'carbs': 'Углеводы',

      'edit_profile_title': 'Редактировать профиль',
      'name': 'Имя',
      'date_of_birth': 'Дата рождения (ГГГГ-ММ-ДД)',
      'height_cm': 'Рост (см)',
      'weight_kg': 'Вес (кг)',
      'activity_level': 'Уровень активности',
      'goal_type': 'Цель',
      'diet_preferences': 'Диетические предпочтения',
      'health_conditions': 'Состояния здоровья',

      'recipes_search_title': 'Поиск рецептов',
      'ingredient': 'Ингредиент',
      'add': 'Добавить',
      'dish_type': 'Тип',
      'cuisine': 'Кухня',
      'diet_filter': 'Диета',
      'recipe_name': 'Название',
      'recipe_category': 'Категория',
      'find': 'Найти',
      'nothing_found': 'Ничего не найдено',
      'search_error': 'Ошибка поиска рецептов',
      'minutes': 'мин',

      'recipe_card_title': 'Карточка рецепта',
      'category_label': 'Категория',
      'prep': 'Подготовка',
      'cook': 'Готовка',
      'total': 'Всего',
      'ingredients': 'Ингредиенты',
      'steps': 'Шаги',
      'nutrition': 'Питательность',
      'constraints': 'Ограничения',
      'recipe_nutrients_title': 'Нутриенты',
      'recipe_restrictions_title': 'Мои ограничения по рецепту',
      'recipe_restrictions_empty': 'Ограничения не обнаружены.',
      'recipe_load_error': 'Не удалось загрузить рецепт',
    },
    'en': {
      'app_name': 'Food Analyzing',
      'settings': 'Settings',
      'theme_dark': 'Dark theme',
      'language': 'Language',
      'lang_ru': 'Russian',
      'lang_en': 'English',
      'save': 'Save',
      'cancel': 'Cancel',
      'edit': 'Edit',
      'any': 'Any',
      'error': 'Error',
      'unknown': 'Unknown',
      'loading': 'Loading...',
      'permission_denied': 'Permission denied',
      'photo_not_selected': 'No photo selected',
      'target_calories': 'Target calories',
      'bmi_label': 'BMI',
      'bmi_state_low': 'Low',
      'bmi_state_normal': 'Normal',
      'bmi_state_elevated': 'Elevated',
      'bmi_state_high': 'High',

      'tab_profile': 'Profile',
      'tab_analyze': 'Analyze',
      'tab_recipes': 'Recipes',
      'tab_liked': 'Liked',
      'liked_empty_title': 'Nothing here yet',
      'liked_empty_subtitle': 'Liked recipes will appear here.',

      'login_title': 'Login',
      'register_title': 'Register',
      'email': 'Email',
      'password': 'Password',
      'role': 'Role (USER/ADMIN)',
      'sign_in': 'Sign in',
      'sign_up': 'Sign up',
      'no_account': 'No account? Register',
      'login_error': 'Login error! Check credentials',
      'register_error': 'Registration error',
      'register_success': 'Success! Please sign in now.',

      'home_title': 'Food Analyzer',
      'logout': 'Logout',
      'profile_no_name': 'No name',
      'height': 'Height',
      'weight': 'Weight',
      'goal': 'Goal',
      'calories': 'Calories',
      'activity': 'Activity',
      'gender': 'Gender',
      'allergies': 'Allergies',
      'diet': 'Diet',
      'health': 'Health',
      'edit_profile': 'Edit profile',
      'calories_day_goal': 'Daily calorie target',
      'calculating': 'Calculating…',
      'profile_saved': 'Profile saved!',
      'save_error': 'Save error',

      'gallery': 'Gallery',
      'camera': 'Camera',
      'permissions_needed': 'Camera and gallery permissions are required!',
      'camera_access_error': 'No camera access. Open settings.',
      'open_settings': 'Settings',

      'start_analysis': 'Start analysis',
      'analyzing': 'AI is analyzing...',
      'analysis_complete': 'Analysis completed',
      'analysis_in_progress': 'In progress...',
      'analysis_failed': 'AI analysis failed',
      'analysis_timeout': 'Analysis finished, but data was not loaded',
      'analyze_again': 'Analyze again',
      'additional_info': 'Additional info',
      'unknown_dish': 'Unknown dish',
      'analysis_questions_title': 'Analysis questions',
      'analysis_questions_subtitle':
          'Pick up to 5 questions for personalized guidance.',
      'analysis_questions_search_hint': 'Search questions by keywords',
      'analysis_questions_open_search': 'Open question search',
      'analysis_questions_core_title': 'Core questions',
      'analysis_questions_selected': 'Selected questions',
      'analysis_questions_selected_empty': 'No questions selected yet.',
      'analysis_questions_limit_error': 'You can select up to 5 questions.',
      'analysis_questions_no_matches': 'No matching questions found.',
      'analysis_history_title': 'Analysis history',
      'analysis_history_empty': 'No analysis history yet.',

      'kcal': 'kcal',
      'grams': 'g',
      'protein': 'Protein',
      'fats': 'Fats',
      'carbs': 'Carbs',

      'edit_profile_title': 'Edit profile',
      'name': 'Name',
      'date_of_birth': 'Date of birth (YYYY-MM-DD)',
      'height_cm': 'Height (cm)',
      'weight_kg': 'Weight (kg)',
      'activity_level': 'Activity level',
      'goal_type': 'Goal',
      'diet_preferences': 'Diet preferences',
      'health_conditions': 'Health conditions',

      'recipes_search_title': 'Recipe Search',
      'ingredient': 'Ingredient',
      'add': 'Add',
      'dish_type': 'Type',
      'cuisine': 'Cuisine',
      'diet_filter': 'Diet',
      'recipe_name': 'Name',
      'recipe_category': 'Category',
      'find': 'Find',
      'nothing_found': 'Nothing found',
      'search_error': 'Recipe search error',
      'minutes': 'min',

      'recipe_card_title': 'Recipe Card',
      'category_label': 'Category',
      'prep': 'Prep',
      'cook': 'Cook',
      'total': 'Total',
      'ingredients': 'Ingredients',
      'steps': 'Steps',
      'nutrition': 'Nutrition',
      'constraints': 'Constraints',
      'recipe_nutrients_title': 'Nutrients',
      'recipe_restrictions_title': 'My recipe restrictions',
      'recipe_restrictions_empty': 'No restrictions detected.',
      'recipe_load_error': 'Failed to load recipe',
    },
  };

  static const Map<String, Map<String, String>> _valueMap = {
    'ru': {
      'MALE': 'Мужской',
      'FEMALE': 'Женский',
      'SEDENTARY': 'Сидячий',
      'LIGHTLY_ACTIVE': 'Слабая активность',
      'MODERATELY_ACTIVE': 'Умеренная активность',
      'VERY_ACTIVE': 'Высокая активность',
      'EXTRA_ACTIVE': 'Очень высокая активность',
      'LOSE_WEIGHT': 'Похудение',
      'MAINTAIN_WEIGHT': 'Поддержание веса',
      'GAIN_MUSCLE': 'Набор мышц',

      'VEGETARIAN': 'Вегетарианская',
      'VEGAN': 'Веганская',
      'PESCATARIAN': 'Пескетарианская',
      'KETO': 'Кето',
      'KETOGENIC': 'Кето',
      'PALEO': 'Палео',
      'HALAL': 'Халяль',
      'KOSHER': 'Кошерная',
      'GLUTEN_FREE': 'Без глютена',
      'LACTOSE_FREE': 'Без лактозы',
      'OMNIVORE': 'Всеядная',

      'GLUTEN': 'Глютен',
      'LACTOSE': 'Лактоза',
      'TREE_NUTS': 'Орехи',
      'PEANUTS': 'Арахис',
      'EGGS': 'Яйца',
      'SOY': 'Соя',
      'FISH': 'Рыба',
      'SHELLFISH': 'Морепродукты',
      'MUSTARD': 'Горчица',
      'SESAME': 'Кунжут',

      'DIABETES_TYPE_1': 'Диабет 1 типа',
      'DIABETES_TYPE_2': 'Диабет 2 типа',
      'INSULIN_RESISTANCE': 'Инсулинорезистентность',
      'GASTRITIS': 'Гастрит',
      'HYPERTENSION': 'Гипертония',
      'HIGH_CHOLESTEROL': 'Высокий холестерин',
      'PREGNANCY': 'Беременность',
      'GOUT': 'Подагра',
      'KIDNEY_DISEASE': 'Болезни почек',
      'CELIAC_DISEASE': 'Целиакия',

      'AMERICAN': 'Американская',
      'CHINESE': 'Китайская',
      'FRENCH': 'Французская',
      'GREEK': 'Греческая',
      'INDIAN': 'Индийская',
      'ITALIAN': 'Итальянская',
      'JAPANESE': 'Японская',
      'MEXICAN': 'Мексиканская',
      'THAI': 'Тайская',

      'MAIN_COURSE': 'Основное блюдо',
      'BREAKFAST': 'Завтрак',
      'SOUP': 'Суп',
      'SALAD': 'Салат',
      'DESSERT': 'Десерт',
      'SNACK': 'Закуска',
      'APPETIZER': 'Аппетайзер',
      'BEVERAGE': 'Напиток',

      'USER': 'Пользователь',
      'ADMIN': 'Администратор',
      'COMPLETED': 'Завершено',
      'FAILED': 'Ошибка',
      'PENDING': 'В процессе',
      'BLOCK': 'Блок',
      'BLOCKED': 'Заблокировано',
      'CAUTION': 'Осторожно',
      'WARN': 'Предупреждение',
      'WARNING': 'Предупреждение',
      'ALLERGY': 'Аллергия',
      'HEALTH': 'Здоровье',
      'DIET': 'Диета',
      'CONSTRAINT': 'Ограничение',
      'UNKNOWN': 'Неизвестно',
    },
    'en': {
      'MALE': 'Male',
      'FEMALE': 'Female',
      'SEDENTARY': 'Sedentary',
      'LIGHTLY_ACTIVE': 'Lightly active',
      'MODERATELY_ACTIVE': 'Moderately active',
      'VERY_ACTIVE': 'Very active',
      'EXTRA_ACTIVE': 'Extra active',
      'LOSE_WEIGHT': 'Lose weight',
      'MAINTAIN_WEIGHT': 'Maintain weight',
      'GAIN_MUSCLE': 'Gain muscle',

      'VEGETARIAN': 'Vegetarian',
      'VEGAN': 'Vegan',
      'PESCATARIAN': 'Pescatarian',
      'KETO': 'Keto',
      'KETOGENIC': 'Ketogenic',
      'PALEO': 'Paleo',
      'HALAL': 'Halal',
      'KOSHER': 'Kosher',
      'GLUTEN_FREE': 'Gluten free',
      'LACTOSE_FREE': 'Lactose free',
      'OMNIVORE': 'Omnivore',

      'GLUTEN': 'Gluten',
      'LACTOSE': 'Lactose',
      'TREE_NUTS': 'Tree nuts',
      'PEANUTS': 'Peanuts',
      'EGGS': 'Eggs',
      'SOY': 'Soy',
      'FISH': 'Fish',
      'SHELLFISH': 'Shellfish',
      'MUSTARD': 'Mustard',
      'SESAME': 'Sesame',

      'DIABETES_TYPE_1': 'Type 1 diabetes',
      'DIABETES_TYPE_2': 'Type 2 diabetes',
      'INSULIN_RESISTANCE': 'Insulin resistance',
      'GASTRITIS': 'Gastritis',
      'HYPERTENSION': 'Hypertension',
      'HIGH_CHOLESTEROL': 'High cholesterol',
      'PREGNANCY': 'Pregnancy',
      'GOUT': 'Gout',
      'KIDNEY_DISEASE': 'Kidney disease',
      'CELIAC_DISEASE': 'Celiac disease',

      'AMERICAN': 'American',
      'CHINESE': 'Chinese',
      'FRENCH': 'French',
      'GREEK': 'Greek',
      'INDIAN': 'Indian',
      'ITALIAN': 'Italian',
      'JAPANESE': 'Japanese',
      'MEXICAN': 'Mexican',
      'THAI': 'Thai',

      'MAIN_COURSE': 'Main course',
      'BREAKFAST': 'Breakfast',
      'SOUP': 'Soup',
      'SALAD': 'Salad',
      'DESSERT': 'Dessert',
      'SNACK': 'Snack',
      'APPETIZER': 'Appetizer',
      'BEVERAGE': 'Beverage',

      'USER': 'User',
      'ADMIN': 'Admin',
      'COMPLETED': 'Completed',
      'FAILED': 'Failed',
      'PENDING': 'Pending',
      'BLOCK': 'Block',
      'BLOCKED': 'Blocked',
      'CAUTION': 'Caution',
      'WARN': 'Warning',
      'WARNING': 'Warning',
      'ALLERGY': 'Allergy',
      'HEALTH': 'Health',
      'DIET': 'Diet',
      'CONSTRAINT': 'Constraint',
      'UNKNOWN': 'Unknown',
    },
  };

  static String t(BuildContext context, String key) {
    final lang = _lang(context);
    return _v[lang]?[key] ?? _v['en']?[key] ?? key;
  }

  static String valueLabel(BuildContext context, String? raw) {
    if (raw == null || raw.trim().isEmpty) return t(context, 'unknown');
    final lang = _lang(context);
    final token = _normalizeToken(raw);
    return _valueMap[lang]?[token] ??
        _valueMap['en']?[token] ??
        _humanizeToken(token);
  }

  static String enumLabel(BuildContext context, String? raw) {
    return valueLabel(context, raw);
  }

  static String _lang(BuildContext context) {
    final code = AppScope.settingsOf(context).locale.languageCode;
    return code == 'ru' ? 'ru' : 'en';
  }

  static String _normalizeToken(String raw) {
    final base = raw.split('.').last.trim().toUpperCase();
    return base
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static String _humanizeToken(String token) {
    final parts = token
        .toLowerCase()
        .split('_')
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.isEmpty) return token;

    return parts
        .map(
          (p) => p.length == 1
              ? p.toUpperCase()
              : p[0].toUpperCase() + p.substring(1),
        )
        .join(' ');
  }
}

String tr(BuildContext context, String key) => Tr.t(context, key);
String trValue(BuildContext context, String? raw) =>
    Tr.valueLabel(context, raw);
