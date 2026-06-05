import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/app_localizations.dart';

class EditTripPage extends StatefulWidget {
  final String itineraryId;
  final Map<String, dynamic> currentData;

  const EditTripPage({
    super.key,
    required this.itineraryId,
    required this.currentData,
  });

  @override
  State<EditTripPage> createState() => _EditTripPageState();
}

class _EditTripPageState extends State<EditTripPage> {
  late TextEditingController _titleController;
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _destinations = [];
  String? _selectedDestination;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.currentData['title'] ?? '');
    _startDate = (widget.currentData['startDate'] as Timestamp?)?.toDate();
    _endDate = (widget.currentData['endDate'] as Timestamp?)?.toDate();
    _selectedDestination = null;
    _fetchDestinations().then((_) {
      if (mounted) {
        setState(() {
          final destination = widget.currentData['destination'] as String?;
          if (destination != null && _destinations.contains(destination)) {
            _selectedDestination = destination;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _fetchDestinations() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('places').get();
      setState(() {
        _destinations = snapshot.docs.map((doc) => doc['title'] as String).toList();
      });
    } catch (e) {
      final localizations = AppLocalizations.of(context);
      print('${localizations.translate('error_loading_destinations')}$e');
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(data: isDark ? ThemeData.dark() : ThemeData.light(), child: child!);
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _updateTrip() async {
    final localizations = AppLocalizations.of(context);

    if (_titleController.text.trim().isEmpty ||
        _selectedDestination == null ||
        _startDate == null ||
        _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('complete_required_fields'))),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localizations.translate('end_date_before_start'))),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final placeSnapshot = await FirebaseFirestore.instance
          .collection('places')
          .where('title', isEqualTo: _selectedDestination)
          .limit(1)
          .get();

      String? imageUrl;
      if (placeSnapshot.docs.isNotEmpty) {
        imageUrl = placeSnapshot.docs.first.data()['imageUrl'] as String?;
      }

      await FirebaseFirestore.instance
          .collection('itineraries')
          .doc(widget.itineraryId)
          .update({
        'title': _titleController.text.trim(),
        'startDate': Timestamp.fromDate(_startDate!),
        'endDate': Timestamp.fromDate(_endDate!),
        'destination': _selectedDestination,
        'imageUrl': imageUrl,
        'updatedAt': Timestamp.now(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).translate('update_failed')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputBoxDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: Colors.grey[500]),
      filled: true,
      fillColor: Theme.of(context).cardColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
    );
  }

  Widget _labeledField(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  Widget _buildDestinationDropdown() {
    final localizations = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (_destinations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: theme.cardColor,
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _destinations.contains(_selectedDestination) ? _selectedDestination : null,
      decoration: InputDecoration(
        labelText: localizations.translate('select_destination'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
      ),
      items: _destinations.map((String destination) {
        return DropdownMenuItem<String>(
          value: destination,
          child: Text(
            destination,
            style: theme.textTheme.bodyMedium,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() => _selectedDestination = newValue);
      },
      dropdownColor: theme.cardColor,
      borderRadius: BorderRadius.circular(8),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.translate('edit_trip')),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _labeledField(
                    localizations.translate('trip_title_label'),
                    TextField(
                      controller: _titleController,
                      decoration: _inputBoxDecoration(
                        hintText: localizations.translate('enter_trip_title'),
                        icon: Icons.title,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _labeledField(
                    localizations.translate('destination'),
                    _destinations.isEmpty
                        ? Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: theme.cardColor,
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: const Center(child: CircularProgressIndicator()),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: _destinations.contains(_selectedDestination)
                                ? _selectedDestination
                                : null,
                            hint: Text(
                              localizations.translate('select_destination'),
                              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: Colors.grey[300]!),
                              ),
                              filled: true,
                              fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                            ),
                            items: _destinations.map((String destination) {
                              return DropdownMenuItem<String>(
                                value: destination,
                                child: Text(
                                  destination,
                                  style: theme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              setState(() => _selectedDestination = newValue);
                            },
                            dropdownColor: theme.cardColor,
                            borderRadius: BorderRadius.circular(8),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                          ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _labeledField(
                          localizations.translate('start_date_label'),
                          GestureDetector(
                            onTap: () => _pickDate(isStart: true),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: theme.cardColor,
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.grey[500], size: 20),
                                  const SizedBox(width: 8),
                                  Text(_formatDate(_startDate), style: theme.textTheme.bodyLarge),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _labeledField(
                          localizations.translate('end_date_label'),
                          GestureDetector(
                            onTap: () => _pickDate(isStart: false),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: theme.cardColor,
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: Colors.grey[500], size: 20),
                                  const SizedBox(width: 8),
                                  Text(_formatDate(_endDate), style: theme.textTheme.bodyLarge),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _updateTrip,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(localizations.translate('save_changes')),
                  ),
                ],
              ),
            ),
    );
  }
}