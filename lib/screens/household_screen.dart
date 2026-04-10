import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_feedback.dart';
import '../core/live_refresh.dart';
import '../core/app_theme.dart';
import '../core/atelier_ui.dart';
import '../core/app_top_bar.dart';
import '../repositories/app_repository.dart';
import '../services/api_service.dart';
import 'household_detail_screen.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen>
    with LiveRefreshState<HouseholdScreen> {
  final AppRepository repository = AppRepository.instance;

  bool _loading = true;
  bool _isFetching = false;
  bool _didScheduleInitialLoad = false;
  List<Map<String, dynamic>> _households = const [];
  List<Map<String, dynamic>> _invitations = const [];
  String _lastSnapshotSignature = '';

  bool get _isRu => Localizations.localeOf(context).languageCode == 'ru';
  ThemeData get _theme => Theme.of(context);
  ColorScheme get _cs => _theme.colorScheme;
  String get _screenTitle => _isRu ? 'Семья' : 'Household';

  String _errorText(Object error, String fallback) {
    if (error is ApiException) return error.message;
    final text = error.toString().trim();
    if (text.isEmpty) return fallback;
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  void _showMessage(
    String message, {
    AppFeedbackKind? kind,
    bool preferPopup = false,
    bool addToInbox = true,
  }) {
    if (!mounted) return;
    showAppFeedback(
      context,
      message,
      kind: kind,
      source: _screenTitle,
      preferPopup: preferPopup,
      addToInbox: addToInbox,
    );
  }

  Future<T> _loadWithFallback<T>({
    required Future<T> future,
    required T fallback,
    required List<String> errors,
    required String fallbackMessage,
  }) async {
    try {
      return await future;
    } catch (error) {
      errors.add(_errorText(error, fallbackMessage));
      return fallback;
    }
  }

  void _showLoadWarnings(List<String> errors) {
    if (!mounted || errors.isEmpty) return;
    final prefix = _isRu
        ? 'Не все данные семьи обновились.'
        : 'Not all household data was refreshed.';
    _showMessage('$prefix\n${errors.toSet().join('\n')}');
  }

  @override
  Duration get liveRefreshInterval => const Duration(seconds: 8);

  @override
  bool get enableLiveRefresh => ModalRoute.of(context)?.isCurrent ?? true;

  @override
  Future<void> performLiveRefresh() => _load(silent: true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didScheduleInitialLoad) return;
    _didScheduleInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    if (!silent) {
      setState(() => _loading = true);
    }
    final errors = <String>[];
    try {
      final householdsFuture = _loadWithFallback<List<Map<String, dynamic>>>(
        future: repository.getHouseholds(),
        fallback: _households,
        errors: errors,
        fallbackMessage: _isRu
            ? 'Не удалось загрузить семьи'
            : 'Failed to load households',
      );
      final invitationsFuture = _loadWithFallback<List<Map<String, dynamic>>>(
        future: repository.getMyHouseholdInvitations(),
        fallback: _invitations,
        errors: errors,
        fallbackMessage: _isRu
            ? 'Не удалось загрузить приглашения'
            : 'Failed to load invitations',
      );

      final households = await householdsFuture;
      final invitations = await invitationsFuture;
      final nextSignature = liveRefreshSignature(<String, Object?>{
        'households': households,
        'invitations': invitations,
      });

      if (!mounted) return;
      final hasChanged = nextSignature != _lastSnapshotSignature;
      if (hasChanged || !silent || _loading) {
        setState(() {
          _households = households;
          _invitations = invitations;
          _loading = false;
        });
      }
      _lastSnapshotSignature = nextSignature;
      if (!silent) {
        _showLoadWarnings(errors);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _createHousehold() async {
    final ctrl = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AtelierDialogFrame(
        title: _isRu ? 'Новая семья' : 'New household',
        subtitle: _isRu
            ? 'Создай общее пространство для покупок, сообщений и домашней координации.'
            : 'Create a shared space for shopping, messages, and home coordination.',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AtelierFieldLabel(_isRu ? 'Название семьи' : 'Household name'),
            TextField(
              controller: ctrl,
              decoration: InputDecoration(
                hintText: _isRu
                    ? 'Например, Семья Ивановых'
                    : 'For example, Green Kitchen',
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(_isRu ? 'Отмена' : 'Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      final name = ctrl.text.trim();
                      if (name.isEmpty) {
                        showAppFeedback(
                          context,
                          _isRu
                              ? 'Введи название семьи'
                              : 'Enter a household name',
                          kind: AppFeedbackKind.error,
                          source: _screenTitle,
                          preferPopup: true,
                          addToInbox: false,
                        );
                        return;
                      }

                      try {
                        final result = await repository.createHousehold(name);
                        if (!context.mounted) return;
                        Navigator.of(context).pop(result != null);
                      } catch (error) {
                        if (!context.mounted) return;
                        showAppFeedback(
                          context,
                          _errorText(
                            error,
                            _isRu
                                ? 'Не удалось создать семью'
                                : 'Failed to create household',
                          ),
                          kind: AppFeedbackKind.error,
                          source: _screenTitle,
                          preferPopup: true,
                        );
                      }
                    },
                    child: Text(_isRu ? 'Создать' : 'Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (created == true) {
      await _load();
    }
  }

  Future<void> _respondInvitation(
    Map<String, dynamic> invite,
    bool accept,
  ) async {
    try {
      final result = accept
          ? await repository.acceptHouseholdInvitation(invite['id'].toString())
          : await repository.declineHouseholdInvitation(
              invite['id'].toString(),
            );
      if (result != null) {
        await _load();
      }
    } catch (error) {
      _showMessage(
        _errorText(
          error,
          accept
              ? (_isRu
                    ? 'Не удалось принять приглашение'
                    : 'Failed to accept invitation')
              : (_isRu
                    ? 'Не удалось отклонить приглашение'
                    : 'Failed to decline invitation'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _theme.scaffoldBackgroundColor,
      appBar: AppTopBar(
        title: _isRu ? 'Семья' : 'Household',
        actions: [
          AppTopAction(icon: Icons.refresh_rounded, onPressed: _load),
          AppTopAction(
            icon: Icons.group_add_rounded,
            onPressed: _createHousehold,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createHousehold,
        icon: const Icon(Icons.add_home_work_outlined),
        label: Text(_isRu ? 'Новая семья' : 'New household'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
          children: [
            AtelierHeroCard(
              eyebrow: 'The Organic Atelier',
              title: _isRu ? 'Семья\nи дом' : 'Shared\nhousehold',
              subtitle: _isRu
                  ? 'Объединяй покупки, приглашения и общий продуктовый ритм.'
                  : 'Bring invitations, shopping, and shared home rhythm together.',
              gradientColors: [
                _cs.primary.withValues(alpha: 0.14),
                AppTheme.atelierLime.withValues(alpha: 0.16),
                AppTheme.atelierHoney.withValues(alpha: 0.08),
              ],
              pills: [
                AtelierStatPill(
                  icon: Icons.groups_rounded,
                  label: _isRu
                      ? '${_households.length} семей'
                      : '${_households.length} household',
                  color: _cs.primary,
                ),
                AtelierStatPill(
                  icon: Icons.mail_rounded,
                  label: _isRu
                      ? '${_invitations.length} приглашений'
                      : '${_invitations.length} invites',
                  color: _cs.tertiary,
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_invitations.isNotEmpty) ...[
                AtelierSectionIntro(
                  eyebrow: _isRu ? 'приглашения' : 'invitations',
                  title: _isRu ? 'Входящие приглашения' : 'Incoming invites',
                  subtitle: _isRu
                      ? 'Прими или отклони приглашения в семейные пространства.'
                      : 'Accept or decline the shared spaces that are waiting for you.',
                ),
                const SizedBox(height: 16),
                ..._invitations.map(
                  (invite) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: AtelierSurfaceCard(
                      radius: 24,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              AtelierIconBadge(
                                icon: Icons.mail_rounded,
                                accent: _cs.tertiary,
                              ),
                              const Spacer(),
                              AtelierTagChip(
                                label: _isRu ? 'Ожидает ответа' : 'Waiting',
                                foreground: _cs.tertiary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            invite['householdName']?.toString() ?? '-',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isRu
                                ? 'Пригласил: ${invite['invitedByName'] ?? '-'}'
                                : 'Invited by: ${invite['invitedByName'] ?? '-'}',
                            style: TextStyle(
                              color: _cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () =>
                                      _respondInvitation(invite, false),
                                  child: Text(_isRu ? 'Отклонить' : 'Decline'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () =>
                                      _respondInvitation(invite, true),
                                  child: Text(_isRu ? 'Принять' : 'Accept'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              AtelierSectionIntro(
                eyebrow: _isRu ? 'пространства' : 'spaces',
                title: _isRu ? 'Мои семьи' : 'My households',
                subtitle: _isRu
                    ? 'Все общие пространства, где живут покупки и совместные действия.'
                    : 'All shared spaces where shopping and collaboration live.',
              ),
              const SizedBox(height: 16),
              if (_households.isEmpty)
                AtelierEmptyState(
                  icon: Icons.home_work_rounded,
                  title: _isRu
                      ? 'Общих семей пока нет'
                      : 'No shared households yet',
                  subtitle: _isRu
                      ? 'Создай первое пространство и начни вести общий домашний контур.'
                      : 'Create the first space and start a shared food workflow.',
                  accent: _cs.primary,
                )
              else
                ..._households.map(
                  (household) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => HouseholdDetailScreen(
                              householdId: household['id'].toString(),
                              initialName: household['name']?.toString() ?? '',
                            ),
                          ),
                        );
                        if (!mounted) return;
                        await _load(silent: true);
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: AtelierSurfaceCard(
                        radius: 24,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AtelierIconBadge(
                              icon: Icons.groups_2_rounded,
                              accent: _cs.primary,
                              size: 56,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    household['name']?.toString() ?? '-',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      AtelierTagChip(
                                        label:
                                            '${household['membersCount'] ?? 0} ${_isRu ? 'участников' : 'members'}',
                                        foreground: _cs.primary,
                                        icon: Icons.group_outlined,
                                      ),
                                      AtelierTagChip(
                                        label:
                                            '${household['uncheckedItemsCount'] ?? 0} ${_isRu ? 'неотмеченных' : 'unchecked'}',
                                        foreground: _cs.tertiary,
                                        icon: Icons.shopping_cart_outlined,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Icon(Icons.chevron_right_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
