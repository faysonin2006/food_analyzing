// Example usage of SearchDebouncer
//
// This file demonstrates how to use SearchDebouncer in a Flutter widget
// for debouncing search queries.

import 'package:flutter/material.dart';
import 'search_debouncer.dart';

/// Example widget showing SearchDebouncer usage
class SearchDebouncerExample extends StatefulWidget {
  const SearchDebouncerExample({super.key});

  @override
  State<SearchDebouncerExample> createState() => _SearchDebouncerExampleState();
}

class _SearchDebouncerExampleState extends State<SearchDebouncerExample> {
  late final SearchDebouncer _debouncer;
  final TextEditingController _controller = TextEditingController();
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    // Initialize debouncer with 300ms delay
    _debouncer = SearchDebouncer(delay: const Duration(milliseconds: 300));

    // Listen to text changes
    _controller.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final query = _controller.text;

    // Use debouncer to delay search execution
    _debouncer.call(() {
      _performSearch(query);
    });
  }

  void _performSearch(String query) {
    setState(() {
      _lastSearchQuery = query;
    });
    // Here you would typically call your search API
    print('Searching for: $query');
  }

  @override
  void dispose() {
    // Clean up debouncer
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Debouncer Example')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'Type to search...',
              ),
            ),
            const SizedBox(height: 16),
            Text('Last search: $_lastSearchQuery'),
          ],
        ),
      ),
    );
  }
}
