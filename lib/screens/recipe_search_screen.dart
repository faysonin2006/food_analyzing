import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_scope.dart';
import '../core/settings_sheet.dart';
import '../core/tr.dart';
import '../services/api_service.dart';
import 'recipe_detail_screen.dart';
import 'recipe_models.dart';

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key, this.onOpenProfileTap});

  final VoidCallback? onOpenProfileTap;

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  static const int _pageSize = 20;

  final api = ApiService();
  final titleCtrl = TextEditingController();
  final keywordCtrl = TextEditingController();
  final pageCtrl = TextEditingController(text: '1');
  final _scrollController = ScrollController();
  final _resultsTopKey = GlobalKey();
  Map<String, dynamic>? _profile;
  String? _lastLocaleCode;

  String? diet;
  String? selectedKeyword;
  bool loading = false;
  bool searched = false;
  int currentPage = 1;
  bool hasNextPage = false;
  List<RecipeSummary> results = [];
  int _activeSearchRequestId = 0;

  final diets = ['gluten free', 'ketogenic', 'vegetarian', 'vegan', 'paleo'];

  static const List<String> _keywordCatalogEn = [
    'dessert',
    'lunch snacks',
    'one dish meal',
    'vegetable',
    'breakfast',
    'chicken',
    'pork',
    'beverages',
    'breads',
    'quick breads',
    'potato',
    'sauces',
    'meat',
    'chicken breast',
    'cheese',
    'yeast breads',
    'bar cookie',
    'pie',
    'drop cookies',
    'stew',
    'candy',
    'spreads',
    'beans',
    'savory pies',
    'poultry',
    'smoothies',
    'rice',
    'curries',
    'european',
    'fruit',
    'lamb',
    'chowders',
    'crab',
    'yam sweet potato',
    'grains',
    'cauliflower',
    'ham',
    'greens',
    'asian',
    'roast beef',
    'chicken thigh leg',
    'spaghetti',
    'scones',
    'white rice',
    'apple',
    'mexican',
    'gelatin',
    'healthy',
    'long grain rice',
    'peppers',
    'pineapple',
    'black beans',
    'whole chicken',
    'penne',
    'clear soup',
    'tarts',
    'lentil',
    'shakes',
    'high protein',
    'low protein',
    'low cholesterol',
    'very low carbs',
    'corn',
    'tilapia',
    'tuna',
    'onions',
    'strawberry',
    'kid friendly',
    'soy tofu',
    'weeknight',
    'brown rice',
    'canadian',
    'stocks',
    'oranges',
    'lemon',
    'halibut',
    'greek',
    'chinese',
    'brunch',
    'catfish',
    'veal',
    'southwestern',
    'sourdough breads',
    'vegan',
    'cajun',
    'berries',
    'spinach',
    'coconut',
    'lobster',
    'gumbo',
    'melons',
    'thai',
    'savory',
    'summer',
    'spicy',
    'trout',
    'easy',
    'caribbean',
    'deer',
    'mussels',
    'german',
    'mango',
    'citrus',
    'tex mex',
    'mahi mahi',
    'bass',
    'tropical fruits',
    'spanish',
    'kosher',
    'pears',
    'japanese',
    'toddler friendly',
    'creole',
    'african',
    'turkey breasts',
    'manicotti',
    'squid',
    'cherries',
    'moroccan',
    'orange roughy',
    'whitefish',
    'duck',
    'pheasant',
    'chicken livers',
    'wild game',
    'lime',
    'high fiber',
    'vietnamese',
    'winter',
    'collard greens',
    'hungarian',
    'egg free',
    'crawfish',
    'tempeh',
    'no shell fish',
    'swedish',
    'plums',
    'hawaiian',
    'nepalese',
    'meatloaf',
    'medium grain rice',
    'dutch',
    'perch',
    'scandinavian',
    'polish',
    'chard',
    'rabbit',
    'quail',
    'egyptian',
    'elk',
    'portuguese',
    'russian',
    'octopus',
    'peanut butter',
    'szechuan',
    'new zealand',
    'ethiopian',
    'norwegian',
    'danish',
    'goose',
    'ice cream',
    'indonesian',
    'lebanese',
    'chocolate chip cookies',
    'malaysian',
    'roast',
    'native american',
    'brazilian',
    'cuban',
    'czech',
    'turkish',
    'costa rican',
    'polynesian',
    'palestinian',
    'icelandic',
    'mashed potatoes',
    'macaroni and cheese',
    'no cook',
    'nuts',
    'scottish',
    'finnish',
    'belgian',
    'puerto rican',
    'nigerian',
    'kiwifruit',
    'oatmeal',
    'dairy free foods',
    'georgian',
    'summer dip',
    'pressure cooker',
    'meatballs',
    'filipino',
    'iraqi',
    'indian',
    'bear',
    'south american',
    'colombian',
    'korean',
    'pakistani',
    'pot pie',
    '15 minutes',
    '30 minutes',
    '60 minutes',
    '4 hours',
  ];

  static const List<String> _keywordCatalogRu = [
    'десерт',
    'обед закуски',
    'одно блюдо',
    'овощной',
    'завтрак',
    'курица',
    'свинина',
    'напитки',
    'хлеб',
    'быстрый хлеб',
    'картофель',
    'соусы',
    'мясо',
    'куриная грудка',
    'сыр',
    'дрожжевой хлеб',
    'барное печенье',
    'пирог',
    'тушить',
    'конфеты',
    'спреды',
    'бобы',
    'птица',
    'смузи',
    'рис',
    'карри',
    'европейский',
    'фрукты',
    'ягненок овца',
    'чаудеры',
    'краб',
    'ямс сладкий картофель',
    'зерна',
    'цветная капуста',
    'ветчина',
    'зелень',
    'азиатский',
    'ростбиф',
    'куриное бедро и ножка',
    'спагетти',
    'чизкейк',
    'булочки',
    'яблоко',
    'мексиканский',
    'желатин',
    'низкое содержание белка',
    'здоровый',
    'длиннозерный рис',
    'перец',
    'ананас',
    'черная фасоль',
    'целая курица',
    'пенне',
    'стейк',
    'очень низкий уровень углеводов',
    'заправки для салатов',
    'замороженные десерты',
    'прозрачный суп',
    'тарты',
    'пикантные пироги',
    'чечевица',
    'высокое содержание белка',
    'кукуруза',
    'тилапия',
    'лук',
    'тунец',
    'низкий уровень холестерина',
    'пунш напиток',
    'желе',
    'будний вечер',
    'коричневый рис',
    'канадский',
    'апельсины',
    'лимон',
    'белый рис',
    'палтус',
    'греческий',
    'китайский',
    'бранч',
    'сом',
    'телятина',
    'юго-запад сша',
    'хлеб на закваске',
    'веган',
    'каджун',
    'ягоды',
    'шпинат',
    'кокос',
    'омар',
    'гамбо',
    'дыни',
    'тайский',
    'пикантный',
    'лето',
    'форель',
    'легкий',
    'карибский бассейн',
    'олень',
    'моллюски',
    'немецкий',
    'соя тофу',
    'манго',
    'цитрусовые',
    'техас мексика',
    'испанский',
    'кошерный',
    'груши',
    'японский',
    'подходит для малышей',
    'креольский',
    'африканский',
    'грудка индейки',
    'маникотти',
    'кальмар',
    'вишня',
    'марокканский',
    'сиг',
    'утка',
    'фазан',
    'куриная печень',
    'дикая дичь',
    'лайм',
    'высокое содержание клетчатки',
    'вьетнамский',
    'зима',
    'листовая капуста',
    'венгерский',
    'без яиц',
    'раки',
    'темпе',
    'нет моллюсков',
    'шведский',
    'сливы',
    'гавайский',
    'непальский',
    'мясной рулет',
    'среднезерновой рис',
    'голландский',
    'окунь',
    'скандинавский',
    'польский',
    'мангольд',
    'кролик',
    'перепел',
    'египетский',
    'лось',
    'португальский',
    'русский',
    'тропические фрукты',
    'осьминог',
    'арахисовое масло',
    'сычуань',
    'новая зеландия',
    'эфиопский',
    'норвежский',
    'датский',
    'гусь',
    'мороженое',
    'индонезийский',
    'ливанский',
    'печенье с шоколадной крошкой',
    'малайзийский',
    'коренной американец',
    'бразильский',
    'кубинский',
    'чешский',
    'турецкий',
    'коста-риканский',
    'полинезийский',
    'палестинский',
    'исландский',
    'пюре',
    'макароны и сыр',
    'без готовки',
    'орехи',
    'шотландский',
    'финский',
    'бельгийский',
    'пуэрто-риканский',
    'нигерийский',
    'киви',
    'овсянка',
    'безмолочные продукты',
    'грузинский',
    'летний дип',
    'скороварка',
    'фрикадельки',
    'филиппинский',
    'иракский',
    'индийский',
    'медведь',
    'южноамериканский',
    'колумбийский',
    'корейский',
    'пакистанский',
    'горшочный пирог',
    '15 минут',
    '30 минут',
    '60 минут',
    '4 часа',
  ];

  static const List<String> _quickKeywordsEn = [
    'dessert',
    'breakfast',
    'chicken',
    'soup',
    'salad',
    'pasta',
    'rice',
    'healthy',
    'high protein',
    'mexican',
    'asian',
    'vegetable',
  ];

  static const List<String> _quickKeywordsRu = [
    'десерт',
    'завтрак',
    'курица',
    'суп',
    'салат',
    'паста',
    'рис',
    'здоровый',
    'высокое содержание белка',
    'мексиканский',
    'азиатский',
    'овощной',
  ];

  final List<String> _placeholders = const [
    'assets/images/recipe_placeholder1.png',
    'assets/images/recipe_placeholder2.png',
  ];

  bool get _isRu => AppScope.settingsOf(context).locale.languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => Theme.of(context).colorScheme;
  bool get _isDarkTheme => _theme.brightness == Brightness.dark;
  Color get _screenBackground =>
      _isDarkTheme ? _theme.scaffoldBackgroundColor : const Color(0xFFF4D9B1);
  Color get _panelBackground => _isDarkTheme
      ? Color.alphaBlend(
          _cs.surfaceContainerHighest.withValues(alpha: 0.56),
          _cs.surface,
        )
      : const Color(0xFFF6F6F7);
  List<String> get _activeKeywordCatalog =>
      _isRu ? _keywordCatalogRu : _keywordCatalogEn;
  List<String> get _activeQuickKeywords =>
      _isRu ? _quickKeywordsRu : _quickKeywordsEn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadProfileSummary();
      _searchFromFirstPage();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = AppScope.settingsOf(context).locale.languageCode;

    if (_lastLocaleCode == null) {
      _lastLocaleCode = localeCode;
      return;
    }

    if (_lastLocaleCode != localeCode) {
      _lastLocaleCode = localeCode;
      setState(() {
        selectedKeyword = null;
        keywordCtrl.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || loading) return;
        _searchFromFirstPage();
      });
    }
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    keywordCtrl.dispose();
    pageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _scrollToResultsTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchorContext = _resultsTopKey.currentContext;
      if (anchorContext != null) {
        Scrollable.ensureVisible(
          anchorContext,
          alignment: 0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _loadProfileSummary() async {
    final profile = await api.getProfile();
    if (!mounted || profile == null) return;
    setState(() => _profile = profile);
  }

  String _displayUserName() {
    final rawName = (_profile?['name'] ?? '').toString().trim();
    if (rawName.isNotEmpty) return rawName;
    final email = (_profile?['email'] ?? '').toString().trim();
    if (email.contains('@')) return email.split('@').first;
    return _isRu ? 'друг' : 'friend';
  }

  String? _profileAvatarUrl() {
    final candidates = <dynamic>[
      _profile?['avatarUrl'],
      _profile?['avatar_url'],
      _profile?['avatar'],
      _profile?['photoUrl'],
      _profile?['photo_url'],
      _profile?['imageUrl'],
      _profile?['image_url'],
    ];
    for (final item in candidates) {
      final value = item?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  Future<void> _searchFromFirstPage() => search(page: 1);

  Future<void> search({int page = 1}) async {
    _dismissKeyboard();
    final requestedPage = page < 1 ? 1 : page;
    final previousPage = currentPage;
    final requestId = ++_activeSearchRequestId;

    setState(() {
      loading = true;
      searched = true;
      if (requestedPage == 1) {
        results = [];
      }
    });

    try {
      final lang = AppScope.settingsOf(context).locale.languageCode;
      final selectedKeywordValue = (selectedKeyword ?? '').trim().isNotEmpty
          ? selectedKeyword!.trim()
          : keywordCtrl.text.trim();

      final pageResult = await api.searchRecipesPage(
        diet: diet,
        title: titleCtrl.text.trim(),
        category: selectedKeywordValue,
        lang: lang,
        page: requestedPage,
        size: _pageSize,
      );
      final list = pageResult.items;

      if (!mounted || requestId != _activeSearchRequestId) return;
      if (requestedPage > 1 && list.isEmpty) {
        setState(() {
          loading = false;
          hasNextPage = false;
          currentPage = previousPage;
        });
        pageCtrl.text = previousPage.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isRu ? 'Это последняя страница' : 'This is the last page',
            ),
          ),
        );
        return;
      }

      setState(() {
        loading = false;
        currentPage = requestedPage;
        hasNextPage = pageResult.hasNext;
        results = list;
      });
      pageCtrl.text = requestedPage.toString();
      if (requestedPage != previousPage) {
        _scrollToResultsTop();
      }
    } catch (_) {
      if (!mounted || requestId != _activeSearchRequestId) return;
      setState(() {
        loading = false;
        currentPage = previousPage;
        if (requestedPage == 1) {
          results = [];
        }
      });
      pageCtrl.text = currentPage.toString();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr(context, 'search_error'))));
    }
  }

  Future<void> _goPrevPage() async {
    if (loading || currentPage <= 1) return;
    await search(page: currentPage - 1);
  }

  Future<void> _goNextPage() async {
    if (loading || !hasNextPage) return;
    await search(page: currentPage + 1);
  }

  Future<void> _goToTypedPage() async {
    _dismissKeyboard();
    if (loading) return;
    final page = int.tryParse(pageCtrl.text.trim());
    if (page == null || page < 1) {
      pageCtrl.text = currentPage.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isRu
                ? 'Введите корректный номер страницы'
                : 'Enter a valid page number',
          ),
        ),
      );
      return;
    }
    if (page == currentPage) return;
    await search(page: page);
  }

  String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  String _dietLabel(String value) {
    if (!_isRu) return _titleCase(value);
    switch (value) {
      case 'gluten free':
        return 'Без глютена';
      case 'ketogenic':
        return 'Кетогенная';
      case 'vegetarian':
        return 'Вегетарианская';
      case 'vegan':
        return 'Веганская';
      case 'paleo':
        return 'Палео';
      default:
        return value;
    }
  }

  String _keywordLabel(String value) {
    final v = value.trim();
    if (v.isEmpty) return v;
    final isCyrillic = RegExp(r'[А-Яа-я]').hasMatch(v);
    if (isCyrillic) return v;
    return _titleCase(v);
  }

  List<String> _keywordSuggestions(String query) {
    final q = query.trim().toLowerCase();
    final unique = _activeKeywordCatalog.toSet().toList();
    if (q.isEmpty) return unique.take(30).toList();

    final startsWith = unique
        .where((k) => k.toLowerCase().startsWith(q))
        .toList();
    final contains = unique.where((k) {
      final lower = k.toLowerCase();
      return !lower.startsWith(q) && lower.contains(q);
    }).toList();

    return [...startsWith, ...contains].take(30).toList();
  }

  void _applyKeyword(String keyword) {
    final k = keyword.trim();
    if (k.isEmpty) return;
    selectedKeyword = k;
    keywordCtrl.text = k;
    _dismissKeyboard();
  }

  String? _cleanText(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }

  bool _isBadImageUrl(String? image) {
    final url = (image ?? '').trim().toLowerCase();
    if (url.isEmpty) return true;
    return url.contains('img.sndimg.com') &&
        url.contains('fdc-sharegraphic.png');
  }

  String _pickPlaceholder(int key) =>
      _placeholders[key.abs() % _placeholders.length];

  bool _isInvalidTimeText(String text) {
    final normalized = text.trim().toLowerCase();
    return normalized.isEmpty ||
        normalized == 'null' ||
        normalized == 'none' ||
        normalized == 'n/a' ||
        normalized == 'na' ||
        normalized == '-' ||
        normalized == '--' ||
        normalized == '{}' ||
        normalized == '[]' ||
        normalized == 'unknown' ||
        normalized == 'неизвестно' ||
        RegExp(r'^0+([.,]0+)?$').hasMatch(normalized);
  }

  int? _parseTimeToMinutes(String? raw) {
    final text = raw?.trim().toLowerCase() ?? '';
    if (text.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(text)) return int.tryParse(text);

    int h = 0;
    int m = 0;
    for (final match in RegExp(
      r'(\d+)\s*(h|hr|hrs|hour|hours|ч)',
    ).allMatches(text)) {
      h += int.parse(match.group(1)!);
    }
    for (final match in RegExp(
      r'(\d+)\s*(m|min|mins|minute|minutes|мин)',
    ).allMatches(text)) {
      m += int.parse(match.group(1)!);
    }
    final hm = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(text);
    if (hm != null) {
      h = int.parse(hm.group(1)!);
      m = int.parse(hm.group(2)!);
    }
    final total = h * 60 + m;
    return total > 0 ? total : null;
  }

  String _formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (_isRu) {
      if (h > 0 && m > 0) return '$h ч $m мин';
      if (h > 0) return '$h ч';
      return '$m мин';
    }
    if (h > 0 && m > 0) return '$h hr $m min';
    if (h > 0) return '$h hr';
    return '$m min';
  }

  String? _totalTimeLabel(RecipeSummary recipe) {
    final raw = _cleanText(recipe.totalTime);
    if (raw != null && !_isInvalidTimeText(raw)) {
      final minutes = _parseTimeToMinutes(raw);
      if (minutes != null && minutes > 0) return _formatMinutes(minutes);
      return null;
    }
    if (recipe.readyInMinutes != null && recipe.readyInMinutes! > 0) {
      return _formatMinutes(recipe.readyInMinutes!);
    }
    return null;
  }

  Widget _recipeImage(
    String? image,
    int recipeId, {
    required double width,
    required double height,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(18)),
  }) {
    final fallback = _pickPlaceholder(recipeId);
    final bad = _isBadImageUrl(image);
    return ClipRRect(
      borderRadius: borderRadius,
      child: bad
          ? Image.asset(
              fallback,
              width: width,
              height: height,
              fit: BoxFit.cover,
            )
          : Image.network(
              image!.trim(),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Image.asset(
                fallback,
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            ),
    );
  }

  Widget _profileAvatarFallback() {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF1A62B).withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 24,
        color: Color(0xFFF1A62B),
      ),
    );
  }

  Future<void> _openFiltersSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            void syncState(VoidCallback fn) {
              setState(fn);
              setSheetState(() {});
            }

            final suggestions = _keywordSuggestions(keywordCtrl.text);
            final inset = MediaQuery.of(sheetContext).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isRu ? 'Фильтры рецептов' : 'Recipe filters',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: keywordCtrl,
                      onTapOutside: (_) => _dismissKeyboard(),
                      onChanged: (value) => syncState(() {
                        final typed = value.trim().toLowerCase();
                        final selected = (selectedKeyword ?? '')
                            .trim()
                            .toLowerCase();
                        if (typed.isEmpty || typed != selected) {
                          selectedKeyword = null;
                        }
                      }),
                      decoration: InputDecoration(
                        labelText: _isRu ? 'Ключевое слово' : 'Keyword',
                        hintText: _isRu
                            ? 'Например: курица, паста, суп, десерт'
                            : 'For example: chicken, pasta, soup, dessert',
                        prefixIcon: const Icon(Icons.tag_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if ((selectedKeyword ?? '').trim().isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          InputChip(
                            label: Text(_keywordLabel(selectedKeyword!.trim())),
                            selected: true,
                            onPressed: null,
                            onDeleted: () => syncState(() {
                              selectedKeyword = null;
                              keywordCtrl.clear();
                            }),
                          ),
                        ],
                      ),
                    if ((selectedKeyword ?? '').trim().isNotEmpty)
                      const SizedBox(height: 12),
                    Text(
                      _isRu ? 'Быстрые ключевые слова' : 'Quick keywords',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _cs.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _activeQuickKeywords
                          .map(
                            (k) => FilterChip(
                              selected: selectedKeyword == k,
                              label: Text(_keywordLabel(k)),
                              onSelected: (_) =>
                                  syncState(() => _applyKeyword(k)),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _isRu ? 'Подсказки' : 'Suggestions',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _cs.onSurface.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (suggestions.isEmpty)
                      Text(
                        _isRu ? 'Ничего не найдено' : 'No keyword suggestions',
                        style: TextStyle(
                          color: _cs.onSurfaceVariant.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: suggestions
                            .map(
                              (k) => FilterChip(
                                selected: selectedKeyword == k,
                                label: Text(_keywordLabel(k)),
                                onSelected: (_) =>
                                    syncState(() => _applyKeyword(k)),
                              ),
                            )
                            .toList(),
                      ),
                    const SizedBox(height: 14),
                    _dropdown(
                      hint: tr(context, 'diet_filter'),
                      value: diet,
                      items: diets,
                      labelBuilder: _dietLabel,
                      onChanged: (v) => syncState(() => diet = v),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => syncState(() {
                              diet = null;
                              selectedKeyword = null;
                              keywordCtrl.clear();
                            }),
                            child: Text(_isRu ? 'Сбросить' : 'Reset'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _searchFromFirstPage();
                            },
                            icon: const Icon(Icons.search_rounded),
                            label: Text(tr(context, 'find')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTopBlock() {
    final cs = _cs;
    final userName = _displayUserName();
    final avatarUrl = _profileAvatarUrl();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _isRu ? 'Привет, $userName' : 'Hello, $userName',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -0.7,
                ),
              ),
            ),
            IconButton(
              onPressed: () => showAppSettingsSheet(context),
              icon: const Icon(Icons.settings_rounded),
              tooltip: tr(context, 'settings'),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: widget.onOpenProfileTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: (avatarUrl == null)
                    ? _profileAvatarFallback()
                    : Image.network(
                        avatarUrl,
                        width: 42,
                        height: 42,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _profileAvatarFallback(),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: titleCtrl,
                onTapOutside: (_) => _dismissKeyboard(),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchFromFirstPage(),
                decoration: InputDecoration(
                  hintText: _isRu ? 'Поиск рецептов' : 'Search for recipes',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 15,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.65),
                  ),
                  suffixIcon: IconButton(
                    onPressed: loading ? null : _searchFromFirstPage,
                    icon: const Icon(Icons.north_east_rounded),
                  ),
                  filled: true,
                  fillColor: Color.alphaBlend(
                    cs.surfaceContainerHighest.withValues(
                      alpha: _isDarkTheme ? 0.34 : 0.75,
                    ),
                    cs.surface,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              onPressed: _openFiltersSheet,
              icon: const Icon(Icons.tune_rounded),
              tooltip: _isRu ? 'Фильтры' : 'Filters',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecipeCard(RecipeSummary recipe) {
    final totalTime = _totalTimeLabel(recipe);
    final ingredientsText = _isRu
        ? '${recipe.ingredientsCount} ингредиентов'
        : '${recipe.ingredientsCount} ingredients';
    final caloriesText = recipe.calories == null
        ? null
        : '${recipe.calories!.round()} ${tr(context, 'kcal')}';

    Widget metaChip(IconData icon, String text) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            _cs.surfaceContainerHighest.withValues(
              alpha: _isDarkTheme ? 0.52 : 0.8,
            ),
            _cs.surface,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _cs.primary),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _cs.onSurface.withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                RecipeDetailScreen(recipeId: recipe.id, seed: recipe),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: _recipeImage(
                    recipe.image,
                    recipe.id,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Icon(
                    Icons.favorite_rounded,
                    size: 24,
                    color: const Color(0xFFFF4F65),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            recipe.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              metaChip(Icons.inventory_2_outlined, ingredientsText),
              if (totalTime != null)
                metaChip(Icons.access_time_rounded, totalTime),
              if (caloriesText != null)
                metaChip(Icons.local_fire_department_rounded, caloriesText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecommended() {
    if (loading && results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (searched && results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(
            _isRu ? 'Ничего не найдено' : 'Nothing found',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: results.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.50,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (_, i) => _buildRecipeCard(results[i]),
    );
  }

  Widget _buildPaginationControls() {
    if (!searched || results.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: (loading || currentPage <= 1) ? null : _goPrevPage,
              child: Text(_isRu ? 'Назад' : 'Previous'),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: TextField(
              controller: pageCtrl,
              onTapOutside: (_) => _dismissKeyboard(),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.go,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _goToTypedPage(),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(isDense: true),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: loading ? null : _goToTypedPage,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 40),
              ),
              child: Text(_isRu ? 'Перейти' : 'Go'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: (loading || !hasNextPage) ? null : _goNextPage,
              child: Text(_isRu ? 'Вперед' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBackground,
      body: GestureDetector(
        onTap: _dismissKeyboard,
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Container(
              decoration: BoxDecoration(
                color: _panelBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                  bottom: Radius.circular(34),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: _isDarkTheme ? 0.24 : 0.07,
                    ),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(34),
                  bottom: Radius.circular(34),
                ),
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadProfileSummary();
                    await _searchFromFirstPage();
                  },
                  child: ListView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 120),
                    children: [
                      _buildTopBlock(),
                      const SizedBox(height: 18),
                      SizedBox(key: _resultsTopKey, height: 0),
                      Text(
                        _isRu ? 'Рекомендуем' : 'Recommended',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.04,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRecommended(),
                      _buildPaginationControls(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required String Function(String) labelBuilder,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: InputDecoration(labelText: hint),
      items: [
        DropdownMenuItem<String?>(value: null, child: Text(tr(context, 'any'))),
        ...items.map(
          (e) =>
              DropdownMenuItem<String?>(value: e, child: Text(labelBuilder(e))),
        ),
      ],
      onChanged: onChanged,
    );
  }
}
