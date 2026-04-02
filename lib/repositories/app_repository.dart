import 'package:image_picker/image_picker.dart';

import '../local/search_history_local_db.dart';
import '../features/recipes/models/models.dart';
import '../services/api_service.dart';

class AppRepository {
  AppRepository._();

  static final AppRepository instance = AppRepository._();

  final ApiService _api = ApiService();
  final SearchHistoryLocalDb _searchHistoryDb = SearchHistoryLocalDb.instance;

  Future<String?> getToken() => _api.getToken();
  Future<void> logout() => _api.logout();

  Future<bool> login(String email, String password) =>
      _api.login(email, password);
  Future<bool> register(String email, String password, String role) =>
      _api.register(email, password, role);

  Future<Map<String, dynamic>?> getProfile() => _api.getProfile();
  Future<bool> updateProfile(Map<String, dynamic> data) =>
      _api.updateProfile(data);
  Future<bool> uploadAvatar(XFile imageFile) => _api.uploadAvatar(imageFile);

  Future<bool> likeRecipe(int recipeId) => _api.likeRecipe(recipeId);
  Future<bool> unlikeRecipe(int recipeId) => _api.unlikeRecipe(recipeId);
  Future<List<Map<String, dynamic>>> getLikedRecipes() =>
      _api.getLikedRecipes();

  Future<String?> startFoodAnalysis(
    XFile imageFile, {
    String extraQuestions = '',
  }) => _api.startFoodAnalysis(imageFile, extraQuestions: extraQuestions);

  Future<Map<String, dynamic>?> getAnalysisResult(String analysisId) =>
      _api.getAnalysisResult(analysisId);

  Future<List<dynamic>?> getAnalysisHistory({int? limit}) =>
      _api.getAnalysisHistory(limit: limit);
  Future<bool> deleteAnalysisHistoryItem(String analysisId) =>
      _api.deleteAnalysisHistoryItem(analysisId);

  Future<Map<String, dynamic>?> saveFoodAnalysis(
    String analysisId, {
    required Map<String, dynamic> data,
  }) => _api.saveFoodAnalysis(analysisId, data: data);

  Future<List<Map<String, dynamic>>> getPantryItems() => _api.getPantryItems();
  Future<List<Map<String, dynamic>>> getExpiringPantryItems() =>
      _api.getExpiringPantryItems();
  Future<List<Map<String, dynamic>>> getExpiredPantryItems() =>
      _api.getExpiredPantryItems();
  Future<Map<String, dynamic>?> getPantryItem(String pantryItemId) =>
      _api.getPantryItem(pantryItemId);
  Future<Map<String, dynamic>?> createPantryItem(Map<String, dynamic> data) =>
      _api.createPantryItem(data);
  Future<Map<String, dynamic>?> updatePantryItem(
    String pantryItemId,
    Map<String, dynamic> data,
  ) => _api.updatePantryItem(pantryItemId, data);
  Future<bool> deletePantryItem(String pantryItemId) =>
      _api.deletePantryItem(pantryItemId);
  Future<Map<String, dynamic>?> uploadPantryItemImage(
    String pantryItemId,
    XFile imageFile,
  ) => _api.uploadPantryItemImage(pantryItemId, imageFile);
  Future<Map<String, dynamic>?> lookupPantryBarcode(String barcode) =>
      _api.lookupPantryBarcode(barcode);

  Future<List<Map<String, dynamic>>> getMeals({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => _api.getMeals(dateFrom: dateFrom, dateTo: dateTo);
  Future<Map<String, dynamic>?> createMeal(Map<String, dynamic> data) =>
      _api.createMeal(data);
  Future<bool> deleteMeal(String mealEntryId) => _api.deleteMeal(mealEntryId);

  Future<List<Map<String, dynamic>>> getShoppingItems() =>
      _api.getShoppingItems();
  Future<Map<String, dynamic>?> createShoppingItem(Map<String, dynamic> data) =>
      _api.createShoppingItem(data);
  Future<Map<String, dynamic>?> toggleShoppingItem(String itemId) =>
      _api.toggleShoppingItem(itemId);
  Future<bool> deleteShoppingItem(String itemId) =>
      _api.deleteShoppingItem(itemId);

  Future<Map<String, dynamic>?> getDailyAnalytics({DateTime? date}) =>
      _api.getDailyAnalytics(date: date);
  Future<Map<String, dynamic>?> getWeeklyAnalytics({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => _api.getWeeklyAnalytics(dateFrom: dateFrom, dateTo: dateTo);
  Future<Map<String, dynamic>?> getMacroSummary({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) => _api.getMacroSummary(dateFrom: dateFrom, dateTo: dateTo);

  Future<List<Map<String, dynamic>>> getRecommendedRecipes({
    int size = 6,
    String sortBy = 'match',
    String lang = 'ru',
  }) => _api.getRecommendedRecipes(size: size, sortBy: sortBy, lang: lang);
  Future<Map<String, dynamic>?> addMissingIngredientsToShoppingList(
    int recipeId,
  ) => _api.addMissingIngredientsToShoppingList(recipeId);

  Future<List<Map<String, dynamic>>> getHouseholds() => _api.getHouseholds();
  Future<Map<String, dynamic>?> createHousehold(String name) =>
      _api.createHousehold(name);
  Future<Map<String, dynamic>?> getHouseholdDetail(String householdId) =>
      _api.getHouseholdDetail(householdId);
  Future<List<Map<String, dynamic>>> getMyHouseholdInvitations() =>
      _api.getMyHouseholdInvitations();
  Future<Map<String, dynamic>?> createHouseholdInvitation(
    String householdId,
    String email,
  ) => _api.createHouseholdInvitation(householdId, email);
  Future<Map<String, dynamic>?> acceptHouseholdInvitation(
    String invitationId,
  ) => _api.acceptHouseholdInvitation(invitationId);
  Future<Map<String, dynamic>?> declineHouseholdInvitation(
    String invitationId,
  ) => _api.declineHouseholdInvitation(invitationId);
  Future<List<Map<String, dynamic>>> getHouseholdShoppingItems(
    String householdId,
  ) => _api.getHouseholdShoppingItems(householdId);
  Future<Map<String, dynamic>?> createHouseholdShoppingItem(
    String householdId,
    Map<String, dynamic> data,
  ) => _api.createHouseholdShoppingItem(householdId, data);
  Future<Map<String, dynamic>?> toggleHouseholdShoppingItem(
    String householdId,
    String itemId,
  ) => _api.toggleHouseholdShoppingItem(householdId, itemId);
  Future<bool> deleteHouseholdShoppingItem(String householdId, String itemId) =>
      _api.deleteHouseholdShoppingItem(householdId, itemId);
  Future<List<Map<String, dynamic>>> getHouseholdMessages(String householdId) =>
      _api.getHouseholdMessages(householdId);
  Future<Map<String, dynamic>?> createHouseholdMessage(
    String householdId,
    String message,
  ) => _api.createHouseholdMessage(householdId, message);

  Future<RecipeSearchPageResult> searchRecipesPage({
    String? diet,
    String? title,
    String? category,
    String lang = 'ru',
    int page = 1,
    int size = 20,
  }) => _api.searchRecipesPage(
    diet: diet,
    title: title,
    category: category,
    lang: lang,
    page: page,
    size: size,
  );

  Future<List<String>> rerankSuggestionCandidateIds({
    required String query,
    required List<Map<String, dynamic>> candidates,
    int limit = 8,
  }) => _api.rerankSuggestionCandidateIds(
    query: query,
    candidates: candidates,
    limit: limit,
  );

  Future<RecipeDetails?> getRecipeDetails({
    required int recipeId,
    RecipeSummary? seedSummary,
  }) => _api.getRecipeDetails(recipeId: recipeId, seedSummary: seedSummary);

  Future<void> saveSearchHistory(SearchHistoryDraft draft) =>
      _searchHistoryDb.save(draft);

  Future<List<SearchHistoryEntry>> getSearchHistory({
    required String lang,
    int limit = 20,
  }) => _searchHistoryDb.listRecent(lang: lang, limit: limit);

  Future<void> deleteSearchHistoryItem(int id) =>
      _searchHistoryDb.deleteById(id);

  Future<void> clearSearchHistory({required String lang}) =>
      _searchHistoryDb.clearByLang(lang);
}
